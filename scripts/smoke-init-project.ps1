param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$initializer = Join-Path $PSScriptRoot "init-project.ps1"
$batchInitializer = Join-Path $PSScriptRoot "init-project.bat"
$smokePath = Join-Path $root ("temp/smoke-init-" + [guid]::NewGuid().ToString("N"))
$batchSmokePath = Join-Path $root ("temp/smoke-bat-" + [guid]::NewGuid().ToString("N"))
$helpProbePath = Join-Path $root ("temp/smoke-help-" + [guid]::NewGuid().ToString("N"))
$occupiedPath = Join-Path $root ("temp/smoke-occupied-" + [guid]::NewGuid().ToString("N"))
$missingExistingPath = Join-Path $root ("temp/smoke-missing-existing-" + [guid]::NewGuid().ToString("N"))
$invalidTarget = Join-Path $root ("temp/smoke-target-file-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Smoke assertion failed: $Message"
    }
}

function Assert-Ignored {
    param([string]$Path)

    git -C $smokePath check-ignore -q -- $Path
    Assert-True ($LASTEXITCODE -eq 0) "$Path should be ignored"
}

try {
    New-Item -ItemType Directory -Path $helpProbePath | Out-Null
    Push-Location $helpProbePath
    try {
        & $initializer --help | Out-Null
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $helpProbePath "--help"))) "PowerShell --help was treated as a target path"
    }
    finally {
        Pop-Location
    }

    & $initializer -TargetPath $smokePath -ProjectName "Init Smoke Project" -DryRun
    Assert-True (-not (Test-Path -LiteralPath $smokePath)) "DryRun created the target directory"

    & $batchInitializer -TargetPath $batchSmokePath -ProjectName "AWZ Batch Smoke" -DryRun
    Assert-True ($LASTEXITCODE -eq 0) "Batch wrapper dry-run failed"
    Assert-True (-not (Test-Path -LiteralPath $batchSmokePath)) "Batch wrapper dry-run created the target directory"

    & $initializer -TargetPath $smokePath -ProjectName "Init Smoke Project"
    Assert-True (Test-Path -LiteralPath (Join-Path $smokePath ".git")) "Git repository was not initialized"

    $branch = git -C $smokePath symbolic-ref --short HEAD
    Assert-True ($branch -eq "main") "Git branch is not main"

    foreach ($path in @("AGENTS.md", "CLAUDE.md", "docs", "docs/references/README.md", "docs/agent-room/room-ledger.py", "docs/agent-room/guides/room-ledger.md", "docs/agent-room/guides/file-search.md", "docs/agent-room/guides/frontend.md", "docs/agent-room/guides/frontend/visual-composition.md", "docs/agent-room/guides/frontend/motion-and-interaction.md", "docs/agent-room/guides/frontend/responsive-and-verification.md", "temp", ".env")) {
        Assert-Ignored $path
    }

    $agentsContent = Get-Content -LiteralPath (Join-Path $smokePath "AGENTS.md") -Raw -Encoding UTF8
    Assert-True ($agentsContent.Contains("docs/references/README.md")) "AGENTS.md does not expose the reference index entry"
    $statusIndex = $agentsContent.IndexOf("docs/agent-room/status.md")
    $referencesIndex = $agentsContent.IndexOf("docs/references/README.md")
    Assert-True ($statusIndex -ge 0) "AGENTS.md does not expose the status entry"
    Assert-True ($referencesIndex -ge 0) "AGENTS.md does not expose the reference index entry"
    Assert-True ($statusIndex -lt $referencesIndex) "AGENTS.md does not route through status before optional references"
    $generatedReadme = Get-Content -LiteralPath (Join-Path $smokePath "README.md") -Raw -Encoding UTF8
    Assert-True ($generatedReadme.Contains("# Init Smoke Project")) "README.md did not render the project name"
    Assert-True ($generatedReadme.Contains("项目简介 / Overview")) "README.md is missing the bilingual placeholder structure"
    Assert-True (-not $generatedReadme.Contains("AWZ")) "README.md exposes the initializer identity"
    Assert-True (-not $generatedReadme.Contains(".awz/")) "README.md exposes internal reference mapping"
    $generatedCollaborationPath = Join-Path $smokePath "docs/agent-room/guides/collaboration.md"
    $generatedCollaboration = Get-Content -LiteralPath $generatedCollaborationPath -Raw -Encoding UTF8
    foreach ($modeLabel in @("单 Agent", "双 Agent", "三 Agent", "四个及以上 Agent")) {
        Assert-True ($generatedCollaboration.Contains($modeLabel)) "collaboration strategy is missing mode: $modeLabel"
    }

    git -C $smokePath check-ignore -q -- ".env.example"
    Assert-True ($LASTEXITCODE -ne 0) ".env.example must remain trackable"
    $referenceMapPath = Join-Path $smokePath ".awz/references.json"
    Assert-True (Test-Path -LiteralPath $referenceMapPath) ".awz/references.json was not generated"
    git -C $smokePath check-ignore -q -- ".awz/references.json"
    Assert-True ($LASTEXITCODE -ne 0) ".awz/references.json must remain trackable"

    $readmePath = Join-Path $smokePath "README.md"
    Set-Content -LiteralPath $readmePath -Value "custom local README" -Encoding UTF8
    $newModeRejectedOccupiedTarget = $false
    try {
        & $initializer -TargetPath $smokePath
    }
    catch {
        $newModeRejectedOccupiedTarget = $true
    }
    Assert-True $newModeRejectedOccupiedTarget "New mode accepted a non-empty initialized target"
    Assert-True ((Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8).Trim() -eq "custom local README") "Existing README was overwritten without -Force"

    & $initializer -TargetPath $smokePath -Mode Existing
    Assert-True ((Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8).Trim() -eq "custom local README") "Existing mode overwrote README without -Force"

    $agentsPath = Join-Path $smokePath "AGENTS.md"
    $projectContextPath = Join-Path $smokePath "docs/references/README.md"
    $projectStatusPath = Join-Path $smokePath "docs/agent-room/status.md"
    $collaborationPath = $generatedCollaborationPath
    $frontendGuidePath = Join-Path $smokePath "docs/agent-room/guides/frontend.md"
    Set-Content -LiteralPath $referenceMapPath -Value '{"schemaVersion":1,"references":[{"id":"custom"}]}' -Encoding UTF8
    Set-Content -LiteralPath $agentsPath -Value "custom local AGENTS" -Encoding UTF8
    Set-Content -LiteralPath $projectContextPath -Value "custom project context" -Encoding UTF8
    Set-Content -LiteralPath $projectStatusPath -Value "custom project status" -Encoding UTF8
    Set-Content -LiteralPath $collaborationPath -Value "custom collaboration strategy" -Encoding UTF8
    Set-Content -LiteralPath $frontendGuidePath -Value "custom frontend profile" -Encoding UTF8
    & $initializer -TargetPath $smokePath -Mode Existing -Force
    Assert-True ((Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8).Trim() -eq "custom local README") "-Force overwrote a protected project README"
    Assert-True (-not ((Get-Content -LiteralPath $agentsPath -Raw -Encoding UTF8).Contains("custom local AGENTS"))) "-Force did not refresh AWZ-managed AGENTS.md"
    Assert-True ((Get-Content -LiteralPath $referenceMapPath -Raw -Encoding UTF8).Contains('"id":"custom"')) "-Force overwrote project-owned .awz/references.json"
    Assert-True ((Get-Content -LiteralPath $projectContextPath -Raw -Encoding UTF8).Contains("custom project context")) "-Force overwrote project-owned docs/references/README.md"
    Assert-True ((Get-Content -LiteralPath $projectStatusPath -Raw -Encoding UTF8).Contains("custom project status")) "-Force overwrote project-owned status.md"
    Assert-True ((Get-Content -LiteralPath $collaborationPath -Raw -Encoding UTF8).Contains("custom collaboration strategy")) "-Force overwrote project-owned collaboration strategy"
    Assert-True ((Get-Content -LiteralPath $frontendGuidePath -Raw -Encoding UTF8).Contains("custom frontend profile")) "-Force overwrote project-owned frontend profile"

    New-Item -ItemType Directory -Path $occupiedPath | Out-Null
    Set-Content -LiteralPath (Join-Path $occupiedPath "valuable.txt") -Value "preserve me" -Encoding UTF8
    $occupiedTargetRejected = $false
    try {
        & $initializer -TargetPath $occupiedPath -ProjectName "Must Not Merge" -DryRun
    }
    catch {
        $occupiedTargetRejected = $true
    }
    Assert-True $occupiedTargetRejected "New mode did not reject a pre-existing non-empty directory"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $occupiedPath "README.md"))) "Rejected target was modified"

    $forceWithoutExistingRejected = $false
    try {
        & $initializer -TargetPath $occupiedPath -Force -DryRun
    }
    catch {
        $forceWithoutExistingRejected = $true
    }
    Assert-True $forceWithoutExistingRejected "-Force bypassed New mode safety"

    $missingExistingRejected = $false
    try {
        & $initializer -TargetPath $missingExistingPath -Mode Existing -DryRun
    }
    catch {
        $missingExistingRejected = $true
    }
    Assert-True $missingExistingRejected "Existing mode accepted a missing directory"

    Set-Content -LiteralPath $invalidTarget -Value "not a directory" -Encoding UTF8
    $invalidTargetRejected = $false
    try {
        & $initializer -TargetPath $invalidTarget -DryRun
    }
    catch {
        $invalidTargetRejected = $true
    }
    Assert-True $invalidTargetRejected "File target was not rejected"

    $sourceRootRejected = $false
    try {
        & $initializer -TargetPath $root -DryRun
    }
    catch {
        $sourceRootRejected = $true
    }
    Assert-True $sourceRootRejected "AWZ Workflow source directory was not rejected"

    Write-Host "Init smoke passed: $smokePath"
}
finally {
    if (Test-Path -LiteralPath $invalidTarget) {
        Remove-Item -LiteralPath $invalidTarget -Force
    }

    if (-not $KeepArtifacts) {
        foreach ($path in @($smokePath, $batchSmokePath, $helpProbePath, $occupiedPath, $missingExistingPath)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
    }
}

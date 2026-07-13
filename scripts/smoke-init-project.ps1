param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$initializer = Join-Path $PSScriptRoot "init-project.ps1"
$smokePath = Join-Path $root ("temp/smoke-init-" + [guid]::NewGuid().ToString("N"))
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
    & $initializer -TargetPath $smokePath -ProjectName "AWZ Init Smoke" -DryRun
    Assert-True (-not (Test-Path -LiteralPath $smokePath)) "DryRun created the target directory"

    & $initializer -TargetPath $smokePath -ProjectName "AWZ Init Smoke"
    Assert-True (Test-Path -LiteralPath (Join-Path $smokePath ".git")) "Git repository was not initialized"

    $branch = git -C $smokePath symbolic-ref --short HEAD
    Assert-True ($branch -eq "main") "Git branch is not main"

    foreach ($path in @("AGENTS.md", "CLAUDE.md", "docs", "temp", ".env")) {
        Assert-Ignored $path
    }

    git -C $smokePath check-ignore -q -- ".env.example"
    Assert-True ($LASTEXITCODE -ne 0) ".env.example must remain trackable"

    $readmePath = Join-Path $smokePath "README.md"
    Set-Content -LiteralPath $readmePath -Value "custom local README" -Encoding UTF8
    & $initializer -TargetPath $smokePath
    Assert-True ((Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8).Trim() -eq "custom local README") "Existing README was overwritten without -Force"

    & $initializer -TargetPath $smokePath -Force
    Assert-True (-not ((Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8).Contains("custom local README"))) "-Force did not overwrite README"

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

    if ((-not $KeepArtifacts) -and (Test-Path -LiteralPath $smokePath)) {
        Remove-Item -LiteralPath $smokePath -Recurse -Force
    }
}

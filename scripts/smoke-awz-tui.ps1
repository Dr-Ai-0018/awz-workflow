param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$tui = Join-Path $PSScriptRoot "awz.ps1"
$batchTui = Join-Path $PSScriptRoot "awz.bat"
$tuiModule = Join-Path $PSScriptRoot "lib/AwzTui.psm1"
$referenceCli = Join-Path $PSScriptRoot "reference-library.ps1"
$refreshCli = Join-Path $PSScriptRoot "refresh-project.ps1"
$dryRunPath = Join-Path $root ("temp/smoke-tui-dryrun-" + [guid]::NewGuid().ToString("N"))
$batchDryRunPath = Join-Path $root ("temp/smoke-tui-bat-" + [guid]::NewGuid().ToString("N"))
$applyPath = Join-Path $root ("temp/smoke-tui-apply-" + [guid]::NewGuid().ToString("N"))
$occupiedPath = Join-Path $root ("temp/smoke-tui-occupied-" + [guid]::NewGuid().ToString("N"))
$readOnlyFixture = Join-Path $root ("temp/smoke-tui-readonly-" + [guid]::NewGuid().ToString("N"))
$mappingProject = Join-Path $readOnlyFixture "mapping-project"
$previousConfigDir = $env:AWZ_CONFIG_DIR
$previousReferenceRoot = $env:AWZ_REFERENCE_ROOT

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "TUI smoke assertion failed: $Message"
    }
}

try {
    & $tui --help | Out-Null

    $tuiSource = Get-Content -LiteralPath $tui -Raw
    $tuiModuleSource = Get-Content -LiteralPath $tuiModule -Raw
    Assert-True $tuiModuleSource.Contains("Read-Host") "Terminal wizard must use native line editing for text input"
    Assert-True (-not $tuiModuleSource.Contains("[Console]::ReadKey")) "Terminal wizard must not redraw the full screen for every keypress"
    Assert-True $tuiModuleSource.Contains("function Show-AwzTuiLog") "Terminal wizard must retain a dedicated activity-log view"
    Assert-True $tuiModuleSource.Contains('Start-Sleep -Seconds $PauseSeconds') "Activity logs must remain visible before the next view replaces them"
    Assert-True $tuiModuleSource.Contains("H 或 ?") "TUI input pages must expose a help semantic"
    Assert-True $tuiModuleSource.Contains("B 返回上一步") "TUI preview must expose a back semantic"
    Assert-True $tuiSource.Contains("function Invoke-AwzJsonCommand") "Control center must consume structured command results"
    Assert-True $tuiSource.Contains("function Invoke-ReferenceBrowser") "Control center is missing the Reference Library browser"
    Assert-True $tuiSource.Contains("function Invoke-ReferenceAdd") "Control center is missing the Reference add flow"
    Assert-True $tuiSource.Contains("function Invoke-ReferenceMapping") "Control center is missing the project mapping view"
    Assert-True $tuiSource.Contains("function Invoke-ReferenceConfigure") "Control center is missing the Reference configure flow"
    Assert-True $tuiSource.Contains("function Invoke-ReferenceProjectActions") "Control center is missing project mapping lifecycle actions"
    Assert-True $tuiSource.Contains("function Invoke-ReferenceDoctor") "Control center is missing Doctor"
    Assert-True $tuiSource.Contains("function Invoke-RefreshCheck") "Control center is missing the safe refresh check"

    $demo = @(& $tui -RenderDemo)
    $demoText = $demo -join "`n"
    Assert-True ($demo.Count -eq 19) "Rendered terminal wizard frame height changed unexpectedly"
    Assert-True ($demo[0].StartsWith("╭") -and $demo[-1].StartsWith("╰")) "Rendered TUI frame borders are incomplete"
    foreach ($token in @("AWZ WORKFLOW", "HOME [控制中心]", "[1]  创建新项目", "[2]  接入已有项目", "[3]  Reference Library", "[4]  安全刷新检查", "[5]  Doctor", "输入编号")) {
        Assert-True $demoText.Contains($token) "Rendered TUI frame is missing: $token"
    }

    $batchDemo = @(& $batchTui -RenderDemo)
    Assert-True ($LASTEXITCODE -eq 0) "BAT TUI demo render failed"
    Assert-True (($batchDemo -join "`n").Contains("PROJECT CONTROL")) "BAT did not render the full-screen TUI frame"

    & $tui -Action init -TargetPath $dryRunPath -ProjectName "AWZ TUI DryRun" -DryRunOnly
    Assert-True (-not (Test-Path -LiteralPath $dryRunPath)) "PowerShell DryRunOnly created the target"

    & $batchTui -Action init -TargetPath $batchDryRunPath -ProjectName "AWZ TUI Batch" -DryRunOnly
    Assert-True ($LASTEXITCODE -eq 0) "BAT TUI dry-run failed"
    Assert-True (-not (Test-Path -LiteralPath $batchDryRunPath)) "BAT DryRunOnly created the target"

    & $tui -Action init -TargetPath $applyPath -ProjectName "AWZ TUI Apply" -Yes
    Assert-True (Test-Path -LiteralPath (Join-Path $applyPath ".git")) "TUI apply did not initialize Git"
    Assert-True (Test-Path -LiteralPath (Join-Path $applyPath "README.md")) "TUI apply did not write README"

    $configDir = Join-Path $readOnlyFixture "config"
    $referenceRoot = Join-Path $readOnlyFixture "references"
    New-Item -ItemType Directory -Path $configDir, $referenceRoot -Force | Out-Null
    $env:AWZ_CONFIG_DIR = $configDir
    $env:AWZ_REFERENCE_ROOT = $referenceRoot

    $listText = @(& $referenceCli list --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Structured Reference Library list failed"
    $listResult = $listText | ConvertFrom-Json
    Assert-True ($listResult.operation -eq "reference.list") "Reference list returned the wrong operation contract"
    Assert-True ($listResult.data.references.Count -eq 0) "Isolated Reference list unexpectedly returned real entries"

    $doctorText = @(& $referenceCli doctor --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Structured Reference Library Doctor failed"
    $doctorResult = $doctorText | ConvertFrom-Json
    Assert-True ($doctorResult.operation -eq "reference.doctor") "Doctor returned the wrong operation contract"
    Assert-True ($doctorResult.data.referenceRoot -eq $referenceRoot) "Doctor escaped the isolated reference root"

    New-Item -ItemType Directory -Path (Join-Path $mappingProject ".awz") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $mappingProject ".awz/references.json") -Value '{"schemaVersion":1,"references":[{"id":"missing-fixture","purpose":"smoke mapping","required":true,"notes":""}]}' -Encoding UTF8
    $mappingText = @(& $referenceCli status --project $mappingProject --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Structured project mapping status failed"
    $mappingResult = $mappingText | ConvertFrom-Json
    Assert-True ($mappingResult.data.projectMappingEntries.Count -eq 1) "Project mapping entry was not exposed"
    Assert-True ($mappingResult.data.projectMappingEntries[0].status -eq "unresolved") "Unresolved project mapping status changed"
    Assert-True ($mappingResult.data.projectMappingEntries[0].purpose -eq "smoke mapping") "Project mapping purpose was lost"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $mappingProject "docs/references/reference-context.md"))) "Mapping status generated context"

    $missingReferenceRoot = Join-Path $readOnlyFixture "missing-references"
    $env:AWZ_REFERENCE_ROOT = $missingReferenceRoot
    $blockedDoctorText = @(& $referenceCli doctor --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 1) "Doctor did not preserve its structured problem exit code"
    $blockedDoctorResult = $blockedDoctorText | ConvertFrom-Json
    Assert-True ($blockedDoctorResult.operation -eq "reference.doctor") "Problem Doctor output was not structured JSON"
    Assert-True (-not [bool]$blockedDoctorResult.data.rootExists) "Problem Doctor unexpectedly created the missing root"
    $env:AWZ_REFERENCE_ROOT = $referenceRoot

    $refreshText = @(& $refreshCli --target $applyPath --dry-run --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Structured refresh DryRun failed"
    $refreshResult = $refreshText | ConvertFrom-Json
    Assert-True ($refreshResult.operation -eq "project.refresh") "Refresh returned the wrong operation contract"
    Assert-True ([bool]$refreshResult.dryRun) "Refresh check was not a DryRun"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $applyPath "docs/agent-room/.awz-manifest.json"))) "Refresh check wrote a manifest"

    Add-Content -LiteralPath (Join-Path $applyPath "AGENTS.md") -Value "local smoke change" -Encoding UTF8
    $conflictRefreshText = @(& $refreshCli --target $applyPath --dry-run --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 2) "Refresh conflict did not preserve exit code 2"
    $conflictRefreshResult = $conflictRefreshText | ConvertFrom-Json
    Assert-True ($conflictRefreshResult.plan.blockedBy.Count -gt 0) "Refresh conflict omitted structured blockers"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $applyPath "docs/agent-room/.awz-manifest.json"))) "Blocked refresh wrote a manifest"

    New-Item -ItemType Directory -Path $occupiedPath | Out-Null
    Set-Content -LiteralPath (Join-Path $occupiedPath "valuable.txt") -Value "preserve me" -Encoding UTF8
    $occupiedRejected = $false
    try {
        & $tui -Action init -TargetPath $occupiedPath -ProjectName "Must Not Merge" -DryRunOnly
    }
    catch {
        $occupiedRejected = $true
    }
    Assert-True $occupiedRejected "TUI accepted an occupied target in New mode"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $occupiedPath "README.md"))) "Rejected TUI target was modified"

    Write-Host "AWZ TUI smoke passed"
}
finally {
    $env:AWZ_CONFIG_DIR = $previousConfigDir
    $env:AWZ_REFERENCE_ROOT = $previousReferenceRoot
    if (-not $KeepArtifacts) {
        foreach ($path in @($dryRunPath, $batchDryRunPath, $applyPath, $occupiedPath, $readOnlyFixture)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
    }
}

param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$tui = Join-Path $PSScriptRoot "awz.ps1"
$batchTui = Join-Path $PSScriptRoot "awz.bat"
$tuiModule = Join-Path $PSScriptRoot "lib/AwzTui.psm1"
$dryRunPath = Join-Path $root ("temp/smoke-tui-dryrun-" + [guid]::NewGuid().ToString("N"))
$batchDryRunPath = Join-Path $root ("temp/smoke-tui-bat-" + [guid]::NewGuid().ToString("N"))
$applyPath = Join-Path $root ("temp/smoke-tui-apply-" + [guid]::NewGuid().ToString("N"))
$occupiedPath = Join-Path $root ("temp/smoke-tui-occupied-" + [guid]::NewGuid().ToString("N"))

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

    $tuiModuleSource = Get-Content -LiteralPath $tuiModule -Raw
    Assert-True $tuiModuleSource.Contains("Read-Host") "Terminal wizard must use native line editing for text input"
    Assert-True (-not $tuiModuleSource.Contains("[Console]::ReadKey")) "Terminal wizard must not redraw the full screen for every keypress"
    Assert-True $tuiModuleSource.Contains("function Show-AwzTuiLog") "Terminal wizard must retain a dedicated activity-log view"
    Assert-True $tuiModuleSource.Contains('Start-Sleep -Seconds $PauseSeconds') "Activity logs must remain visible before the next view replaces them"

    $demo = @(& $tui -RenderDemo)
    $demoText = $demo -join "`n"
    Assert-True ($demo.Count -eq 19) "Rendered terminal wizard frame height changed unexpectedly"
    Assert-True ($demo[0].StartsWith("╭") -and $demo[-1].StartsWith("╰")) "Rendered TUI frame borders are incomplete"
    foreach ($token in @("AWZ WORKFLOW", "01 [模式]", "[1]  创建新项目", "[2]  接入已有项目", "输入编号")) {
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
    if (-not $KeepArtifacts) {
        foreach ($path in @($dryRunPath, $batchDryRunPath, $applyPath, $occupiedPath)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
    }
}

param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$initializer = Join-Path $PSScriptRoot "init-project.ps1"
$refresh = Join-Path $PSScriptRoot "refresh-project.ps1"
$smokeRoot = Join-Path $root ("temp/smoke-refresh-" + [guid]::NewGuid().ToString("N"))
$project = Join-Path $smokeRoot "project"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "Refresh smoke assertion failed: $Message"
    }
}
try {
    & $initializer -TargetPath $project -ProjectName "Refresh Smoke Project"

    $previewText = @(& $refresh --target $project --dry-run --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Initial refresh DryRun failed"
    $preview = $previewText | ConvertFrom-Json
    Assert-True ($preview.operation -eq "project.refresh") "Unexpected refresh operation contract"
    Assert-True ($preview.plan.blockedBy.Count -eq 0) "Fresh initialized project was blocked"
    Assert-True ($preview.plan.changes.Count -eq 1) "First refresh should only adopt the manifest"

    $planHash = $preview.plan.planHash
    $applyText = @(& $refresh --target $project --apply --plan-hash $planHash --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Refresh apply failed"
    $apply = $applyText | ConvertFrom-Json
    Assert-True ($apply.data.transaction.state -eq "completed") "Refresh transaction did not complete"
    $manifest = Join-Path $project "docs/agent-room/.awz-manifest.json"
    Assert-True (Test-Path -LiteralPath $manifest -PathType Leaf) "Refresh manifest was not written"

    $secondText = @(& $refresh --target $project --dry-run --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 0) "Stable second DryRun failed"
    $second = $secondText | ConvertFrom-Json
    Assert-True ($second.plan.changes.Count -eq 0) "Stable refresh was not a no-op"

    Add-Content -LiteralPath (Join-Path $project "AGENTS.md") -Value "local project rule" -Encoding UTF8
    $conflictText = @(& $refresh --target $project --dry-run --json) -join "`n"
    Assert-True ($LASTEXITCODE -eq 2) "Local modification did not return the blocked exit code"
    $conflict = $conflictText | ConvertFrom-Json
    Assert-True ($conflict.plan.blockedBy.Count -gt 0) "Local modification was not reported as blocked"

    Write-Host "AWZ refresh smoke passed: $smokeRoot"
}
finally {
    if ((-not $KeepArtifacts) -and (Test-Path -LiteralPath $smokeRoot)) {
        Remove-Item -LiteralPath $smokeRoot -Recurse -Force
    }
}

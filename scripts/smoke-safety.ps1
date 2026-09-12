param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path $root "temp"
$fixture = Join-Path $tempRoot ("smoke-safety-" + [guid]::NewGuid().ToString("N"))
$outside = Join-Path $root ("not-smoke-safety-" + [guid]::NewGuid().ToString("N"))
$wrongIdentity = Join-Path $tempRoot ("safety-fixture-" + [guid]::NewGuid().ToString("N"))
$traversal = Join-Path $fixture "../../not-smoke-safety"

Import-Module (Join-Path $PSScriptRoot "lib/AwzSafety.psm1") -Force

function Assert-Rejected {
    param([string]$Path, [string]$Message)

    $rejected = $false
    try {
        Assert-AwzSafeRemovalTarget -Path $Path -AllowedRoot $tempRoot | Out-Null
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw "Safety smoke assertion failed: $Message"
    }
}

New-Item -ItemType Directory -Path $fixture -Force | Out-Null
New-Item -ItemType Directory -Path $outside -Force | Out-Null
New-Item -ItemType Directory -Path $wrongIdentity -Force | Out-Null
try {
    Assert-Rejected -Path "" -Message "empty path was accepted"
    Assert-Rejected -Path ([IO.Path]::GetPathRoot($root)) -Message "filesystem root was accepted"
    Assert-Rejected -Path $root -Message "repository root was accepted"
    Assert-Rejected -Path $tempRoot -Message "temp root was accepted"
    Assert-Rejected -Path $outside -Message "outside path was accepted"
    Assert-Rejected -Path $wrongIdentity -Message "wrong directory identity was accepted"
    Assert-Rejected -Path $traversal -Message "path traversal was accepted"
    Assert-Rejected -Path ([Environment]::GetFolderPath("UserProfile")) -Message "user profile was accepted"

    $emptyRemovalRejected = $false
    try {
        Remove-AwzSafeTree -Path "" -AllowedRoot $tempRoot
    }
    catch {
        $emptyRemovalRejected = $true
    }
    if (-not $emptyRemovalRejected) {
        throw "Safety smoke assertion failed: empty removal was silently accepted"
    }

    $accepted = Assert-AwzSafeRemovalTarget -Path $fixture -AllowedRoot $tempRoot
    if ($accepted -ne [IO.Path]::GetFullPath($fixture)) {
        throw "Safety smoke assertion failed: valid fixture resolved unexpectedly"
    }

    Remove-AwzSafeTree -Path $fixture -AllowedRoot $tempRoot
    if (Test-Path -LiteralPath $fixture) {
        throw "Safety smoke assertion failed: valid fixture was not removed"
    }
    Write-Host "Safety smoke passed"
}
finally {
    if (Test-Path -LiteralPath $fixture) {
        Remove-AwzSafeTree -Path $fixture -AllowedRoot $tempRoot
    }
    if (Test-Path -LiteralPath $outside) {
        Remove-Item -LiteralPath $outside -Force
    }
    if (Test-Path -LiteralPath $wrongIdentity) {
        Remove-Item -LiteralPath $wrongIdentity -Force
    }
}

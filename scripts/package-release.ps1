param(
    [string]$OutputDirectory = "",
    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"

function Show-Usage {
    @"
Usage:
  .\scripts\package-release.ps1 [-OutputDirectory <path>] [-AllowDirty]

Options:
  -OutputDirectory <path>  Directory for the .tar.gz package. Defaults to dist.
  -AllowDirty              Allow packaging from a dirty worktree for local smoke tests.
"@
}

if ($args -contains "--help" -or $args -contains "-h") {
    Show-Usage
    exit 0
}

$root = Split-Path -Parent $PSScriptRoot
$versionPath = Join-Path $root "VERSION"
$changelogPath = Join-Path $root "CHANGELOG.md"

if (-not (Test-Path -LiteralPath $versionPath)) {
    throw "VERSION is missing."
}

if (-not (Test-Path -LiteralPath $changelogPath)) {
    throw "CHANGELOG.md is missing."
}

$version = (Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8).Trim()
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$') {
    throw "Invalid VERSION: $version"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required to validate the release worktree."
}

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
    throw "tar is required to create the release package."
}

if (-not $AllowDirty) {
    $dirty = git -C $root status --porcelain
    if ($dirty) {
        throw "Worktree is dirty. Commit or stash changes before packaging, or use -AllowDirty only for a local smoke test."
    }
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $root "dist"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
$releaseDirectoryName = "awz-workflow-v$version"
$packagePath = Join-Path $outputPath "$releaseDirectoryName.tar.gz"

if (Test-Path -LiteralPath $packagePath) {
    throw "Package already exists: $packagePath"
}

$tempRoot = Join-Path $root "temp"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$stageParent = Join-Path $tempRoot ("release-stage-" + [guid]::NewGuid().ToString("N"))
$stageRoot = Join-Path $stageParent $releaseDirectoryName

try {
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

    $releasePaths = @(
        "VERSION",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "requirements",
        "style",
        "workflows",
        "templates",
        "scripts"
    )

    foreach ($relativePath in $releasePaths) {
        $source = Join-Path $root $relativePath
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Release source is missing: $relativePath"
        }

        Copy-Item -LiteralPath $source -Destination (Join-Path $stageRoot $relativePath) -Recurse -Force
    }

    Get-ChildItem -LiteralPath $stageRoot -Recurse -Directory -Filter "__pycache__" |
        Sort-Object FullName -Descending |
        Remove-Item -Recurse -Force
    Get-ChildItem -LiteralPath $stageRoot -Recurse -File -Include "*.pyc", "*.pyo" |
        Remove-Item -Force

    & tar -C $stageParent -czf $packagePath $releaseDirectoryName
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed with exit code $LASTEXITCODE"
    }

    Write-Host "Created release package: $packagePath"
}
finally {
    if (Test-Path -LiteralPath $stageParent) {
        Remove-Item -LiteralPath $stageParent -Recurse -Force
    }
}

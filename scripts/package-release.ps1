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
  -AllowDirty              Allow packaging committed HEAD from a dirty worktree; dirty changes are excluded.
"@
}

if ($args -contains "--help" -or $args -contains "-h") {
    Show-Usage
    exit 0
}

$root = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required to validate the release worktree."
}

$version = ((& git -C $root show "HEAD:VERSION") -join "`n").Trim()
if ($LASTEXITCODE -ne 0) {
    throw "VERSION is missing from HEAD."
}
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$') {
    throw "Invalid VERSION in HEAD: $version"
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
    & git -C $root cat-file -e "HEAD:$relativePath"
    if ($LASTEXITCODE -ne 0) {
        throw "Release source is missing from HEAD: $relativePath"
    }
}

& git -C $root -c core.autocrlf=false archive --format=tar.gz "--prefix=$releaseDirectoryName/" "--output=$packagePath" HEAD -- @releasePaths
if ($LASTEXITCODE -ne 0) {
    if (Test-Path -LiteralPath $packagePath) {
        Remove-Item -LiteralPath $packagePath -Force
    }
    throw "git archive failed with exit code $LASTEXITCODE"
}

Write-Host "Created release package from committed HEAD: $packagePath"

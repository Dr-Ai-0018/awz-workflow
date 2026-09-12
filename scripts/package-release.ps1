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
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw "Python 3 is required to create a byte-stable release archive."
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
$tarPath = Join-Path $outputPath ".$releaseDirectoryName.$([guid]::NewGuid().ToString('N')).tar"

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

try {
    & git -C $root -c core.autocrlf=false archive --format=tar "--prefix=$releaseDirectoryName/" "--output=$tarPath" HEAD -- @releasePaths
    if ($LASTEXITCODE -ne 0) {
        throw "git archive failed with exit code $LASTEXITCODE"
    }
    & $python.Source (Join-Path $PSScriptRoot "lib\deterministic_gzip.py") $tarPath $packagePath
    if ($LASTEXITCODE -ne 0) {
        throw "deterministic gzip failed with exit code $LASTEXITCODE"
    }
}
catch {
    if (Test-Path -LiteralPath $packagePath) {
        Remove-Item -LiteralPath $packagePath -Force
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $tarPath) {
        Remove-Item -LiteralPath $tarPath -Force
    }
}

Write-Host "Created release package from committed HEAD: $packagePath"

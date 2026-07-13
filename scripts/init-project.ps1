param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$ProjectName = "",
    [string]$Owner = "AWZ Workflow contributors",
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$templateRoot = Join-Path $root "templates/project"
$rootPath = (Resolve-Path -LiteralPath $root).Path

if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template directory not found: $templateRoot"
}

$target = Get-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue

if ($null -eq $target) {
    $targetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetPath)
    if ($DryRun) {
        Write-Host "DryRun: target directory does not exist; would create $targetPath"
    }
}
else {
    if (-not $target.PSIsContainer) {
        throw "Target path is not a directory: $TargetPath"
    }

    $targetPath = $target.FullName
}

if ([string]::Equals($targetPath, $rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Target path cannot be the AWZ Workflow source directory: $rootPath"
}

$needsGitInit = -not (Test-Path -LiteralPath (Join-Path $targetPath ".git"))
$gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if ($needsGitInit -and (-not $gitAvailable)) {
    if ($DryRun) {
        Write-Host "DryRun: git is unavailable; real initialization would stop before writing files."
    }
    else {
        throw "Git is required to initialize a new repository. Install Git, then run the initializer again."
    }
}

if (($null -eq $target) -and (-not $DryRun)) {
    New-Item -ItemType Directory -Path $TargetPath | Out-Null
    $targetPath = (Resolve-Path -LiteralPath $TargetPath).Path
}

$resolvedProjectName = if ($ProjectName) { $ProjectName } else { Split-Path -Leaf $targetPath }
$resolvedYear = (Get-Date).Year.ToString()

function Get-TemplateContent {
    param([string]$SourceName)

    $source = Join-Path $templateRoot $SourceName
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Template file not found: $SourceName"
    }

    $content = Get-Content -LiteralPath $source -Raw -Encoding UTF8
    $content = $content.Replace("{{PROJECT_NAME}}", $script:resolvedProjectName)
    $content = $content.Replace("{{YEAR}}", $script:resolvedYear)
    $content = $content.Replace("{{OWNER}}", $Owner)
    return $content
}

function Write-GeneratedFile {
    param(
        [string]$SourceName,
        [string]$DestName,
        [switch]$Render
    )

    $dest = Join-Path $targetPath $DestName
    $destDir = Split-Path -Parent $dest

    if ((Test-Path -LiteralPath $dest) -and (-not $Force)) {
        Write-Host "Skip existing file: $DestName"
        return
    }

    if ($DryRun) {
        if ((Test-Path -LiteralPath $dest) -and $Force) {
            Write-Host "DryRun: would overwrite $DestName"
        }
        else {
            Write-Host "DryRun: would write $DestName"
        }
        return
    }

    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }

    if ($Render) {
        $content = Get-TemplateContent $SourceName
        Set-Content -LiteralPath $dest -Value $content -Encoding UTF8
    }
    else {
        $source = Join-Path $templateRoot $SourceName
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Template file not found: $SourceName"
        }
        Copy-Item -LiteralPath $source -Destination $dest -Force:$Force
    }

    Write-Host "Wrote $DestName"
}

function Ensure-LocalDirectory {
    param([string]$DirName)

    $path = Join-Path $targetPath $DirName
    if (Test-Path -LiteralPath $path) {
        return
    }

    if ($DryRun) {
        Write-Host "DryRun: would create directory $DirName"
        return
    }

    New-Item -ItemType Directory -Path $path | Out-Null
    Write-Host "Created directory $DirName"
}

$rootFiles = @(
    @{ Source = "AGENTS.md"; Dest = "AGENTS.md"; Render = $false },
    @{ Source = "CLAUDE.md"; Dest = "CLAUDE.md"; Render = $false },
    @{ Source = "gitignore.template"; Dest = ".gitignore"; Render = $false },
    @{ Source = "env.example"; Dest = ".env.example"; Render = $false },
    @{ Source = "README.template.md"; Dest = "README.md"; Render = $true },
    @{ Source = "LICENSE-MIT"; Dest = "LICENSE"; Render = $true }
)

foreach ($file in $rootFiles) {
    Write-GeneratedFile -SourceName $file.Source -DestName $file.Dest -Render:([bool]$file.Render)
}

$localDirs = @(
    "docs",
    "docs/agent-room",
    "docs/agent-room/guides",
    "docs/agent-room/handoffs",
    "docs/agent-room/reviews",
    "docs/agent-room/decisions",
    "docs/agent-room/notes",
    "docs/plans",
    "temp",
    "temp/scripts",
    "temp/output",
    "temp/assets",
    "temp/screenshots",
    "temp/experiments",
    "temp/logs"
)

foreach ($dir in $localDirs) {
    Ensure-LocalDirectory $dir
}

$localFiles = @(
    @{ Source = "docs-layout.md"; Dest = "docs/README.md"; Render = $false },
    @{ Source = "agent-onboarding.md"; Dest = "docs/agent-room/onboarding.md"; Render = $false },
    @{ Source = "guides/collaboration.md"; Dest = "docs/agent-room/guides/collaboration.md"; Render = $false },
    @{ Source = "guides/repository-hygiene.md"; Dest = "docs/agent-room/guides/repository-hygiene.md"; Render = $false },
    @{ Source = "guides/git-workflow.md"; Dest = "docs/agent-room/guides/git-workflow.md"; Render = $false },
    @{ Source = "guides/verification.md"; Dest = "docs/agent-room/guides/verification.md"; Render = $false },
    @{ Source = "guides/code-architecture.md"; Dest = "docs/agent-room/guides/code-architecture.md"; Render = $false },
    @{ Source = "guides/frontend.md"; Dest = "docs/agent-room/guides/frontend.md"; Render = $false },
    @{ Source = "guides/blockers-and-safety.md"; Dest = "docs/agent-room/guides/blockers-and-safety.md"; Render = $false },
    @{ Source = "guides/review.md"; Dest = "docs/agent-room/guides/review.md"; Render = $false },
    @{ Source = "agent-status.template.md"; Dest = "docs/agent-room/status.md"; Render = $true },
    @{ Source = "handoff.template.md"; Dest = "docs/agent-room/handoffs/handoff.template.md"; Render = $false },
    @{ Source = "review-checklist.template.md"; Dest = "docs/agent-room/reviews/review-checklist.template.md"; Render = $false },
    @{ Source = "decision-record.template.md"; Dest = "docs/agent-room/decisions/decision-record.template.md"; Render = $false },
    @{ Source = "release-checklist.template.md"; Dest = "docs/plans/release-checklist.template.md"; Render = $false },
    @{ Source = "temp-layout.md"; Dest = "temp/README.md"; Render = $false }
)

foreach ($file in $localFiles) {
    Write-GeneratedFile -SourceName $file.Source -DestName $file.Dest -Render:([bool]$file.Render)
}

if ($needsGitInit) {
    if ($DryRun) {
        Write-Host "DryRun: would run git init -b main"
    }
    else {
        git -C $targetPath init -b main | Out-Null
        Write-Host "Ran git init -b main"
    }
}

if ($DryRun) {
    Write-Host "DryRun: will not generate pyproject.toml, package.json, Docker, CI, or deployment config unless a matching project type is chosen later."
    Write-Host "DryRun: preview complete; no files were written: $targetPath"
}
else {
    Write-Host "AWZ project baseline initialized: $targetPath"
}

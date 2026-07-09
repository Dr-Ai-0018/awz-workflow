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

if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "模板目录不存在：$templateRoot"
}

$target = Resolve-Path -LiteralPath $TargetPath -ErrorAction SilentlyContinue

if ($null -eq $target) {
    $targetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetPath)
    if ($DryRun) {
        Write-Host "DryRun：目标目录不存在，将创建 $targetPath"
    }
    else {
        New-Item -ItemType Directory -Path $TargetPath | Out-Null
        $targetPath = (Resolve-Path -LiteralPath $TargetPath).Path
    }
}
else {
    $targetPath = $target.Path
}

$resolvedProjectName = if ($ProjectName) { $ProjectName } else { Split-Path -Leaf $targetPath }
$resolvedYear = (Get-Date).Year.ToString()

function Get-TemplateContent {
    param([string]$SourceName)

    $source = Join-Path $templateRoot $SourceName
    if (-not (Test-Path -LiteralPath $source)) {
        throw "模板文件不存在：$SourceName"
    }

    $content = Get-Content -LiteralPath $source -Raw
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
        Write-Host "跳过已存在文件 $DestName"
        return
    }

    if ($DryRun) {
        if ((Test-Path -LiteralPath $dest) -and $Force) {
            Write-Host "DryRun：将覆盖 $DestName"
        }
        else {
            Write-Host "DryRun：将写入 $DestName"
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
            throw "模板文件不存在：$SourceName"
        }
        Copy-Item -LiteralPath $source -Destination $dest -Force:$Force
    }

    Write-Host "写入 $DestName"
}

function Ensure-LocalDirectory {
    param([string]$DirName)

    $path = Join-Path $targetPath $DirName
    if (Test-Path -LiteralPath $path) {
        return
    }

    if ($DryRun) {
        Write-Host "DryRun：将创建目录 $DirName"
        return
    }

    New-Item -ItemType Directory -Path $path | Out-Null
    Write-Host "创建目录 $DirName"
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

if (-not (Test-Path -LiteralPath (Join-Path $targetPath ".git"))) {
    if ($DryRun) {
        Write-Host "DryRun：将执行 git init -b main"
    }
    else {
        git -C $targetPath init -b main | Out-Null
        Write-Host "已执行 git init -b main"
    }
}

if ($DryRun) {
    Write-Host "DryRun：不会生成 pyproject.toml、package.json、Docker、CI 或部署配置，除非后续明确选择对应项目类型。"
    Write-Host "DryRun：预演完成，未写入任何文件：$targetPath"
}
else {
    Write-Host "AWZ 项目基线已初始化：$targetPath"
}

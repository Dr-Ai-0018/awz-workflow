param(
    [string]$Action = "",
    [string]$TargetPath = "",
    [string]$ProjectName = "",
    [string]$Owner = "AWZ Workflow contributors",
    [string]$Mode = "",
    [switch]$Force,
    [switch]$Yes,
    [switch]$DryRunOnly,
    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Usage {
    @"
AWZ Workflow TUI

Interactive:
  .\scripts\awz.ps1

Scriptable:
  .\scripts\awz.ps1 -Action init -TargetPath <path> [options]

Options:
  -Action init          Run project initialization.
  -TargetPath <path>   Target project directory.
  -ProjectName <name>  Project name. Defaults to the target directory name.
  -Owner <name>        MIT license owner.
  -Mode New|Existing   Initialization mode. Defaults to New.
  -Force               Refresh AWZ-managed files in Existing mode.
  -DryRunOnly          Stop after the mandatory preview.
  -Yes                  Apply after preview without an interactive confirmation.
  -Help, -h, --help    Show this help message.
"@
}

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$Value
    )

    if ($Value) {
        return $Value
    }

    $result = Read-Host $Prompt
    if (-not $result) {
        throw "$Prompt cannot be empty."
    }
    return $result
}

if ($Help -or $Action -in @("--help", "-h", "help")) {
    Show-Usage
    return
}

$scriptRoot = $PSScriptRoot
$initializer = Join-Path $scriptRoot "init-project.ps1"
if (-not (Test-Path -LiteralPath $initializer -PathType Leaf)) {
    throw "Initializer not found: $initializer"
}

$interactiveMenu = -not $Action
if ($interactiveMenu) {
    Write-Host "AWZ Workflow" -ForegroundColor Cyan
    Write-Host "安全初始化与项目接入"
    Write-Host ""
    Write-Host "  1. 创建新项目"
    Write-Host "  2. 接入已有项目"
    Write-Host "  Q. 退出"
    Write-Host ""

    $choice = (Read-Host "请选择").Trim().ToLowerInvariant()
    switch ($choice) {
        "1" {
            $Action = "init"
            $Mode = "New"
        }
        "2" {
            $Action = "init"
            $Mode = "Existing"
        }
        "q" {
            Write-Host "已退出。"
            return
        }
        default {
            throw "Unknown menu choice: $choice"
        }
    }
}

if ($Action.ToLowerInvariant() -ne "init") {
    throw "Unsupported action: $Action. Current TUI supports init only."
}

if (-not $Mode) {
    $Mode = "New"
}
switch ($Mode.ToLowerInvariant()) {
    "new" { $Mode = "New" }
    "existing" { $Mode = "Existing" }
    default { throw "Mode must be New or Existing: $Mode" }
}

$TargetPath = Read-RequiredValue -Prompt "目标目录" -Value $TargetPath
if (-not $ProjectName) {
    $trimmedTarget = $TargetPath.TrimEnd([char[]]@('\', '/'))
    $ProjectName = Split-Path -Leaf $trimmedTarget
    if (-not $ProjectName) {
        throw "Cannot infer ProjectName from target path: $TargetPath"
    }
}

if ($interactiveMenu -and $Mode -eq "Existing" -and (-not $Force)) {
    Write-Host ""
    Write-Host "默认只补充缺失文件，不覆盖已有内容。" -ForegroundColor Yellow
    $refreshChoice = (Read-Host "是否刷新 AWZ 管理的本地指导文件？[y/N]").Trim().ToLowerInvariant()
    $Force = $refreshChoice -in @("y", "yes")
}

$initParams = @{
    TargetPath = $TargetPath
    ProjectName = $ProjectName
    Owner = $Owner
    Mode = $Mode
}
if ($Force) {
    $initParams.Force = $true
}

Write-Section "变更预览"
Write-Host "目标：$TargetPath"
Write-Host "项目：$ProjectName"
Write-Host "模式：$Mode"
Write-Host "刷新 AWZ 文件：$([bool]$Force)"
Write-Host ""

# The preview is mandatory. A failed preview prevents every apply path, including -Yes.
& $initializer @initParams -DryRun

if ($DryRunOnly) {
    Write-Host ""
    Write-Host "DryRunOnly：未写入任何文件。" -ForegroundColor Green
    return
}

$confirmed = [bool]$Yes
if (-not $confirmed) {
    Write-Section "执行确认"
    if ($Mode -eq "Existing" -and $Force) {
        Write-Host "将刷新已有项目中的 AWZ 管理文件。项目自有根文件仍受保护。" -ForegroundColor Yellow
        $answer = Read-Host "输入 APPLY 继续"
        $confirmed = $answer -ceq "APPLY"
    }
    else {
        $answer = (Read-Host "确认执行？[y/N]").Trim().ToLowerInvariant()
        $confirmed = $answer -in @("y", "yes")
    }
}

if (-not $confirmed) {
    Write-Host "已取消，未执行写入。" -ForegroundColor Yellow
    return
}

Write-Section "执行初始化"
& $initializer @initParams

Write-Section "完成"
Write-Host "项目已处理：$TargetPath" -ForegroundColor Green
if (Test-Path -LiteralPath (Join-Path $TargetPath ".git")) {
    Write-Host ""
    Write-Host "git status --short"
    & git -C $TargetPath status --short
}

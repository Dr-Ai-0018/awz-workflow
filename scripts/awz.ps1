param(
    [string]$Action = "",
    [string]$TargetPath = "",
    [string]$ProjectName = "",
    [string]$Owner = "AWZ Workflow contributors",
    [string]$Mode = "",
    [switch]$Force,
    [switch]$Yes,
    [switch]$DryRunOnly,
    [switch]$Classic,
    [switch]$RenderDemo,
    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$tuiModule = Join-Path $PSScriptRoot "lib/AwzTui.psm1"
Import-Module $tuiModule -Force -ErrorAction Stop

function Show-Usage {
    @"
AWZ Workflow TUI

Interactive full-screen TUI:
  .\scripts\awz.bat
  .\scripts\awz.ps1

Classic prompt fallback:
  .\scripts\awz.ps1 -Classic

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
  -Classic              Use line-oriented prompts instead of the full-screen TUI.
  -RenderDemo           Print a deterministic visual frame for preview/testing.
  -Help, -h, --help    Show this help message.

PowerShell paths containing spaces:
  & 'E:\Project\AWZ Workflow\scripts\awz.ps1'
"@
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

function Normalize-Mode {
    param([string]$Value)

    if (-not $Value) {
        return "New"
    }
    switch ($Value.ToLowerInvariant()) {
        "new" { return "New" }
        "existing" { return "Existing" }
        default { throw "Mode must be New or Existing: $Value" }
    }
}

function New-InitParams {
    param(
        [string]$Target,
        [string]$Project,
        [string]$LicenseOwner,
        [string]$SelectedMode,
        [bool]$Refresh
    )

    $params = @{
        TargetPath = $Target
        ProjectName = $Project
        Owner = $LicenseOwner
        Mode = $SelectedMode
    }
    if ($Refresh) {
        $params.Force = $true
    }
    return $params
}

function Invoke-ScriptedFlow {
    param(
        [string]$InitializerPath,
        [bool]$UseClassicMenu
    )

    if ($UseClassicMenu -and (-not $script:Action)) {
        Write-Host "AWZ Workflow" -ForegroundColor Cyan
        Write-Host "安全初始化与项目接入"
        Write-Host ""
        Write-Host "  1. 创建新项目"
        Write-Host "  2. 接入已有项目"
        Write-Host "  Q. 退出"
        $choice = (Read-Host "请选择").Trim().ToLowerInvariant()
        switch ($choice) {
            "1" { $script:Action = "init"; $script:Mode = "New" }
            "2" { $script:Action = "init"; $script:Mode = "Existing" }
            "q" { Write-Host "已退出。"; return }
            default { throw "Unknown menu choice: $choice" }
        }
    }

    if ($script:Action.ToLowerInvariant() -ne "init") {
        throw "Unsupported action: $($script:Action). Current TUI supports init only."
    }
    $script:Mode = Normalize-Mode $script:Mode
    $script:TargetPath = Read-RequiredValue -Prompt "目标目录" -Value $script:TargetPath
    if (-not $script:ProjectName) {
        $trimmedTarget = $script:TargetPath.TrimEnd([char[]]@('\', '/'))
        $script:ProjectName = Split-Path -Leaf $trimmedTarget
    }
    if (-not $script:ProjectName) {
        throw "Cannot infer ProjectName from target path: $($script:TargetPath)"
    }

    if ($UseClassicMenu -and $script:Mode -eq "Existing" -and (-not $script:Force)) {
        $refreshChoice = (Read-Host "是否刷新 AWZ 管理的本地指导文件？[y/N]").Trim().ToLowerInvariant()
        $script:Force = $refreshChoice -in @("y", "yes")
    }

    $params = New-InitParams -Target $script:TargetPath -Project $script:ProjectName -LicenseOwner $script:Owner -SelectedMode $script:Mode -Refresh ([bool]$script:Force)
    Write-Host ""
    Write-Host "== 变更预览 ==" -ForegroundColor Cyan
    Write-Host "目标：$($script:TargetPath)"
    Write-Host "项目：$($script:ProjectName)"
    Write-Host "模式：$($script:Mode)"
    Write-Host ""
    & $InitializerPath @params -DryRun

    if ($script:DryRunOnly) {
        Write-Host "DryRunOnly：未写入任何文件。" -ForegroundColor Green
        return
    }

    $confirmed = [bool]$script:Yes
    if (-not $confirmed) {
        if ($script:Mode -eq "Existing" -and $script:Force) {
            $confirmed = (Read-Host "输入 APPLY 继续") -ceq "APPLY"
        }
        else {
            $confirmed = (Read-Host "确认执行？[y/N]").Trim().ToLowerInvariant() -in @("y", "yes")
        }
    }
    if (-not $confirmed) {
        Write-Host "已取消，未执行写入。" -ForegroundColor Yellow
        return
    }

    & $InitializerPath @params
    Write-Host "项目已处理：$($script:TargetPath)" -ForegroundColor Green
    if (Test-Path -LiteralPath (Join-Path $script:TargetPath ".git")) {
        & git -C $script:TargetPath status --short
    }
}

function Invoke-FullScreenTui {
    param([string]$InitializerPath)

    $oldCursorVisible = $true
    try {
        $oldCursorVisible = [Console]::CursorVisible
        [Console]::CursorVisible = $false

        $selectedMode = Select-AwzTuiOption -Title "选择工作模式" -Subtitle "新项目与已有项目采用完全不同的安全边界" -Step "01 [模式]  ───   02  信息   ───   03  预览   ───   04  执行" -Options @(
            [pscustomobject]@{ Label = "创建新项目"; Description = "仅允许不存在或完全为空的目标目录"; Value = "New" },
            [pscustomobject]@{ Label = "接入已有项目"; Description = "显式保留项目自有文件，只补充 AWZ 基线"; Value = "Existing" }
        )
        if (-not $selectedMode) { return }

        $target = Read-AwzTuiText -Title "项目位置" -Label "目标目录" -Hint "示例：E:\Project\My App" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Required
        if (-not $target) { return }

        $trimmedTarget = $target.TrimEnd([char[]]@('\', '/'))
        $defaultProject = Split-Path -Leaf $trimmedTarget
        $project = Read-AwzTuiText -Title "项目身份" -Label "项目名称" -Value $defaultProject -Hint "可直接按 Enter 使用目录名" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Required
        if (-not $project) { return }

        $licenseOwner = Read-AwzTuiText -Title "许可证信息" -Label "MIT License Owner" -Value $script:Owner -Hint "只用于生成新项目 LICENSE" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Required
        if (-not $licenseOwner) { return }

        $refresh = $false
        if ($selectedMode -eq "Existing") {
            $refreshChoice = Select-AwzTuiOption -Title "已有项目策略" -Subtitle "项目自有根文件始终受保护" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Options @(
                [pscustomobject]@{ Label = "只补充缺失文件"; Description = "推荐；不会覆盖任何已存在文件"; Value = "Preserve" },
                [pscustomobject]@{ Label = "刷新 AWZ 指导文件"; Description = "仅更新 AGENTS、CLAUDE 与 agent-room 模板"; Value = "Refresh" }
            )
            if (-not $refreshChoice) { return }
            $refresh = $refreshChoice -eq "Refresh"
        }

        $params = New-InitParams -Target $target -Project $project -LicenseOwner $licenseOwner -SelectedMode $selectedMode -Refresh $refresh
        Show-AwzTuiFrame -Title "正在生成变更计划" -Subtitle "只读检查，不会创建或修改文件" -Content @("", "                 ◇  ANALYZING TARGET", "", "                 检查目录、模板与 Git 前置条件…") -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行" -Footer "请稍候"
        $preview = @(& $InitializerPath @params -DryRun 2>&1 | ForEach-Object { $_.ToString() })
        $apply = Show-AwzTuiPreview -PreviewLines $preview -Target $target -Project $project -SelectedMode $selectedMode -Refresh $refresh
        if (-not $apply) { return }

        if ($selectedMode -eq "Existing" -and $refresh) {
            $confirmation = Read-AwzTuiText -Title "高风险确认" -Label "输入 APPLY 继续刷新 AWZ 指导文件" -Hint "README、LICENSE、.gitignore 与 .env.example 仍不会被覆盖" -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [执行]" -Required
            if ($confirmation -cne "APPLY") { return }
        }

        Show-AwzTuiFrame -Title "正在应用" -Subtitle "底层初始化器正在执行已预览的计划" -Content @("", "                 ◆  APPLYING BASELINE", "", "                 写入模板并验证 Git 状态…") -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [执行]" -Footer "请勿关闭终端"
        $applyOutput = @(& $InitializerPath @params 2>&1 | ForEach-Object { $_.ToString() })
        $gitStatus = @()
        if (Test-Path -LiteralPath (Join-Path $target ".git")) {
            $gitStatus = @(& git -C $target status --short 2>&1 | ForEach-Object { $_.ToString() })
        }
        $content = @(
            "✓ 操作完成",
            "",
            "目标   $target",
            "模式   $selectedMode",
            "写入日志   $($applyOutput.Count) 行",
            "Git 待提交   $($gitStatus.Count) 项",
            "",
            "下一步：进入项目目录并检查 git status"
        )
        Show-AwzTuiFrame -Title "项目已准备就绪" -Subtitle "AWZ Workflow baseline applied successfully" -Content $content -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [完成]" -Footer "Enter / Q 返回终端"
        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -in @("Enter", "Q", "Escape")) { break }
        }
    }
    catch {
        $message = $_.Exception.Message
        Show-AwzTuiFrame -Title "操作未执行" -Subtitle "安全检查或初始化过程返回错误" -Content @("✕ $message", "", "没有通过预览的计划不会进入执行阶段。", "请检查目标路径或改用 Existing 模式。") -Step "01  模式   ───   02  信息   ───   03 [阻止]  ───   04  执行" -Footer "Enter / Q 返回终端"
        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -in @("Enter", "Q", "Escape")) { break }
        }
    }
    finally {
        [Console]::CursorVisible = $oldCursorVisible
    }
}

if ($Help -or $Action -in @("--help", "-h", "help")) {
    Show-Usage
    return
}

if ($RenderDemo) {
    New-AwzTuiFrame -Title "选择工作模式" -Subtitle "新项目与已有项目采用完全不同的安全边界" -Content @(
        "❯  创建新项目",
        "     仅允许不存在或完全为空的目标目录",
        "",
        "   接入已有项目",
        "     显式保留项目自有文件，只补充 AWZ 基线"
    ) -Step "01 [模式]  ───   02  信息   ───   03  预览   ───   04  执行" -Footer "↑↓ 移动    Enter 确认    Q 退出" -Width 92
    return
}

$initializer = Join-Path $PSScriptRoot "init-project.ps1"
if (-not (Test-Path -LiteralPath $initializer -PathType Leaf)) {
    throw "Initializer not found: $initializer"
}

$useFullScreen = (-not $Action) -and (-not $Classic) -and (-not [Console]::IsInputRedirected)
if ($useFullScreen) {
    Invoke-FullScreenTui -InitializerPath $initializer
    return
}

Invoke-ScriptedFlow -InitializerPath $initializer -UseClassicMenu (-not $Action)

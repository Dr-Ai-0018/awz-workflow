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
AWZ Workflow Terminal Control Center

Interactive control center:
  .\scripts\awz.bat
  .\scripts\awz.ps1

Classic prompt fallback:
  .\scripts\awz.ps1 -Classic

Scriptable:
  .\scripts\awz.ps1 -Action init -TargetPath <path> [options]

Options:
  -Action init          Run project initialization (scriptable compatibility path).
  -TargetPath <path>   Target project directory.
  -ProjectName <name>  Project name. Defaults to the target directory name.
  -Owner <name>        MIT license owner.
  -Mode New|Existing   Initialization mode. Defaults to New.
  -Force               Refresh AWZ-managed files in Existing mode.
  -DryRunOnly          Stop after the mandatory preview.
  -Yes                  Apply after preview without an interactive confirmation.
  -Classic              Use the minimal line-oriented prompt flow.
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

function Invoke-InitializationWizard {
    param(
        [string]$InitializerPath,
        [string]$InitialMode = ""
    )

    try {
        $selectedMode = $InitialMode
        if (-not $selectedMode) {
            $selectedMode = Select-AwzTuiOption -Title "选择工作模式" -Subtitle "新项目与已有项目采用完全不同的安全边界" -Step "01 [模式]  ───   02  信息   ───   03  预览   ───   04  执行" -Options @(
                [pscustomobject]@{ Label = "创建新项目"; Description = "仅允许不存在或完全为空的目标目录"; Value = "New" },
                [pscustomobject]@{ Label = "接入已有项目"; Description = "显式保留项目自有文件，只补充 AWZ 基线"; Value = "Existing" }
            ) -AllowBack
            if (-not $selectedMode -or $selectedMode -eq "__AWZ_BACK__") { return }
        }

        $target = Read-AwzTuiText -Title "项目位置" -Label "目标目录" -Hint "示例：E:\Project\My App" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Required -AllowBack -ExitOnQuit
        if (-not $target -or $target -in @("__AWZ_BACK__", "__AWZ_EXIT__")) { return }

        $trimmedTarget = $target.TrimEnd([char[]]@('\', '/'))
        $defaultProject = Split-Path -Leaf $trimmedTarget
        $project = Read-AwzTuiText -Title "项目身份" -Label "项目名称" -Value $defaultProject -Hint "可直接按 Enter 使用目录名" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Required -AllowBack -ExitOnQuit
        if (-not $project -or $project -in @("__AWZ_BACK__", "__AWZ_EXIT__")) { return }

        $licenseOwner = Read-AwzTuiText -Title "许可证信息" -Label "MIT License Owner" -Value $script:Owner -Hint "只用于生成新项目 LICENSE" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Required -AllowBack -ExitOnQuit
        if (-not $licenseOwner -or $licenseOwner -in @("__AWZ_BACK__", "__AWZ_EXIT__")) { return }

        $refresh = $false
        if ($selectedMode -eq "Existing") {
            $refreshChoice = Select-AwzTuiOption -Title "已有项目策略" -Subtitle "项目自有根文件始终受保护" -Step "01  模式   ───   02 [信息]  ───   03  预览   ───   04  执行" -Options @(
                [pscustomobject]@{ Label = "只补充缺失文件"; Description = "推荐；不会覆盖任何已存在文件"; Value = "Preserve" },
                [pscustomobject]@{ Label = "刷新 AWZ 指导文件"; Description = "仅更新 AGENTS、CLAUDE 与 agent-room 模板"; Value = "Refresh" }
            )
            if (-not $refreshChoice -or $refreshChoice -eq "__AWZ_BACK__") { return }
            $refresh = $refreshChoice -eq "Refresh"
        }

        $params = New-InitParams -Target $target -Project $project -LicenseOwner $licenseOwner -SelectedMode $selectedMode -Refresh $refresh
        Show-AwzTuiFrame -Title "正在生成变更计划" -Subtitle "只读检查，不会创建或修改文件" -Content @("", "                 ◇  ANALYZING TARGET", "", "                 检查目录、模板与 Git 前置条件…") -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行" -Footer "请稍候"
        $preview = @(& $InitializerPath @params -DryRun 2>&1 | ForEach-Object { $_.ToString() })
        Show-AwzTuiLog -Title "DryRun 检查完成" -Subtitle "以下是将要发生的全部变更" -Lines $preview -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行"
        $apply = Show-AwzTuiPreview -PreviewLines $preview -Target $target -Project $project -SelectedMode $selectedMode -Refresh $refresh
        if ($apply -eq "__AWZ_EXIT__" -or $apply -eq "__AWZ_BACK__" -or -not $apply) { return }

        if ($selectedMode -eq "Existing" -and $refresh) {
            $confirmation = Read-AwzTuiText -Title "高风险确认" -Label "输入 APPLY 继续刷新 AWZ 指导文件" -Hint "README、LICENSE、.gitignore 与 .env.example 仍不会被覆盖" -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [执行]" -Required -AllowBack -ExitOnQuit
            if ($confirmation -cne "APPLY") { return }
        }

        Show-AwzTuiFrame -Title "正在应用" -Subtitle "底层初始化器正在执行已预览的计划" -Content @("", "                 ◆  APPLYING BASELINE", "", "                 写入模板并验证 Git 状态…") -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [执行]" -Footer "请勿关闭终端"
        $applyOutput = @(& $InitializerPath @params 2>&1 | ForEach-Object { $_.ToString() })
        Show-AwzTuiLog -Title "初始化已执行" -Subtitle "以下是本次实际写入与创建的结果" -Lines $applyOutput -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [执行]"
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
        Show-AwzTuiFrame -Title "项目已准备就绪" -Subtitle "AWZ Workflow baseline applied successfully" -Content $content -Step "01  模式   ───   02  信息   ───   03  预览   ───   04 [完成]" -Footer "按 Enter 返回终端"
        Read-Host "按 Enter 返回终端" | Out-Null
    }
    catch {
        $message = $_.Exception.Message
        Show-AwzTuiFrame -Title "操作未执行" -Subtitle "安全检查或初始化过程返回错误" -Content @("✕ $message", "", "没有通过预览的计划不会进入执行阶段。", "请检查目标路径或改用 Existing 模式。") -Step "01  模式   ───   02  信息   ───   03 [阻止]  ───   04  执行" -Footer "按 Enter 返回终端"
        Read-Host "按 Enter 返回终端" | Out-Null
    }
}

function Invoke-AwzJsonCommand {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments,
        [int[]]$AcceptedExitCodes = @(0)
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "AWZ command not found: $ScriptPath"
    }
    $commandArguments = @($Arguments) + @("--json")
    $output = @(& $ScriptPath @commandArguments)
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    if (-not $text.Trim()) {
        throw "AWZ command returned no structured output: $ScriptPath"
    }
    try {
        $result = $text | ConvertFrom-Json
    }
    catch {
        throw "AWZ command returned invalid JSON: $($_.Exception.Message)"
    }
    if ($exitCode -notin $AcceptedExitCodes) {
        $reason = @($result.blockedBy) -join "; "
        if (-not $reason) { $reason = "exit code $exitCode" }
        throw $reason
    }
    return $result
}

function Invoke-ReferencePlanApply {
    param(
        [string]$ReferenceCli,
        [string[]]$Arguments,
        [string]$Title,
        [string]$ConfirmToken = "A",
        [int[]]$AcceptedExitCodes = @(0)
    )

    $preview = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments (@($Arguments) + @("--dry-run")) -AcceptedExitCodes $AcceptedExitCodes
    $plan = $preview.plan
    $content = [System.Collections.Generic.List[string]]::new()
    $content.Add("Operation  $($preview.operation)")
    $content.Add("Plan       $($plan.planHash)")
    $content.Add("")
    foreach ($change in @($plan.changes)) {
        $content.Add("$($change.kind)  $($change.summary)")
        $content.Add("    $($change.target)")
    }
    foreach ($warning in @($preview.warnings)) { $content.Add("WARN  $warning") }
    foreach ($blocker in @($preview.blockedBy)) { $content.Add("BLOCK $blocker") }
    $content.Add("")
    $content.Add("输入 $ConfirmToken 应用；B 返回；Q 退出。")
    Show-AwzTuiFrame -Title "$Title · 预览" -Subtitle "DryRun 完成；apply 必须匹配当前 planHash" -Content $content.ToArray() -Step "HOME  ───  REFERENCE  ───  [WRITE PREVIEW]" -Footer "$ConfirmToken 应用；B 返回；Q 退出"
    while ($true) {
        $choice = (Read-Host "输入 $ConfirmToken 应用，B 返回或 Q 退出").Trim()
        if ($choice -match '^[bB]$') { return "__AWZ_BACK__" }
        if ($choice -match '^[qQ]$') { return "__AWZ_EXIT__" }
        $matches = if ($ConfirmToken -eq "A") { $choice -match '^[aA]$' } else { $choice -ceq $ConfirmToken }
        if (-not $matches) { continue }
        return Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments (@($Arguments) + @("--plan-hash", [string]$plan.planHash)) -AcceptedExitCodes $AcceptedExitCodes
    }
}

function Show-AwzReadOnlyPage {
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Content,
        [string]$Step = "HOME [控制中心]"
    )

    Show-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $Content -Step $Step -Footer "按 B 返回控制中心；Q 退出"
    while ($true) {
        $choice = (Read-Host "输入 B 返回，Q 退出").Trim()
        if ($choice -match '^[bB]$') { return "back" }
        if ($choice -match '^[qQ]$') { return "exit" }
    }
}

function Invoke-ReferenceListBrowser {
    param([string]$ReferenceCli)

    try {
        while ($true) {
            $list = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments @("list")
            $references = @($list.data.references)
            if ($references.Count -eq 0) {
                return Show-AwzReadOnlyPage -Title "Reference Library" -Subtitle "机器级参考项目库" -Content @(
                    "Reference root   $($list.data.referenceRoot)",
                    "状态             尚未登记 reference",
                    "",
                    "使用 Reference CLI add 或后续 TUI 写入流程登记项目。"
                ) -Step "HOME  ───  [REFERENCE]  ───  DETAIL"
            }

            $options = @(
                foreach ($reference in $references) {
                    [pscustomobject]@{
                        Label = [string]$reference.id
                        Description = "$($reference.state.status)  ·  version $($reference.version)"
                        Value = [string]$reference.id
                    }
                }
            )
            $healthyCount = @($references | Where-Object { $_.state.status -eq "ok" }).Count
            $configSource = if ($list.data.configured) { "显式配置" } else { "默认路径" }
            $selected = Select-AwzTuiOption -Title "Reference Library" -Subtitle "$($references.Count) 个条目 · 正常 $healthyCount · $configSource · $($list.data.referenceRoot)" -Step "HOME  ───  [REFERENCE]  ───  DETAIL" -Options $options -AllowBack
            if (-not $selected) { return "exit" }
            if ($selected -eq "__AWZ_BACK__") { return "back" }

            $detail = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments @("show", "--id", $selected)
            $reference = $detail.data.reference
            $state = $reference.state
            $issues = @($state.issues)
            $content = @(
                "ID        $($reference.id)",
                "状态      $($state.status)",
                "版本      $($reference.version)",
                "分支      $($state.branch)",
                "Revision  $($reference.revision)",
                "License   $($reference.license)",
                "Trust     $($reference.trust)",
                "Path      $($state.path)",
                "Remote    $($state.remote)",
                "Issues    $($issues.Count)"
            )
            foreach ($issue in ($issues | Select-Object -First 3)) {
                $content += "  ! $issue"
            }
            $pageResult = Show-AwzReadOnlyPage -Title "Reference 详情：$($reference.name)" -Subtitle "只读状态；不会 fetch、update 或修改 catalog" -Content $content -Step "HOME  ───  REFERENCE  ───  [DETAIL]"
            if ($pageResult -eq "exit") { return "exit" }
        }
    }
    catch {
        return Show-AwzReadOnlyPage -Title "Reference Library 不可用" -Subtitle "只读命令返回错误" -Content @(
            "✕ $($_.Exception.Message)",
            "",
            "没有执行任何 Reference Library 写操作。"
        ) -Step "HOME  ───  [REFERENCE ERROR]"
    }
}

function Invoke-ReferenceMapping {
    param([string]$ReferenceCli)

    $project = Read-AwzTuiText -Title "项目 Reference mapping" -Label "项目目录" -Hint "读取 .awz/references.json；本页只读，不会修改 mapping 或 context" -Step "HOME  ───  REFERENCE  ───  [PROJECT MAPPING]" -Required -AllowBack -ExitOnQuit
    if ($project -eq "__AWZ_BACK__") { return "back" }
    if ($project -eq "__AWZ_EXIT__") { return "exit" }
    try {
        $result = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments @("status", "--project", $project) -AcceptedExitCodes @(0, 1)
        $data = $result.data
        $entries = @($data.projectMappingEntries)
        $content = [System.Collections.Generic.List[string]]::new()
        $content.Add("项目      $project")
        $content.Add("映射      $($entries.Count) · unresolved $(@($data.unresolved).Count)")
        $content.Add("")
        if ($entries.Count -eq 0) {
            $content.Add("当前项目没有映射 Reference。")
        }
        foreach ($entry in $entries) {
            $required = if ($entry.required) { "required" } else { "optional" }
            $content.Add("$($entry.status.ToUpper())  $($entry.id)  [$required]")
            if ($entry.purpose) { $content.Add("    用途：$($entry.purpose)") }
            if ($entry.path) { $content.Add("    路径：$($entry.path)") }
            foreach ($issue in (@($entry.issues) | Select-Object -First 1)) {
                $content.Add("    ! $issue")
            }
        }
        $subtitle = if (@($data.unresolved).Count -gt 0) { "发现 unresolved mapping；本页不会自动修复" } else { "只读项目映射状态" }
        return Show-AwzReadOnlyPage -Title "项目 Reference mapping" -Subtitle $subtitle -Content $content.ToArray() -Step "HOME  ───  REFERENCE  ───  [PROJECT MAPPING]"
    }
    catch {
        return Show-AwzReadOnlyPage -Title "项目 mapping 不可用" -Subtitle "只读命令返回错误" -Content @(
            "✕ $($_.Exception.Message)",
            "",
            "没有执行任何 mapping 或 context 写操作。"
        ) -Step "HOME  ───  [MAPPING ERROR]"
    }
}

function Invoke-ReferenceConfigure {
    param([string]$ReferenceCli)

    $root = Read-AwzTuiText -Title "配置 Reference root" -Label "Reference root" -Hint "机器级目录；不会 clone 或更新仓库" -Step "HOME  ───  REFERENCE  ───  [CONFIGURE]" -Required -AllowBack -ExitOnQuit
    if ($root -eq "__AWZ_EXIT__") { return "exit" }
    if ($root -eq "__AWZ_BACK__") { return "back" }
    $depth = Read-AwzTuiText -Title "配置 Clone depth" -Label "默认 clone depth" -Value "1" -Hint "输入大于等于 1 的整数" -Step "HOME  ───  REFERENCE  ───  [CONFIGURE]" -Required -AllowBack -ExitOnQuit
    if ($depth -eq "__AWZ_EXIT__") { return "exit" }
    if ($depth -eq "__AWZ_BACK__") { return "back" }
    $depthNumber = 0
    if (-not [int]::TryParse($depth, [ref]$depthNumber) -or $depthNumber -lt 1) {
        return Show-AwzReadOnlyPage -Title "配置未执行" -Subtitle "clone depth 必须是大于等于 1 的整数" -Content @("输入值：$depth", "", "没有写入配置或创建 Reference root。") -Step "HOME  ───  [CONFIGURE BLOCKED]"
    }
    try {
        $preview = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments @("configure", "--root", $root, "--depth", [string]$depthNumber, "--dry-run")
        $plan = $preview.plan
        $content = @(
            "Root      $root",
            "Depth     $depthNumber",
            "Plan      $($plan.planHash)",
            "",
            "以下变更来自 configure DryRun："
        )
        foreach ($change in @($plan.changes)) {
            $content += "  $($change.kind)  $($change.summary)"
        }
        $content += ""
        $content += "输入 A 应用；B 返回；Q 退出。"
        Show-AwzTuiFrame -Title "配置 Reference root · 预览" -Subtitle "执行前确认结构化计划" -Content $content -Step "HOME  ───  REFERENCE  ───  [CONFIGURE PREVIEW]" -Footer "A 应用；B 返回；H 帮助；Q 退出"
        while ($true) {
            $choice = (Read-Host "输入 A 应用，B 返回，H 帮助或 Q 退出").Trim()
            if ($choice -match '^[bB]$') { return "back" }
            if ($choice -match '^[qQ]$') { return "exit" }
            if ($choice -match '^[hH?]$') {
                Show-AwzTuiFrame -Title "配置 Reference root · 帮助" -Subtitle "本页先 DryRun，再按 planHash 应用" -Content @("A  应用当前 planHash 对应的配置计划", "B  返回输入", "Q  退出控制中心") -Step "HOME  ───  REFERENCE  ───  [CONFIGURE HELP]" -Footer "按 Enter 返回预览"
                Read-Host "按 Enter 返回预览" | Out-Null
                continue
            }
            if ($choice -notmatch '^[aA]$') { continue }
            $applied = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments @("configure", "--root", $root, "--depth", [string]$depthNumber, "--plan-hash", [string]$plan.planHash) -AcceptedExitCodes @(0)
            $transaction = $applied.data.transaction
            return Show-AwzReadOnlyPage -Title "Reference root 已配置" -Subtitle "配置写入完成；仓库仍未 clone 或更新" -Content @(
                "Root         $root",
                "Config       $($applied.data.config.referenceRoot)",
                "Transaction  $($transaction.path)",
                "状态         $($transaction.state)"
            ) -Step "HOME  ───  REFERENCE  ───  [CONFIGURE DONE]"
        }
    }
    catch {
        return Show-AwzReadOnlyPage -Title "配置 Reference root 失败" -Subtitle "没有执行未预览的写入" -Content @("✕ $($_.Exception.Message)", "", "可重新运行 DryRun 后再试。") -Step "HOME  ───  [CONFIGURE ERROR]"
    }
}

function Invoke-ReferenceProjectActions {
    param([string]$ReferenceCli)

    while ($true) {
        $selected = Select-AwzTuiOption -Title "项目 Reference lifecycle" -Subtitle "所有写入都先 DryRun，再绑定 planHash apply" -Step "HOME  ───  REFERENCE  ───  [PROJECT ACTIONS]" -Options @(
            [pscustomobject]@{ Label = "Map reference"; Description = "新增或更新项目映射；不会修改全局 clone"; Value = "map" },
            [pscustomobject]@{ Label = "Unmap reference"; Description = "仅移除项目映射；全局 clone 保留"; Value = "unmap" },
            [pscustomobject]@{ Label = "Generate context"; Description = "生成项目本地 reference-context.md"; Value = "context" }
        ) -AllowBack
        if (-not $selected) { return "exit" }
        if ($selected -eq "__AWZ_BACK__") { return "back" }

        $project = Read-AwzTuiText -Title "项目 Reference lifecycle" -Label "项目目录" -Hint "项目必须存在" -Step "HOME  ───  REFERENCE  ───  [PROJECT ACTIONS]" -Required -AllowBack -ExitOnQuit
        if ($project -eq "__AWZ_EXIT__") { return "exit" }
        if ($project -eq "__AWZ_BACK__") { continue }
        try {
            if ($selected -eq "map") {
                $referenceId = Read-AwzTuiText -Title "Map reference" -Label "Reference id" -Hint "必须已登记到全局 catalog" -Step "HOME  ───  REFERENCE  ───  [MAP]" -Required -AllowBack -ExitOnQuit
                if ($referenceId -eq "__AWZ_EXIT__") { return "exit" }
                if ($referenceId -eq "__AWZ_BACK__") { continue }
                $purpose = Read-AwzTuiText -Title "Map reference" -Label "Purpose" -Hint "可留空；说明本项目何时参考它" -Step "HOME  ───  REFERENCE  ───  [MAP]" -AllowBack -ExitOnQuit
                if ($purpose -eq "__AWZ_EXIT__") { return "exit" }
                if ($purpose -eq "__AWZ_BACK__") { continue }
                $requiredChoice = Select-AwzTuiOption -Title "Map reference" -Subtitle "required mapping 不可用时会阻止完整 context" -Step "HOME  ───  REFERENCE  ───  [MAP]" -Options @(
                    [pscustomobject]@{ Label = "Optional"; Description = "参考不可用时继续工作"; Value = "optional" },
                    [pscustomobject]@{ Label = "Required"; Description = "参考不可用时报告阻塞"; Value = "required" }
                ) -AllowBack
                if (-not $requiredChoice) { return "exit" }
                if ($requiredChoice -eq "__AWZ_BACK__") { continue }
                $arguments = @("map", "--project", $project, "--id", $referenceId, "--purpose", $purpose)
                if ($requiredChoice -eq "required") { $arguments += "--required" }
                $applied = Invoke-ReferencePlanApply -ReferenceCli $ReferenceCli -Arguments $arguments -Title "Map $referenceId"
            }
            elseif ($selected -eq "unmap") {
                $referenceId = Read-AwzTuiText -Title "Unmap reference" -Label "Reference id" -Hint "仅移除项目 mapping；不会删除全局 clone" -Step "HOME  ───  REFERENCE  ───  [UNMAP]" -Required -AllowBack -ExitOnQuit
                if ($referenceId -eq "__AWZ_EXIT__") { return "exit" }
                if ($referenceId -eq "__AWZ_BACK__") { continue }
                $arguments = @("unmap", "--project", $project, "--id", $referenceId)
                $applied = Invoke-ReferencePlanApply -ReferenceCli $ReferenceCli -Arguments $arguments -Title "Unmap $referenceId" -ConfirmToken "UNMAP"
            }
            else {
                $output = Read-AwzTuiText -Title "Generate reference context" -Label "输出路径" -Hint "留空使用 docs/references/reference-context.md；路径必须位于项目内" -Step "HOME  ───  REFERENCE  ───  [CONTEXT]" -AllowBack -ExitOnQuit
                if ($output -eq "__AWZ_EXIT__") { return "exit" }
                if ($output -eq "__AWZ_BACK__") { continue }
                $arguments = @("context", "--project", $project)
                if ($output) { $arguments += @("--output", $output) }
                $applied = Invoke-ReferencePlanApply -ReferenceCli $ReferenceCli -Arguments $arguments -Title "Generate reference context" -AcceptedExitCodes @(0, 1)
            }

            if ($applied -eq "__AWZ_EXIT__") { return "exit" }
            if ($applied -eq "__AWZ_BACK__") { continue }
            $transaction = $applied.data.transaction
            $pageResult = Show-AwzReadOnlyPage -Title "Reference 写入完成" -Subtitle "$($applied.operation) 已按预览计划执行" -Content @(
                "Operation    $($applied.operation)",
                "Plan         $($applied.plan.planHash)",
                "Transaction  $($transaction.path)",
                "状态         $($transaction.state)",
                "Completed    $($transaction.completed)",
                "Remaining    $($transaction.remaining)"
            ) -Step "HOME  ───  REFERENCE  ───  [WRITE DONE]"
            if ($pageResult -eq "exit") { return "exit" }
        }
        catch {
            $pageResult = Show-AwzReadOnlyPage -Title "Reference 写入未完成" -Subtitle "预览或 apply 被安全检查阻止" -Content @("✕ $($_.Exception.Message)", "", "重新运行 DryRun 后再试；不要复用旧 planHash。") -Step "HOME  ───  [WRITE ERROR]"
            if ($pageResult -eq "exit") { return "exit" }
        }
    }
}

function Invoke-ReferenceBrowser {
    param([string]$ReferenceCli)

    while ($true) {
        $selected = Select-AwzTuiOption -Title "Reference Library" -Subtitle "全局浏览、项目 mapping 与受控写入" -Step "HOME  ───  [REFERENCE CENTER]" -Options @(
            [pscustomobject]@{ Label = "浏览全局条目"; Description = "查看 reference 列表、详情与本地仓库状态"; Value = "list" },
            [pscustomobject]@{ Label = "查看项目 mapping"; Description = "查看项目映射、用途、required 与 unresolved 状态"; Value = "mapping" },
            [pscustomobject]@{ Label = "配置 Reference root"; Description = "DryRun 预览后按 planHash 写入机器级配置"; Value = "configure" },
            [pscustomobject]@{ Label = "项目 mapping lifecycle"; Description = "map、unmap 与 context 的受控写入"; Value = "project-actions" }
        ) -AllowBack
        if (-not $selected) { return "exit" }
        if ($selected -eq "__AWZ_BACK__") { return "back" }
        if ($selected -eq "list") {
            $result = Invoke-ReferenceListBrowser -ReferenceCli $ReferenceCli
            if ($result -eq "exit") { return "exit" }
        }
        elseif ($selected -eq "mapping") {
            $result = Invoke-ReferenceMapping -ReferenceCli $ReferenceCli
            if ($result -eq "exit") { return "exit" }
        }
        elseif ($selected -eq "configure") {
            $result = Invoke-ReferenceConfigure -ReferenceCli $ReferenceCli
            if ($result -eq "exit") { return "exit" }
        }
        elseif ($selected -eq "project-actions") {
            $result = Invoke-ReferenceProjectActions -ReferenceCli $ReferenceCli
            if ($result -eq "exit") { return "exit" }
        }
    }
}

function Invoke-ReferenceDoctor {
    param([string]$ReferenceCli)

    try {
        $doctor = Invoke-AwzJsonCommand -ScriptPath $ReferenceCli -Arguments @("doctor") -AcceptedExitCodes @(0, 1)
        $references = @($doctor.data.references)
        $problemReferences = @($references | Where-Object { $_.status -ne "ok" })
        $content = [System.Collections.Generic.List[string]]::new()
        $content.Add("配置      $($doctor.data.configured)")
        $content.Add("Root      $($doctor.data.referenceRoot)")
        $content.Add("Root 存在 $($doctor.data.rootExists)")
        $content.Add("Reference $($references.Count) · 问题 $($problemReferences.Count)")
        $content.Add("")
        foreach ($reference in ($references | Select-Object -First 3)) {
            $marker = if ($reference.status -eq "ok") { "✓" } else { "!" }
            $content.Add("$marker $($reference.id)  $($reference.status)")
            foreach ($issue in (@($reference.issues) | Select-Object -First 1)) {
                $content.Add("    $issue")
            }
        }
        foreach ($warning in (@($doctor.warnings) | Select-Object -First 1)) {
            $content.Add("WARN  $warning")
        }
        foreach ($blocker in (@($doctor.blockedBy) | Select-Object -First 1)) {
            $content.Add("BLOCK $blocker")
        }
        if ($problemReferences.Count -gt 0) {
            $content.Add("建议：检查上方问题后重新运行 Doctor；本页不会自动修复。")
        }
        $subtitle = if ($doctor.exitCode -eq 0) { "离线检查通过" } else { "发现需要处理的问题；本页不会自动修复" }
        return Show-AwzReadOnlyPage -Title "AWZ Doctor" -Subtitle $subtitle -Content $content.ToArray() -Step "HOME  ───  [DOCTOR]"
    }
    catch {
        return Show-AwzReadOnlyPage -Title "AWZ Doctor 不可用" -Subtitle "诊断命令返回错误" -Content @("✕ $($_.Exception.Message)") -Step "HOME  ───  [DOCTOR ERROR]"
    }
}

function Invoke-RefreshCheck {
    param([string]$RefreshCli)

    $target = Read-AwzTuiText -Title "安全刷新检查" -Label "项目目录" -Hint "只运行 DryRun，不会修改项目" -Step "HOME  ───  [REFRESH CHECK]" -Required -AllowBack -ExitOnQuit
    if ($target -eq "__AWZ_BACK__") { return "back" }
    if ($target -eq "__AWZ_EXIT__") { return "exit" }
    try {
        $refresh = Invoke-AwzJsonCommand -ScriptPath $RefreshCli -Arguments @("--target", $target, "--dry-run") -AcceptedExitCodes @(0, 2)
        $files = @($refresh.data.files)
        $updates = @($files | Where-Object { $_.classification -in @("create", "update") })
        $adopted = @($files | Where-Object { $_.classification -eq "adopt" })
        $conflicts = @($files | Where-Object { $_.classification -eq "conflict" })
        $content = [System.Collections.Generic.List[string]]::new()
        $content.Add("目标      $target")
        $content.Add("待更新    $($updates.Count)")
        $content.Add("首次接管  $($adopted.Count)")
        $content.Add("冲突      $($conflicts.Count)")
        $content.Add("Plan      $($refresh.plan.planHash)")
        $content.Add("")
        foreach ($item in ($files | Where-Object { $_.classification -ne "unchanged" } | Select-Object -First 5)) {
            $content.Add("$($item.classification.ToUpper())  $($item.path)")
        }
        $subtitle = if ($conflicts.Count -gt 0) { "发现本地冲突；refresh 已整体阻止" } else { "DryRun 完成；本页不会 apply" }
        return Show-AwzReadOnlyPage -Title "安全刷新检查" -Subtitle $subtitle -Content $content.ToArray() -Step "HOME  ───  [REFRESH CHECK]"
    }
    catch {
        return Show-AwzReadOnlyPage -Title "安全刷新检查失败" -Subtitle "没有修改目标项目" -Content @("✕ $($_.Exception.Message)") -Step "HOME  ───  [REFRESH ERROR]"
    }
}

function Invoke-TerminalWizard {
    param(
        [string]$InitializerPath,
        [string]$ReferenceCli,
        [string]$RefreshCli
    )

    while ($true) {
        $selected = Select-AwzTuiOption -Title "AWZ 控制中心" -Subtitle "项目初始化、参考库、刷新检查与离线诊断" -Step "HOME [控制中心]" -Compact -Options @(
            [pscustomobject]@{ Label = "创建新项目"; Description = "安全初始化空目录"; Value = "New" },
            [pscustomobject]@{ Label = "接入已有项目"; Description = "保留项目自有文件"; Value = "Existing" },
            [pscustomobject]@{ Label = "Reference Library"; Description = "浏览参考条目与本地状态"; Value = "Reference" },
            [pscustomobject]@{ Label = "安全刷新检查"; Description = "manifest DryRun，不执行写入"; Value = "Refresh" },
            [pscustomobject]@{ Label = "Doctor"; Description = "离线诊断配置与 reference"; Value = "Doctor" }
        )
        if (-not $selected) { return }
        switch ($selected) {
            "New" { Invoke-InitializationWizard -InitializerPath $InitializerPath -InitialMode "New" }
            "Existing" { Invoke-InitializationWizard -InitializerPath $InitializerPath -InitialMode "Existing" }
            "Reference" { if ((Invoke-ReferenceBrowser -ReferenceCli $ReferenceCli) -eq "exit") { return } }
            "Refresh" { if ((Invoke-RefreshCheck -RefreshCli $RefreshCli) -eq "exit") { return } }
            "Doctor" { if ((Invoke-ReferenceDoctor -ReferenceCli $ReferenceCli) -eq "exit") { return } }
        }
    }
}

if ($Help -or $Action -in @("--help", "-h", "help")) {
    Show-Usage
    return
}

if ($RenderDemo) {
    New-AwzTuiFrame -Title "AWZ 控制中心" -Subtitle "项目初始化、参考库、刷新检查与离线诊断" -Content @(
        "[1]  创建新项目  ·  安全初始化空目录",
        "[2]  接入已有项目  ·  保留项目自有文件",
        "[3]  Reference Library  ·  浏览参考条目与本地状态",
        "[4]  安全刷新检查  ·  manifest DryRun，不执行写入",
        "[5]  Doctor  ·  离线诊断配置与 reference"
    ) -Step "HOME [控制中心]" -Footer "在面板下方输入编号；Q 退出" -Width 92
    return
}

$initializer = Join-Path $PSScriptRoot "init-project.ps1"
if (-not (Test-Path -LiteralPath $initializer -PathType Leaf)) {
    throw "Initializer not found: $initializer"
}
$referenceCli = Join-Path $PSScriptRoot "reference-library.ps1"
$refreshCli = Join-Path $PSScriptRoot "refresh-project.ps1"

$useTerminalWizard = (-not $Action) -and (-not $Classic) -and (-not [Console]::IsInputRedirected)
if ($useTerminalWizard) {
    Invoke-TerminalWizard -InitializerPath $initializer -ReferenceCli $referenceCli -RefreshCli $refreshCli
    return
}

Invoke-ScriptedFlow -InitializerPath $initializer -UseClassicMenu (-not $Action)

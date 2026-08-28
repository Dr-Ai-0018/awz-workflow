function Get-AwzDisplayWidth {
    param([string]$Text)

    $width = 0
    foreach ($char in $Text.ToCharArray()) {
        $code = [int]$char
        if (
            ($code -ge 0x1100 -and $code -le 0x115F) -or
            ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE10 -and $code -le 0xFE6F) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60)
        ) {
            $width += 2
        }
        else {
            $width += 1
        }
    }
    return $width
}

function Limit-AwzDisplayText {
    param(
        [string]$Text,
        [int]$MaxWidth
    )

    if ((Get-AwzDisplayWidth $Text) -le $MaxWidth) {
        return $Text
    }

    $result = ""
    $used = 0
    foreach ($char in $Text.ToCharArray()) {
        $charWidth = Get-AwzDisplayWidth ([string]$char)
        if (($used + $charWidth) -gt ($MaxWidth - 1)) {
            break
        }
        $result += $char
        $used += $charWidth
    }
    return "$result…"
}

function Pad-AwzDisplayText {
    param(
        [string]$Text,
        [int]$Width
    )

    $limited = Limit-AwzDisplayText -Text $Text -MaxWidth $Width
    $padding = [Math]::Max(0, $Width - (Get-AwzDisplayWidth $limited))
    return $limited + (" " * $padding)
}

function Get-AwzTuiWidth {
    try {
        $windowWidth = [Console]::WindowWidth
    }
    catch {
        $windowWidth = 92
    }
    if ($windowWidth -le 0) {
        $windowWidth = 92
    }
    return [Math]::Min(108, [Math]::Max(76, $windowWidth - 2))
}

function New-AwzTuiFrame {
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Content,
        [string]$Step = "01  模式   ───   02  信息   ───   03  预览   ───   04  执行",
        [string]$Footer = "↑↓ 移动    Enter 确认    Q 退出",
        [int]$Width = 92,
        [int]$BodyHeight = 0
    )

    $Width = [Math]::Max(76, $Width)
    if ($BodyHeight -le 0) {
        $BodyHeight = [Math]::Min(14, [Math]::Max(8, $Content.Count + 1))
    }
    $inner = $Width - 2
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("╭" + ("─" * $inner) + "╮")
    $lines.Add("│" + (Pad-AwzDisplayText -Text "  AWZ WORKFLOW   /   PROJECT CONTROL" -Width $inner) + "│")
    $lines.Add("├" + ("─" * $inner) + "┤")
    $lines.Add("│" + (Pad-AwzDisplayText -Text "  $Step" -Width $inner) + "│")
    $lines.Add("├" + ("─" * $inner) + "┤")
    $lines.Add("│" + (Pad-AwzDisplayText -Text "  $Title" -Width $inner) + "│")
    $lines.Add("│" + (Pad-AwzDisplayText -Text "  $Subtitle" -Width $inner) + "│")
    $lines.Add("│" + (" " * $inner) + "│")

    $body = @($Content | Select-Object -First $BodyHeight)
    foreach ($line in $body) {
        $lines.Add("│" + (Pad-AwzDisplayText -Text "  $line" -Width $inner) + "│")
    }
    for ($i = $body.Count; $i -lt $BodyHeight; $i++) {
        $lines.Add("│" + (" " * $inner) + "│")
    }

    $lines.Add("├" + ("─" * $inner) + "┤")
    $lines.Add("│" + (Pad-AwzDisplayText -Text "  $Footer" -Width $inner) + "│")
    $lines.Add("╰" + ("─" * $inner) + "╯")
    return $lines.ToArray()
}

function Show-AwzTuiFrame {
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Content,
        [string]$Step,
        [string]$Footer,
        [int]$BodyHeight = 0
    )

    Clear-Host 2>$null
    $frame = New-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $Content -Step $Step -Footer $Footer -Width (Get-AwzTuiWidth) -BodyHeight $BodyHeight
    for ($i = 0; $i -lt $frame.Count; $i++) {
        $line = $frame[$i]
        if ($line.StartsWith("╭") -or $line.StartsWith("├") -or $line.StartsWith("╰")) {
            Write-Host $line -ForegroundColor Cyan
        }
        elseif ($i -eq 1) {
            Write-Host $line -ForegroundColor White -BackgroundColor DarkCyan
        }
        elseif ($i -eq 3) {
            Write-Host $line -ForegroundColor Cyan
        }
        elseif ($i -eq 5) {
            Write-Host $line -ForegroundColor White
        }
        elseif ($i -eq 6) {
            Write-Host $line -ForegroundColor DarkGray
        }
        elseif ($i -eq ($frame.Count - 2)) {
            Write-Host $line -ForegroundColor Black -BackgroundColor Cyan
        }
        elseif ($line -match '│\s+\[\d+\]') {
            Write-Host $line -ForegroundColor Black -BackgroundColor Cyan
        }
        else {
            Write-Host $line
        }
    }
}

function Select-AwzTuiOption {
    param(
        [string]$Title,
        [string]$Subtitle,
        [object[]]$Options,
        [string]$Step,
        [switch]$Compact,
        [switch]$AllowBack
    )

    $errorMessage = ""
    $pageSize = if ($Compact) { 10 } else { 4 }
    $page = 0
    $pageCount = [Math]::Max(1, [Math]::Ceiling($Options.Count / $pageSize))
    while ($true) {
        $content = [System.Collections.Generic.List[string]]::new()
        $start = $page * $pageSize
        $end = [Math]::Min($Options.Count, $start + $pageSize)
        for ($i = $start; $i -lt $end; $i++) {
            if ($Compact) {
                $content.Add("[$($i + 1)]  $($Options[$i].Label)  ·  $($Options[$i].Description)")
            }
            else {
                $content.Add("[$($i + 1)]  $($Options[$i].Label)")
                $content.Add("     $($Options[$i].Description)")
                $content.Add("")
            }
        }
        if ($errorMessage) {
            $content.Add("")
            $content.Add("! $errorMessage")
        }
        if ($pageCount -gt 1) {
            $content.Add("")
            $content.Add("第 $($page + 1) / $pageCount 页")
        }
        $footerParts = [System.Collections.Generic.List[string]]::new()
        $footerParts.Add("输入编号")
        if ($pageCount -gt 1) { $footerParts.Add("N/P 翻页") }
        if ($AllowBack) { $footerParts.Add("B 返回") }
        $footerParts.Add("Q 退出")
        $footer = $footerParts -join "；"
        Show-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $content.ToArray() -Step $Step -Footer $footer

        $prompt = "选择 [$($start + 1)-$end]"
        if ($pageCount -gt 1) { $prompt += "、N/P" }
        if ($AllowBack) { $prompt += "、B" }
        $prompt += " 或 Q"
        $choice = (Read-Host $prompt).Trim()
        if ($choice -match '^[qQ]$') {
            return $null
        }
        if ($choice -match '^[hH?]$') {
            $errorMessage = "帮助：输入编号选择；"
            if ($pageCount -gt 1) { $errorMessage += "N/P 翻页；" }
            if ($AllowBack) { $errorMessage += "B 返回；" }
            $errorMessage += "Q 退出。"
            continue
        }
        if ($AllowBack -and $choice -match '^[bB]$') {
            return "__AWZ_BACK__"
        }
        if ($pageCount -gt 1 -and $choice -match '^[nN]$') {
            $page = ($page + 1) % $pageCount
            $errorMessage = ""
            continue
        }
        if ($pageCount -gt 1 -and $choice -match '^[pP]$') {
            $page = if ($page -le 0) { $pageCount - 1 } else { $page - 1 }
            $errorMessage = ""
            continue
        }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge ($start + 1) -and $number -le $end) {
            return $Options[$number - 1].Value
        }
        $errorMessage = '无法识别输入“{0}”，请使用页面显示的编号。' -f $choice
    }
}

function Read-AwzTuiText {
    param(
        [string]$Title,
        [string]$Label,
        [string]$Value = "",
        [string]$Hint = "",
        [string]$Step,
        [switch]$Required,
        [switch]$AllowBack,
        [switch]$ExitOnQuit
    )

    while ($true) {
        $defaultNote = if ($Value) { "直接按 Enter 使用默认值：$Value" } else { "请输入完整内容；支持粘贴。" }
        $content = @(
            $Label,
            "",
            "输入会在面板下方进行，终端原生编辑可正常粘贴、删除与移动光标。",
            "",
            $defaultNote,
            "",
            $Hint
        )
        $footer = if ($AllowBack) { "在面板下方输入；B 返回；Q 退出" } else { "在面板下方输入；输入 Q 取消" }
        Show-AwzTuiFrame -Title $Title -Subtitle "稳定输入模式：不逐键重绘终端" -Content $content -Step $Step -Footer $footer

        $input = Read-Host $Label
        if ($input -match '^[qQ]$') {
            if ($ExitOnQuit) { return "__AWZ_EXIT__" }
            return $null
        }
        if ($AllowBack -and $input -match '^[bB]$') {
            return "__AWZ_BACK__"
        }
        if ($input -match '^[hH?]$') {
            Show-AwzTuiFrame -Title "$Title · 帮助" -Subtitle "输入提示" -Content @(
                "输入完整路径或文本后按 Enter 确认。",
                "留空时使用默认值（如果页面提供默认值）。",
                "B 返回；Q 退出；H 或 ? 再次查看帮助。"
            ) -Step $Step -Footer "按 Enter 返回输入"
            $helpChoice = (Read-Host "按 Enter 返回输入").Trim()
            if ($helpChoice -match '^[qQ]$' -and $ExitOnQuit) { return "__AWZ_EXIT__" }
            if ($helpChoice -match '^[bB]$' -and $AllowBack) { return "__AWZ_BACK__" }
            continue
        }
        if ($input) {
            return $input
        }
        if ($Value) {
            return $Value
        }
        if (-not $Required) {
            return ""
        }
    }
}

function Show-AwzTuiPreview {
    param(
        [string[]]$PreviewLines,
        [string]$Target,
        [string]$Project,
        [string]$SelectedMode,
        [bool]$Refresh
    )

    $content = @(
        "目标   $Target",
        "项目   $Project",
        "模式   $SelectedMode     刷新 AWZ 文件   $Refresh",
        "",
        "完整 DryRun 输出已在上一页展示并停留 3 秒，可用终端原生滚动回看。",
        "确认无误后输入 A 应用，B 返回上一步，Q 退出。"
    )
    Show-AwzTuiFrame -Title "检查变更计划" -Subtitle "预览已通过；执行前请检查完整输出" -Content $content -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行" -Footer "A 应用；B 返回上一步；H 帮助；Q 退出"
    while ($true) {
        $choice = (Read-Host "输入 A 应用，B 返回，H 帮助或 Q 退出").Trim()
        if ($choice -match '^[aA]$') {
            return $true
        }
        if ($choice -match '^[qQ]$') {
            return "__AWZ_EXIT__"
        }
        if ($choice -match '^[bB]$') {
            return "__AWZ_BACK__"
        }
        if ($choice -match '^[hH?]$') {
            Show-AwzTuiFrame -Title "检查变更计划 · 帮助" -Subtitle "预览阶段不会写入文件" -Content @(
                "A  应用已通过 DryRun 的计划",
                "B  返回信息输入阶段",
                "Q  退出控制中心",
                "H  或 ? 再次查看帮助"
            ) -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行" -Footer "按 Enter 返回预览"
            $helpChoice = (Read-Host "按 Enter 返回预览").Trim()
            if ($helpChoice -match '^[qQ]$') { return "__AWZ_EXIT__" }
            if ($helpChoice -match '^[bB]$') { return "__AWZ_BACK__" }
        }
    }
}

function Show-AwzTuiLog {
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Lines,
        [string]$Step,
        [int]$PauseSeconds = 3
    )

    $content = @(
        "已记录 $($Lines.Count) 行输出。",
        "日志会保留 $PauseSeconds 秒，随后进入下一阶段。",
        ""
    )
    Show-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $content -Step $Step -Footer "日志展示中；请勿关闭终端"
    Write-Host ""
    Write-Host "── ACTIVITY LOG ─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    foreach ($line in $Lines) {
        if ($line -match '^(Wrote|Created|Ran|DryRun: preview complete)') {
            Write-Host $line -ForegroundColor Green
        }
        elseif ($line -match '^(DryRun:|WARNING:|Warning:)') {
            Write-Host $line -ForegroundColor Yellow
        }
        elseif ($line -match '(?i)error|refused|failed') {
            Write-Host $line -ForegroundColor Red
        }
        else {
            Write-Host $line
        }
    }
    Write-Host "────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "将在 $PauseSeconds 秒后继续…" -ForegroundColor DarkGray
    Start-Sleep -Seconds $PauseSeconds
}

Export-ModuleMember -Function @(
    "New-AwzTuiFrame",
    "Show-AwzTuiFrame",
    "Select-AwzTuiOption",
    "Read-AwzTuiText",
    "Show-AwzTuiPreview",
    "Show-AwzTuiLog"
)

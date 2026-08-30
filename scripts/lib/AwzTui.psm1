function Get-AwzDisplayWidth {
    param([string]$Text)

    $width = 0
    foreach ($cluster in @(Get-AwzDisplayClusters $Text)) {
        $width += Get-AwzClusterWidth $cluster
    }
    return $width
}

function Get-AwzCodePoints {
    param([string]$Text)

    $points = [System.Collections.Generic.List[int]]::new()
    for ($index = 0; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        if ([char]::IsHighSurrogate($character) -and ($index + 1) -lt $Text.Length -and [char]::IsLowSurrogate($Text[$index + 1])) {
            $points.Add([char]::ConvertToUtf32($character, $Text[$index + 1]))
            $index++
        }
        else {
            $points.Add([int]$character)
        }
    }
    return $points.ToArray()
}

function Test-AwzRegionalIndicator {
    param([int]$CodePoint)
    return $CodePoint -ge 0x1F1E6 -and $CodePoint -le 0x1F1FF
}

function Test-AwzEmojiCodePoint {
    param([int]$CodePoint)
    return $CodePoint -ge 0x1F000 -and $CodePoint -le 0x1FAFF
}

function Test-AwzZeroWidthCodePoint {
    param([int]$CodePoint)
    return (
        $CodePoint -eq 0x200D -or
        ($CodePoint -ge 0x0300 -and $CodePoint -le 0x036F) -or
        ($CodePoint -ge 0x1AB0 -and $CodePoint -le 0x1AFF) -or
        ($CodePoint -ge 0x1DC0 -and $CodePoint -le 0x1DFF) -or
        ($CodePoint -ge 0x20D0 -and $CodePoint -le 0x20FF) -or
        ($CodePoint -ge 0xFE00 -and $CodePoint -le 0xFE0F) -or
        ($CodePoint -ge 0xFE20 -and $CodePoint -le 0xFE2F) -or
        ($CodePoint -ge 0x1F3FB -and $CodePoint -le 0x1F3FF) -or
        ($CodePoint -ge 0xE0100 -and $CodePoint -le 0xE01EF)
    )
}

function Test-AwzWideCodePoint {
    param([int]$CodePoint)
    return (
        ($CodePoint -ge 0x1100 -and $CodePoint -le 0x115F) -or
        ($CodePoint -ge 0x2E80 -and $CodePoint -le 0xA4CF) -or
        ($CodePoint -ge 0xAC00 -and $CodePoint -le 0xD7A3) -or
        ($CodePoint -ge 0xF900 -and $CodePoint -le 0xFAFF) -or
        ($CodePoint -ge 0xFE10 -and $CodePoint -le 0xFE6F) -or
        ($CodePoint -ge 0xFF00 -and $CodePoint -le 0xFF60) -or
        ($CodePoint -ge 0xFFE0 -and $CodePoint -le 0xFFE6) -or
        ($CodePoint -ge 0x20000 -and $CodePoint -le 0x3FFFD) -or
        (Test-AwzEmojiCodePoint $CodePoint)
    )
}

function Get-AwzDisplayClusters {
    param([string]$Text)

    $elements = [System.Collections.Generic.List[string]]::new()
    $enumerator = [Globalization.StringInfo]::GetTextElementEnumerator($Text)
    while ($enumerator.MoveNext()) {
        $elements.Add($enumerator.GetTextElement())
    }

    $clusters = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $elements.Count; $index++) {
        $cluster = $elements[$index]
        $points = @(Get-AwzCodePoints $cluster)
        if ($points.Count -eq 1 -and (Test-AwzRegionalIndicator $points[0]) -and ($index + 1) -lt $elements.Count) {
            $nextPoints = @(Get-AwzCodePoints $elements[$index + 1])
            if ($nextPoints.Count -eq 1 -and (Test-AwzRegionalIndicator $nextPoints[0])) {
                $index++
                $cluster += $elements[$index]
            }
        }
        while (($index + 2) -lt $elements.Count) {
            $joiner = @(Get-AwzCodePoints $elements[$index + 1])
            if ($joiner.Count -ne 1 -or $joiner[0] -ne 0x200D) {
                break
            }
            $cluster += $elements[$index + 1] + $elements[$index + 2]
            $index += 2
        }
        if (($index + 1) -lt $elements.Count) {
            $modifier = @(Get-AwzCodePoints $elements[$index + 1])
            if ($modifier.Count -eq 1 -and $modifier[0] -ge 0x1F3FB -and $modifier[0] -le 0x1F3FF) {
                $index++
                $cluster += $elements[$index]
            }
        }
        $clusters.Add($cluster)
    }
    return $clusters.ToArray()
}

function Get-AwzClusterWidth {
    param([string]$Text)

    $points = @(Get-AwzCodePoints $Text)
    if ($points | Where-Object { $_ -eq 0x200D -or $_ -eq 0xFE0F -or (Test-AwzRegionalIndicator $_) -or (Test-AwzEmojiCodePoint $_) }) {
        return 2
    }
    $width = 0
    foreach ($codePoint in $points) {
        if (Test-AwzZeroWidthCodePoint $codePoint) {
            continue
        }
        $width += if (Test-AwzWideCodePoint $codePoint) { 2 } else { 1 }
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

    if ($MaxWidth -le 0) {
        return ""
    }
    $result = ""
    $used = 0
    foreach ($cluster in @(Get-AwzDisplayClusters $Text)) {
        $clusterWidth = Get-AwzClusterWidth $cluster
        if (($used + $clusterWidth) -gt ($MaxWidth - 1)) {
            break
        }
        $result += $cluster
        $used += $clusterWidth
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
    return [Math]::Min(108, [Math]::Max(44, $windowWidth - 2))
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

    $Width = [Math]::Max(44, $Width)
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

function Read-AwzTuiInput {
    param([string]$Prompt)

    $value = Read-Host $Prompt
    if ($null -eq $value) {
        return $null
    }
    return [string]$value
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
        $rawChoice = Read-AwzTuiInput $prompt
        if ($null -eq $rawChoice) {
            return $null
        }
        $choice = $rawChoice.Trim()
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

        $input = Read-AwzTuiInput $Label
        if ($null -eq $input) {
            if ($ExitOnQuit) { return "__AWZ_EXIT__" }
            return $null
        }
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
            $rawHelpChoice = Read-AwzTuiInput "按 Enter 返回输入"
            if ($null -eq $rawHelpChoice) {
                if ($ExitOnQuit) { return "__AWZ_EXIT__" }
                return $null
            }
            $helpChoice = $rawHelpChoice.Trim()
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
        $rawChoice = Read-AwzTuiInput "输入 A 应用，B 返回，H 帮助或 Q 退出"
        if ($null -eq $rawChoice) {
            return "__AWZ_EXIT__"
        }
        $choice = $rawChoice.Trim()
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
            $rawHelpChoice = Read-AwzTuiInput "按 Enter 返回预览"
            if ($null -eq $rawHelpChoice) { return "__AWZ_EXIT__" }
            $helpChoice = $rawHelpChoice.Trim()
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
    "Read-AwzTuiInput",
    "Select-AwzTuiOption",
    "Read-AwzTuiText",
    "Show-AwzTuiPreview",
    "Show-AwzTuiLog"
)

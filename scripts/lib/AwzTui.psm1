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
        [string]$Step
    )

    while ($true) {
        $content = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $content.Add("[$($i + 1)]  $($Options[$i].Label)")
            $content.Add("     $($Options[$i].Description)")
            $content.Add("")
        }
        Show-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $content.ToArray() -Step $Step -Footer "在面板下方输入编号；Q 退出"

        $choice = (Read-Host "选择 [1-$($Options.Count)] 或 Q").Trim()
        if ($choice -match '^[qQ]$') {
            return $null
        }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $Options.Count) {
            return $Options[$number - 1].Value
        }
    }
}

function Read-AwzTuiText {
    param(
        [string]$Title,
        [string]$Label,
        [string]$Value = "",
        [string]$Hint = "",
        [string]$Step,
        [switch]$Required
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
        Show-AwzTuiFrame -Title $Title -Subtitle "稳定输入模式：不逐键重绘终端" -Content $content -Step $Step -Footer "在面板下方输入；输入 Q 取消"

        $input = Read-Host $Label
        if ($input -ceq "Q") {
            return $null
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
        "确认无误后输入 A 应用，输入 Q 取消。"
    )
    Show-AwzTuiFrame -Title "检查变更计划" -Subtitle "预览已通过；执行前请检查完整输出" -Content $content -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行" -Footer "查看完整计划后输入 A 应用；Q 取消"
    while ($true) {
        $choice = (Read-Host "输入 A 应用，Q 取消").Trim()
        if ($choice -ceq "A") {
            return $true
        }
        if ($choice -match '^[qQ]$') {
            return $false
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

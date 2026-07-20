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
        [int]$BodyHeight = 14
    )

    $Width = [Math]::Max(76, $Width)
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
        [int]$BodyHeight = 14
    )

    Clear-Host
    $frame = New-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $Content -Step $Step -Footer $Footer -Width (Get-AwzTuiWidth) -BodyHeight $BodyHeight
    foreach ($line in $frame) {
        if ($line.StartsWith("╭") -or $line.StartsWith("├") -or $line.StartsWith("╰") -or $line.Contains("AWZ WORKFLOW")) {
            Write-Host $line -ForegroundColor Cyan
        }
        elseif ($line.Contains("❯")) {
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

    $selected = 0
    while ($true) {
        $content = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $prefix = if ($i -eq $selected) { "❯" } else { " " }
            $content.Add("$prefix  $($Options[$i].Label)")
            $content.Add("     $($Options[$i].Description)")
            $content.Add("")
        }
        Show-AwzTuiFrame -Title $Title -Subtitle $Subtitle -Content $content.ToArray() -Step $Step -Footer "↑↓ 移动    Enter 确认    Q 退出"

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow" { $selected = ($selected - 1 + $Options.Count) % $Options.Count }
            "DownArrow" { $selected = ($selected + 1) % $Options.Count }
            "Enter" { return $Options[$selected].Value }
            "Escape" { return $null }
            "Q" { return $null }
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

    $buffer = $Value
    while ($true) {
        $shown = if ($buffer) { $buffer } else { " " }
        $content = @(
            $Label,
            "",
            "┌" + ("─" * 66) + "┐",
            "│ " + (Pad-AwzDisplayText -Text "$shown█" -Width 64) + " │",
            "└" + ("─" * 66) + "┘",
            "",
            $Hint
        )
        Show-AwzTuiFrame -Title $Title -Subtitle "直接输入；支持粘贴路径" -Content $content -Step $Step -Footer "Enter 下一步    Backspace 删除    Esc 取消"

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "Enter" {
                if ((-not $Required) -or $buffer) {
                    return $buffer
                }
            }
            "Escape" { return $null }
            "Backspace" {
                if ($buffer.Length -gt 0) {
                    $buffer = $buffer.Substring(0, $buffer.Length - 1)
                }
            }
            default {
                if (-not [char]::IsControl($key.KeyChar)) {
                    $buffer += $key.KeyChar
                }
            }
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

    $offset = 0
    $pageSize = 8
    while ($true) {
        $maxOffset = [Math]::Max(0, $PreviewLines.Count - $pageSize)
        $offset = [Math]::Min($maxOffset, [Math]::Max(0, $offset))
        $page = @($PreviewLines | Select-Object -Skip $offset -First $pageSize)
        $content = @(
            "目标   $Target",
            "项目   $Project",
            "模式   $SelectedMode     刷新 AWZ 文件   $Refresh",
            "",
            "DRY RUN  $($offset + 1)-$([Math]::Min($PreviewLines.Count, $offset + $pageSize)) / $($PreviewLines.Count)",
            "──────────────────────────────────────────────────────────────────"
        ) + $page

        Show-AwzTuiFrame -Title "检查变更计划" -Subtitle "预览已通过；执行前请检查完整输出" -Content $content -Step "01  模式   ───   02  信息   ───   03 [预览]  ───   04  执行" -Footer "↑↓ 滚动    PgUp/PgDn 翻页    Enter/A 应用    Q 取消"
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow" { $offset-- }
            "DownArrow" { $offset++ }
            "PageUp" { $offset -= $pageSize }
            "PageDown" { $offset += $pageSize }
            "Home" { $offset = 0 }
            "End" { $offset = $maxOffset }
            "Enter" { return $true }
            "A" { return $true }
            "Escape" { return $false }
            "Q" { return $false }
        }
    }
}

Export-ModuleMember -Function @(
    "New-AwzTuiFrame",
    "Show-AwzTuiFrame",
    "Select-AwzTuiOption",
    "Read-AwzTuiText",
    "Show-AwzTuiPreview"
)

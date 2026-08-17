# 文件搜索指南

仅在跨目录、跨盘或不知道目标位置时读取本文件。项目内文本和文件定位优先使用 `rg` / `rg --files`。

## Windows 跨盘搜索

优先探测本机 Everything HTTP API，避免用 `Get-ChildItem -Recurse` 扫全盘：

```powershell
try {
    $r = Invoke-WebRequest 'http://localhost:8080/' -UseBasicParsing -TimeoutSec 3
    $ok = $r.Headers['Server'] -match 'Everything'
} catch { $ok = $false }
```

端点可用时查询：

```text
http://localhost:8080/?search=<QUERY>&json=1&count=<N>[&path_column=1&size_column=1]
```

- `<QUERY>` 需要 URL encode；PowerShell 使用 `[uri]::EscapeDataString($q)`。
- 常用条件：`ext:md`、`path:E:\Project`、`path:"E:\A B"`、`!folder:`、`folder:`、`size:>10mb`、`dm:today`。
- 空格连接为 AND，`|` 为 OR；结果多时使用 `count` + `offset` 分页。

## 回退

1. Everything 可用：使用 HTTP API。
2. 服务未开、非 Windows/NTFS 或目标不在索引内：回退到 `rg --files`、限定范围的 `Get-ChildItem` 或 `find`。
3. 范围过大时先收窄或说明成本，不静默递归扫描全盘。

Everything 默认只索引 NTFS 文件名和元数据，不保证覆盖文件内容、网络盘、WSL Linux 文件系统、FAT32 或 exFAT。

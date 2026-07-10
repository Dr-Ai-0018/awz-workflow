# 验证指南

## 三层验证

`DryRun`：回答“如果执行，会改什么”。

- 不写文件；
- 不创建目录；
- 不初始化 git；
- 不安装依赖；
- 不修改用户环境。

`Smoke`：回答“最小闭环能不能跑”。

`Full Check`：回答“这个阶段能不能交付或合并”。

## Python

- 本地开发、依赖管理、测试优先用 `uv`。
- `uv` 不可用或项目约束不适合时，回退到 `python -m venv`。
- 涉及部署时，文档必须兼容 `venv`。
- 不因为想跑 pytest 就自动生成 `pyproject.toml`。
- 只有确实是 Python 包、服务、测试工程或需要依赖锁定时，才生成 `pyproject.toml`。

## Node / Frontend

- 本地开发和测试优先用 `pnpm`。
- `pnpm` 不可用或项目约束不适合时，回退到 `npm`。
- 涉及部署时，文档必须兼容 `npm`。
- 不因为想跑 TypeScript 检查就自动生成 `package.json`。
- 只有确实需要 Node 工具链、前端工程、构建脚本或测试脚本时，才生成 `package.json`。

## 文件定位

跨目录、跨盘、面向未知位置的文件定位，优先走本机 Everything HTTP API，不要用 `Get-ChildItem -Recurse` / `find` 手动扫全盘。

### 探测

使用前先确认端点：

```powershell
try {
    $r = Invoke-WebRequest 'http://localhost:8080/' -UseBasicParsing -TimeoutSec 3
    $ok = $r.Headers['Server'] -match 'Everything'
} catch { $ok = $false }
```

`Server: Everything HTTP Server` 存在即可用；默认端口 8080，跟随实际配置。

### 查询

URL：`http://localhost:8080/?search=<QUERY>&json=1&count=<N>[&path_column=1&size_column=1]`

- `<QUERY>` 需要 URL encode（PowerShell：`[uri]::EscapeDataString($q)`）。
- 常用 filter：`ext:md`、`path:E:\Project`、`path:"E:\A B"`、`!folder:`（排除目录）、`folder:`（只留目录）、`size:>10mb`、`dm:today`。
- 直接输名字做 substring 匹配。多条件空格连接为 AND，`|` 为 OR。

返回 JSON：`totalResults` + `results[]`，每条含 `type`（file/folder）、`name`、`path`、`size`。`totalResults` 永远是全量数，用 `count` + `offset` 分页拉。

### 回退

1. 探测通过 → 走 Everything HTTP。
2. 不可达（服务未开、Linux/macOS、非 NTFS 卷）→ 回退到 `Get-ChildItem -Recurse` / `find` / `rg --files`。
3. 回退时如果范围过大，先收窄或说明预期耗时，不要静默硬跑。

### 边界

- 只索引 NTFS 卷；FAT32、exFAT、网络盘、WSL 里的 Linux 文件系统不进索引。
- 默认只索引文件名/元数据，不索引内容（`content:` 需 UI 手动打开，视为默认不支持）。
- 结果可能包含普通 PS 因 ACL 看不到的路径。

## 测试目录

验证初始化脚本、生成器或一次性输出时，默认使用本项目的 `temp/` 目录。

推荐：

```text
temp/smoke-<timestamp>/
temp/dryrun-<timestamp>/
temp/output/
```

不要默认写到 `C:\tmp`、桌面、下载目录或其他项目外路径。

## 交接

最终交接说明：

```text
验证层级：
运行命令：
结果：
未验证：
原因：
后续建议：
```

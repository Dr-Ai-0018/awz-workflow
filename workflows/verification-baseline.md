# 验证和检测基线

本文件定义 Agent 在项目中如何选择检查命令。核心原则：先检测已有入口，再执行最小有效验证；不要为了验证而强行生成项目并不需要的配置文件。

## 环境与文本语义

首次构建、已有项目接入或环境变化时，先探测 OS/架构、实际 shell executable/version、编码与行尾、Git、runtime/package manager 和已验证入口；只把会影响后续执行的事实写入 `docs/references/README.md`。

- 不把 PowerShell、cmd、Bash 的引号和转义互相照搬。PowerShell 的“反引号 + n”只在正确的可展开字符串中表示换行；单引号或额外转义层会把它写成字面量。
- Windows PowerShell 5.1 与 PowerShell 7 不能只凭同名假定编码行为一致。
- 多行文档优先使用结构化 edit/patch；必须经 shell 写入时，立即回读实际字符、编码与行尾。
- 初始化器、生成器或批量写入应加入文件尾或字节级回归断言，不依赖肉眼检查。

## 三层验证

### DryRun

回答“如果执行，会改什么”。

适用：

- 初始化项目；
- 批量生成文件；
- 可能覆盖已有文件；
- 涉及目录结构或配置写入。

要求：

- 不写文件；
- 不创建目录；
- 不初始化 git；
- 不安装依赖；
- 清楚列出将写入、将跳过、将覆盖、将不生成的内容。

### Smoke

回答“最小闭环能不能跑”。

适用：

- 初始化后；
- 修复后；
- 交接前；
- 不确定完整测试是否昂贵时。

例子：

- Python：导入主模块、启动 app、跑一个最小 pytest；
- Frontend：启动 dev server、打开页面、确认无白屏；
- CLI：运行 `--help` 或最小命令；
- API：命中 health check 或最小 contract。

### Full Check

回答“这个阶段能不能交付或合并”。

适用：

- 合并回 `main` 前；
- 大功能完成；
- release 前；
- 触及共享逻辑或公共 contract。

可能包括：

- test；
- lint；
- typecheck；
- build；
- browser preview；
- migration dry-run；
- security/privacy spot check。

## Python 检测顺序

1. 如果存在 `pyproject.toml`，优先检查是否可用 `uv`：
   - `uv sync`
   - `uv run pytest`
2. 如果没有 `uv` 或项目明确不用 `uv`，检查 venv 路径：
   - `python -m venv .venv`
   - `.\.venv\Scripts\Activate.ps1`
   - `pip install -r requirements.txt`
   - `pytest`
3. 如果只有脚本，没有测试框架：
   - 运行主脚本的 `--help`、导入检查或最小示例。
4. 不因为想跑 pytest 就自动生成 `pyproject.toml`。

## Node / TypeScript 检测顺序

1. 如果存在 `package.json`，先读取 `scripts`。
2. 优先使用 `pnpm`：
   - `pnpm install`
   - `pnpm test`
   - `pnpm lint`
   - `pnpm typecheck`
   - `pnpm build`
3. 如果没有 `pnpm` 或部署路径要求，回退 `npm`：
   - `npm install`
   - `npm test`
   - `npm run lint`
   - `npm run typecheck`
   - `npm run build`
4. 如果存在 `tsconfig.json` 但没有 script，可以说明缺少 typecheck 入口，必要时建议补 `typecheck` script。
5. 不因为想跑 TypeScript 检查就自动生成 `package.json`。

## 前端浏览器验证

前端变更不能只看 build。

至少确认：

- 页面不是白屏；
- console 没有关键 error；
- 核心交互可点击；
- 主要 viewport 不重叠、不溢出；
- modal、toast、滚动条、focus 等基础 UI 没有裸奔。

有真实浏览器控制工具时，优先真实浏览器。遇到登录、MFA、验证码时停下等用户操作。

## 输出格式

最终交接里写清楚：

```text
验证层级：
运行命令：
结果：
未验证：
原因：
后续建议：
```

不要只说“测试通过”。要说明跑了什么，以及没跑什么。

## 入口与可发现性

用户可见功能不能只证明底层函数或隐藏 CLI 可调用。交付前至少确认：

- 主 README、根命令 `--help` 或 TUI 主菜单能找到该能力；
- 文档中的入口、参数和界面名称与真实实现一致；
- smoke 从用户实际入口进入，而不是绕过编排层直接调用内部函数；
- 交互能力要验证取消、错误、长路径和结果回看，不能用静态 render 代替真实交互；
- backend CLI 完成不等于 TUI lifecycle 完成，必须分别报告能力边界。

如果能力暂未接入主入口，应明确标为“内部/脚本化接口”或“未完成”，不能以代码存在替代可用性。

## 文件定位

跨目录、跨盘、面向未知位置的文件定位，优先走 Everything HTTP API，不要用 `Get-ChildItem -Recurse` / `find` 手动遍历。

基准数据（341 万文件的机器上）：小项目 100x，`C:\Windows` 全体 6800x，全盘搜索 PS 端 300 秒超时未完成、Everything 50–120ms 秒回。差距是结构性的（NTFS MFT + USN Journal 内存索引 vs 递归系统调用），不是"快一点"。

### 探测

任何 Agent 在使用前先探测端点是否可用：

```powershell
try {
    $r = Invoke-WebRequest 'http://localhost:8080/' -UseBasicParsing -TimeoutSec 3
    $ok = $r.Headers['Server'] -match 'Everything'
} catch { $ok = $false }
```

`Server: Everything HTTP Server` 存在即可用。默认端口 8080，用户改过就跟随实际配置。

### 查询语法

URL：`http://localhost:8080/?search=<QUERY>&json=1&count=<N>[&path_column=1&size_column=1]`

`<QUERY>` 需要 URL encode（PowerShell：`[uri]::EscapeDataString($q)`）。常用 filter：

- `ext:md`：按扩展名。
- `path:E:\Project`：限定路径前缀，含空格用 `path:"E:\A B"`。
- `!folder:`：排除文件夹结果，只留 file。
- `folder:`：只留文件夹结果。
- `size:>10mb`、`dm:today`：大小/时间过滤。
- 直接输 `readme`：文件名 substring 匹配。
- 多条件空格连接为 AND，`|` 为 OR。

返回 JSON 形状：

```json
{ "totalResults": 6829, "results": [ { "type": "file", "name": "...", "path": "...", "size": "..." } ] }
```

`totalResults` 永远是全量结果数，不受 `count` 限制。结果集大时用 `count=` + `offset=` 分页，别一次拉几十万条。

### 回退顺序

1. 探测通过 → 走 Everything HTTP。
2. 端点不可达（服务未开、Linux/macOS、非 NTFS 卷）→ 回退到 `Get-ChildItem -Recurse` / `find` / `rg --files`。
3. 回退时如果范围显然过大（全盘 / 百万文件级目录），先说明预期耗时或收窄范围，不要静默硬跑。

### 边界

- 只索引 NTFS 卷；FAT32、exFAT、网络盘、WSL 里的 Linux 文件系统不进索引。
- 默认不索引文件**内容**（只有名字、路径、元数据）；`content:` 语法需要用户在 UI 里手动打开内容索引，默认视为不支持。
- 索引经内核 raw volume 读取，包含普通 PS 因 ACL 看不到的路径。这是能力优势，但意味着结果可能大于/不同于用户态遍历。

## Reference Library 验证

参考项目库默认使用离线检查：

1. `status` 检查配置、catalog、repo、revision、dirty state 和项目 mapping。
2. `doctor` 进行严格检查，存在错误时返回非零。
3. `add --dry-run`、`configure --dry-run` 不创建目录、不写配置、不 clone。
4. smoke 必须使用隔离的 `AWZ_CONFIG_DIR` 和本地 Git fixture，不得访问公网或真实参考库。
5. Reference Library 不可用不能破坏核心项目初始化。

## 测试目录

验证初始化脚本、生成器或一次性输出时，默认使用本项目的 `temp/` 目录。

推荐：

```text
temp/smoke-<timestamp>/
temp/dryrun-<timestamp>/
temp/output/
```

如果本项目还没有 `temp/`，先创建 `temp/`，再把 smoke/dryrun 目标放进去。

避免默认写到 `C:\tmp`、用户桌面、下载目录或其他项目外路径。只有在用户明确指定、权限限制必须绕开，或需要模拟外部路径时，才使用项目外测试目录，并在交接里说明原因。

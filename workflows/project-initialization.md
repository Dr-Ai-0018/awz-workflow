# 项目初始化工作流

用于安全启动新项目。已有项目接入 AWZ Workflow 时必须显式进入 `Existing` 模式，不能与新项目初始化共用默认行为。

## 初始化模式与安全边界

初始化器提供两个语义严格分离的模式：

| 模式 | PowerShell | POSIX | 允许的目标 |
| --- | --- | --- | --- |
| 新项目（默认） | `-Mode New` | `--mode new` | 不存在或完全为空的目录 |
| 已有项目（显式） | `-Mode Existing` | `--mode existing` | 已存在的目录 |

硬边界：

1. 默认 `New` 模式遇到任何已有条目都必须在写入前失败，包括隐藏文件、`.git/`、旧 `.env` 和旧工程文件。
2. `-Force` / `--force` 不能绕过 `New` 模式，只能与显式 `Existing` 模式组合使用。
3. `Existing` 模式默认保留已有文件，只补充缺失基线；force 只刷新 AWZ 管理的本地指导文件。
4. 已有项目的 `.gitignore`、`.env.example`、`README.md`、`LICENSE` 永远视为项目自有文件，即使指定 force 也不能覆盖。
5. `Existing` 模式不能指向不存在的目录，避免把参数写错后静默创建成新项目。
6. 所有模板、目标类型、模式和 `git` 前置条件必须在首次写入前完成校验。
7. 执行已有项目模式前必须先跑 DryRun，并 review 将写入、跳过或覆盖的清单。

默认新项目示例：

```powershell
.\scripts\init-project.ps1 -TargetPath 'E:\Project\Example' -ProjectName 'Example' -DryRun
.\scripts\init-project.ps1 -TargetPath 'E:\Project\Example' -ProjectName 'Example'
```

Windows `cmd` / BAT 入口复用同一份 PowerShell 核心逻辑：

```bat
scripts\init-project.bat -TargetPath "E:\Project\Example" -ProjectName "Example" -DryRun
scripts\init-project.bat -TargetPath "E:\Project\Example" -ProjectName "Example"
```

已有项目示例：

```powershell
.\scripts\init-project.ps1 -TargetPath 'E:\Project\Existing' -Mode Existing -DryRun
.\scripts\init-project.ps1 -TargetPath 'E:\Project\Existing' -Mode Existing
```

不要在未 review DryRun 的情况下给已有项目追加 `-Force`。

## 必需基线

每个项目默认应该具备：

- git 初始化在 `main` 分支；
- `.gitignore`；
- `.env.example`；
- 本地 ignored `AGENTS.md`；
- 本地 ignored `CLAUDE.md`，并导入 `AGENTS.md`；
- 本地 ignored `docs/`；
- 本地 ignored `temp/`；
- license，默认 MIT；
- README，包含 quickstart 和常用命令。

注意：必需基线不包含 `pyproject.toml`、`package.json`、Docker、CI 或部署配置。

注意：`AGENTS.md` 和 `CLAUDE.md` 会生成在项目根目录，方便本地 Agent 读取，但默认不进 git。

初始化器只接受目录目标，且不允许把 AWZ Workflow 自身源码目录作为目标。需要新建 git 仓库时，必须在任何文件或目录写入前确认 `git` 可用；缺失时直接报错，不留下半成品基线。不能把“跳过同名文件”等同于“对已有项目安全”，因为新增 README、LICENSE、Agent 规则或目录同样会污染旧项目。

## 忽略规则

生成的 `.gitignore` 至少包含：

```gitignore
.codex/
.claude/
.vscode/
/AGENTS.md
/CLAUDE.md
.env
.env.*
!.env.example
docs/
docs/agent-room/
docs/agent-room/onboarding.md
docs/agent-room/guides/
docs/agent-room/handoffs/
docs/agent-room/reviews/
docs/agent-room/decisions/
docs/agent-room/notes/
docs/plans/
temp/
```

再根据项目语言和框架补充对应忽略项。

## 工具检测

检测只决定“怎么执行已有项目”，不自动制造不需要的工程文件。

默认不生成：

- `pyproject.toml`
- `package.json`
- `docker-compose.yml`
- GitHub Actions
- Cloudflare Pages 配置

只有在项目真实使用对应技术栈、用户明确要求、或规模已经需要时，才生成这些文件。

Python：

1. 优先使用 `uv`。
2. 不可用时回退到 `python -m venv`。
3. 部署文档保留 `venv` 兼容路径。
4. 只有项目确实是 Python 包、Python 服务或需要依赖锁定时，才生成 `pyproject.toml`。

Node：

1. 优先使用 `pnpm`。
2. 不可用时回退到 `npm`。
3. 部署文档保留 `npm` 兼容路径。
4. 只有项目确实需要 Node 工具链、前端工程或构建脚本时，才生成 `package.json`。

## DryRun

初始化脚本应该支持 `-DryRun`，用于预览而不写入文件。

`DryRun` 必须说明：

- 将写入哪些文件；
- 将创建哪些目录；
- 哪些文件已存在，会跳过还是被 `-Force` 覆盖；
- 目标目录是否因模式不匹配而被拒绝；
- 是否会执行 `git init -b main`；
- 哪些配置因为项目规模或技术栈不足而故意不生成。

`DryRun` 禁止：

- 创建目录；
- 写入文件；
- 初始化 git；
- 安装依赖；
- 修改用户环境。

`DryRun` 不是测试。它只是变更预演。真实验证仍要用 smoke/test/check。

## CLI、BAT 与后续 TUI 分层

- `init-project.ps1`：Windows 核心实现与稳定参数接口。
- `init-project.sh`：Ubuntu/POSIX 核心实现，与 PowerShell 保持行为对齐。
- `init-project.bat`：Windows 快捷入口，只负责选择 `pwsh`/Windows PowerShell 并转发参数，不复制初始化逻辑。
- `awz.bat` / `awz.ps1` / `awz.sh`：终端交互入口，只负责收集目标路径、模式、项目名和确认信息；必须调用核心脚本的 DryRun/执行接口，不能另写一套文件生成逻辑。

后续新增 refresh、模板升级、差异预览或技术栈选择时，应使用独立 subcommand/脚本和 manifest，不要继续扩大 `init` 的覆盖权限。

完整交互与脚本化调用契约见 `workflows/tui.md`。

## 规模判断

小项目：

- 默认不上 Docker；
- 本地命令足够；
- README 保持简洁；
- 任务 checklist 放在 ignored `docs/`。

中型项目：

- 增加 lint/test 命令；
- Docker 能提升复现性时再加 `docker-compose.yml`；
- 可以考虑 GitHub Actions。

大型或需要部署的项目：

- 明确部署目标；
- 按需加入 Docker/compose；
- 加入 CI 检查；
- 加入 release checklist；
- 记录 rollback 路径。

## 初始目录建议

Backend/API：

```text
src/
tests/
scripts/
```

Frontend：

```text
src/
  components/
  features/
  styles/
  lib/
  hooks/
  routes/
tests/
```

Full-stack：

```text
backend/
frontend/
shared/
scripts/
tests/
```

## 初始化后验证

1. 确认 `git status --short`。
2. 确认 ignored 路径没有被 staged。
3. 确认 `AGENTS.md`、`CLAUDE.md`、`docs/`、`temp/` 不会被 git 看到。
4. 确认 `.env.example` 能被 git 看到。
5. 确认 `docs/agent-room/status.md` 已生成。
6. 确认 `docs/README.md`、`temp/README.md`、agent onboarding、分层 guides、review/release/handoff/decision 模板已生成到 ignored 本地工作区。
7. 运行最小可用 smoke command。
8. 总结已经生成什么，以及哪些东西是故意没生成。

详见 `workflows/verification-baseline.md`。

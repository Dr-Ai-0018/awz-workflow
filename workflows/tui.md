# TUI 与 CLI 工作流

本文件定义 AWZ Workflow 的终端交互入口。TUI 是初始化器之上的轻量编排层，不拥有文件生成或覆盖权限。

## 入口

Windows：

```powershell
.\scripts\awz.bat
.\scripts\awz.ps1
```

Ubuntu/POSIX：

```bash
bash scripts/awz.sh
```

`awz.bat` 只选择 `pwsh` 或 Windows PowerShell，并把参数转交给 `awz.ps1`。`awz.ps1` 与 `awz.sh` 负责交互；真实初始化仍分别由 `init-project.ps1` 与 `init-project.sh` 完成。

## v1 功能

交互模式提供：

1. 创建新项目；
2. 接入已有项目；
3. 输入目标目录；
4. 从目标目录推断项目名；
5. 已有项目是否刷新 AWZ 管理文件的显式选择；
6. 强制 DryRun；
7. 执行前确认；
8. 完成后显示 `git status --short`。

默认确认使用 `y`。已有项目且刷新 AWZ 文件时，必须输入大写 `APPLY`；脚本化调用则需要同时显式给出 Existing、Force 和 Yes。

## 安全不变量

- TUI 不能跳过底层初始化器的目标类型、非空目录、模式或 force 检查。
- `-Yes` / `--yes` 只能跳过人工确认，不能跳过 DryRun。
- DryRun 失败时不能进入执行阶段。
- TUI 不直接复制模板、创建目录或运行 `git init`。
- Existing 模式仍永久保护项目自有的 `.gitignore`、`.env.example`、`README.md` 和 `LICENSE`。
- 登录、密钥、环境变量或技术栈配置不在 v1 TUI 中自动推断或写入。

## 脚本化调用

PowerShell：

```powershell
.\scripts\awz.ps1 `
  -Action init `
  -TargetPath 'E:\Project\Example' `
  -ProjectName 'Example' `
  -Mode New `
  -DryRunOnly

.\scripts\awz.ps1 `
  -Action init `
  -TargetPath 'E:\Project\Example' `
  -ProjectName 'Example' `
  -Mode New `
  -Yes
```

POSIX：

```bash
bash scripts/awz.sh \
  --action init \
  --target "$HOME/projects/example" \
  --name "Example" \
  --mode new \
  --dry-run-only

bash scripts/awz.sh \
  --action init \
  --target "$HOME/projects/example" \
  --name "Example" \
  --mode new \
  --yes
```

## 验证

```powershell
.\scripts\smoke-awz-tui.ps1
```

```bash
bash scripts/smoke-awz-tui.sh
```

两端 smoke 必须验证：

- help 可用；
- DryRunOnly 不创建目标；
- 确认执行后创建完整基线和 `.git/`；
- 默认模式拒绝非空目标；
- 被拒绝目标不出现新增模板文件；
- Windows BAT 参数转发可用；
- 测试结束后没有临时残留。

## 后续演进

TUI 后续按独立 action/subcommand 扩展：

1. `doctor`：检查 Git、PowerShell/Bash、uv、pnpm 等环境能力，只报告不安装。
2. `refresh`：基于 manifest hash 展示 AWZ 管理文件差异，再选择 apply。
3. `plan --json`：输出机器可读变更计划，供更完整的全屏 TUI 或其他前端消费。
4. 技术栈初始化：仅在用户明确选择 Python/Node 等类型后调用独立脚手架，不并入通用 init。

新增 action 不能扩大 `init` 权限，也不能通过交互层绕开底层脚本的安全边界。

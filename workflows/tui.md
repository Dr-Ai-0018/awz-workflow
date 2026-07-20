# TUI 与 CLI 工作流

本文件定义 AWZ Workflow 的终端交互入口。TUI 是初始化器之上的轻量编排层，不拥有文件生成或覆盖权限。

## 入口

Windows：

```powershell
.\scripts\awz.bat
.\scripts\awz.ps1
```

从其他目录使用绝对路径时：

```powershell
& 'E:\Project\AWZ Workflow\scripts\awz.bat'
& 'E:\Project\AWZ Workflow\scripts\awz.ps1'
```

不能省略 `&` 或路径两侧的引号，否则 PowerShell 会把空格后的内容拆成另一条命令。

Ubuntu/POSIX：

```bash
bash scripts/awz.sh
```

`awz.bat` 只选择 `pwsh` 或 Windows PowerShell，并把参数转交给 `awz.ps1`。`awz.ps1` 与 `awz.sh` 负责交互；真实初始化仍分别由 `init-project.ps1` 与 `init-project.sh` 完成。

Windows 全屏渲染、中文宽度计算、方向键输入和滚动预览集中在 `scripts/lib/AwzTui.psm1`；`awz.ps1` 只保留流程编排与底层初始化器调用，避免继续膨胀成单文件应用。

## Windows 全屏 TUI

`awz.bat` 默认用 `-NoProfile` 启动 PowerShell，`awz.ps1` 在真实终端中默认进入全屏模式。它提供：

1. 方向键选择新项目或已有项目模式；
2. 分步输入目标目录、项目名和 License owner；
3. 已有项目刷新策略选择；
4. 强制 DryRun 和可滚动预览窗口；
5. Existing + Force 的 `APPLY` 明文确认；
6. 执行中、完成和错误状态页面；
7. 中文等宽布局宽度修正和窄窗口内容裁剪；
8. 退出时恢复光标状态。

方向键、`PageUp` / `PageDown`、`Home` / `End` 用于选择或滚动，`Enter` 确认，`Q` / `Esc` 取消。已有项目且刷新 AWZ 文件时，必须输入大写 `APPLY`；脚本化调用则需要同时显式给出 Existing、Force 和 Yes。

终端不支持 `ReadKey`、输入被重定向或需要传统提示时，可以使用：

```powershell
.\scripts\awz.ps1 -Classic
```

视觉契约可以在不进入交互状态机时渲染：

```powershell
.\scripts\awz.ps1 -RenderDemo
```

POSIX `awz.sh` 当前保留引导式交互与相同安全语义；后续再对齐全屏渲染，不在两种 shell 中复制底层初始化逻辑。

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
- 全屏 frame 包含完整边框、步骤栏、选中态与快捷键栏；
- 测试结束后没有临时残留。

## 后续演进

TUI 后续按独立 action/subcommand 扩展：

1. `doctor`：检查 Git、PowerShell/Bash、uv、pnpm 等环境能力，只报告不安装。
2. `refresh`：基于 manifest hash 展示 AWZ 管理文件差异，再选择 apply。
3. `plan --json`：输出机器可读变更计划，供更完整的全屏 TUI 或其他前端消费。
4. 技术栈初始化：仅在用户明确选择 Python/Node 等类型后调用独立脚手架，不并入通用 init。

新增 action 不能扩大 `init` 权限，也不能通过交互层绕开底层脚本的安全边界。

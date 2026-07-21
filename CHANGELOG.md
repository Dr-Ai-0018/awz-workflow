# Changelog

本文件记录 AWZ Workflow 对使用者有影响的变更。版本号以 `VERSION` 为唯一来源。

格式参考 Keep a Changelog，并使用语义化版本号。

## [Unreleased]

### Added

- Windows 与 POSIX 的初始化器轻量回归 smoke 脚本。
- Windows `init-project.bat` 快捷入口，复用 PowerShell 核心实现并为后续交互入口保留稳定参数层。
- Windows `awz.bat` / `awz.ps1` 与 POSIX `awz.sh` 终端交互入口。
- TUI 的强制 DryRun、确认执行、脚本化参数和跨平台 smoke 覆盖。

### Fixed

- 初始化器在写入前校验目标类型、工作流源码目录和 `git` 前置条件，避免失败时留下半成品目录。
- 新项目 README 不再预置尚未选择技术栈时必然失败的 Python/Node 命令。
- 默认新项目初始化拒绝非空目录，避免把 AWZ 文件混入同名旧项目。
- `Force` 不能再绕过新项目安全检查，已有项目接入必须显式选择对应模式。
- 已有项目模式即使使用 `Force` 也会保留项目自有的 `.gitignore`、`.env.example`、`README.md` 和 `LICENSE`。

### Changed

- 精简发布工作流中的历史实施叙述，改为当前发布基线与后续发布流程。
- PowerShell 与 POSIX 初始化器统一为 `New`/`Existing` 双模式，并在首次写入前校验完整模板集。
- Windows TUI 从编号提示升级为全屏方向键状态机，增加分步表单、滚动预览和完成/错误页面。

## [0.2.0] - 2026-07-12

### Added

- Ubuntu/POSIX 初始化入口 `scripts/init-project.sh`。
- Windows 与 POSIX 的 release 打包入口。
- 可用于 VPS 的版本包、验证和回退基线。

### Verified

- Windows PowerShell 的 dry-run、真实初始化、隔离解压初始化与默认打包。
- Ubuntu VPS 的 dry-run、真实初始化、重复运行保护、参数报错与解压隔离初始化。
- release 包不包含 `.git`、`docs/`、`temp/`、`dist/` 等本地开发产物。

## [0.1.0]

### Added

- Windows PowerShell 项目初始化器。
- 本地 ignored Agent 协作区与分层指导模板。
- DryRun、仓库卫生、验证、Git、架构与前端基线。

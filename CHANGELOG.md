# Changelog

本文件记录 AWZ Workflow 对使用者有影响的变更。版本号以 `VERSION` 为唯一来源。

格式参考 Keep a Changelog，并使用语义化版本号。

## [Unreleased]

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

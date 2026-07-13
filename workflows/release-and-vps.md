# Release 与 VPS 初始化工作流

本文件定义 AWZ Workflow 如何从 Windows 本地基线，演进为可在 Ubuntu VPS 上复用的初始化工具。

目标是让 VPS 上的新项目也能得到同一套最小基线，而不是把 Windows 脚本硬搬过去，或在服务器上临时拼命令。

## 当前状态

截至 `v0.1`：

- Windows 初始化入口是 `scripts/init-project.ps1`；
- 它已支持 `-DryRun`、`-Force`、UTF-8 模板渲染和 `git init -b main`；
- 它**不能**作为 Ubuntu 的默认入口；
- 仓库尚未提供 Linux 初始化脚本、版本包或远端 release。

因此，在 Linux 初始化器完成前，不能在 VPS 文档里宣称 AWZ Workflow 已可一键初始化。可以先保留手动初始化需求，但不应把未验证的命令当正式路径。

## v0.2 交付目标

在宣布支持 VPS 前，至少完成：

```text
VERSION
CHANGELOG.md
scripts/init-project.sh
scripts/package-release.ps1
scripts/package-release.sh
dist/awz-workflow-v<version>.tar.gz
```

其中：

- `VERSION`：单一版本来源，例如 `0.2.0`；
- `CHANGELOG.md`：记录对使用者有影响的新增、修复和兼容性变化；
- `init-project.sh`：Ubuntu/POSIX shell 初始化入口；
- 两个 `package-release` 脚本：在 Windows 与 Linux/macOS 上生成同一格式的 release 包；
- `dist/`：只放可分发产物，不进 git；
- release 包必须带齐脚本、模板、LICENSE、README、VERSION、CHANGELOG，不依赖开发机上的其他目录。

Windows 和 Linux 初始化器必须对齐这些语义：

| 能力 | Windows | Ubuntu / POSIX |
| --- | --- | --- |
| 预演 | `-DryRun` | `--dry-run` |
| 目标目录 | `-TargetPath` | `--target` |
| 项目名 | `-ProjectName` | `--name` |
| 覆盖已有模板 | `-Force` | `--force` |
| Git 默认分支 | `git init -b main` | `git init -b main` |
| 模板编码 | UTF-8 | UTF-8 |
| 不自动生成技术栈配置 | 保持 | 保持 |

参数形式可以因 shell 习惯不同而不同，行为不能悄悄分叉。新增或修改模板后，要用同一个测试清单验证两个入口。

## Linux 初始化器约束

`scripts/init-project.sh` 使用 `bash`，顶部声明：

```bash
#!/usr/bin/env bash
set -euo pipefail
```

实现时遵守：

1. 只依赖 Ubuntu 常见基础工具：`bash`、`cp`、`mkdir`、`git`、`date`；不把 `jq`、`rsync` 或 GNU 专属扩展作为前置条件。
2. 所有路径必须双引号包裹，支持空格；禁止 `eval` 和根据用户输入拼接可执行 shell 片段。
3. `--dry-run` 不创建目录、不写文件、不执行 `git init`、不安装依赖。
4. 非 `--force` 情况下不覆盖已存在文件；输出每个跳过或覆盖决定。
5. 模板复制后保留 UTF-8；文本替换只能处理项目名、年份、owner 等固定占位符。
6. 执行前明确检查 `git`；缺失时给出安装建议，但不擅自执行 `apt install`。
7. `docs/`、`temp/`、根目录 `AGENTS.md`、`CLAUDE.md` 仍生成在项目中，但必须被新项目 `.gitignore` 忽略。

## Release 包格式

release 包以源码目录为根，不包含 `.git/`、`temp/`、`docs/`、`dist/`、本机配置或测试残留：

```text
awz-workflow-v0.2.0/
├─ VERSION
├─ CHANGELOG.md
├─ LICENSE
├─ README.md
├─ scripts/
│  ├─ init-project.ps1
│  ├─ init-project.sh
│  ├─ package-release.ps1
│  └─ package-release.sh
└─ templates/
   └─ project/
```

打包前检查：

1. 工作区没有未提交的预期发布改动。
2. Windows `-DryRun` 和真实 smoke 都通过。
3. Linux `--dry-run` 和真实 smoke 都通过。
4. 解压后的临时目录中运行两端 smoke，不从源仓库借模板。
5. 包内不含密钥、`.env`、本地 Agent 状态、`docs/`、`temp/` 或 `.git/`。
6. 记录版本、commit SHA、打包时间和验证命令。

通过后创建 Git tag，例如：

```text
v0.2.0
```

tag 表示可复现的发布点，不用一个巨型 commit 代替版本边界。

## VPS 使用路径

`v0.2` release 可用后，VPS 的推荐安装位置是用户目录下的工具目录，而不是随手解到某个业务项目中：

```bash
mkdir -p "$HOME/tools/awz-workflow"
tar -xzf awz-workflow-v0.2.0.tar.gz \
  -C "$HOME/tools/awz-workflow" \
  --strip-components=1
```

初始化项目时：

```bash
bash "$HOME/tools/awz-workflow/scripts/init-project.sh" \
  --target "$HOME/projects/example-service" \
  --name "Example Service" \
  --dry-run

bash "$HOME/tools/awz-workflow/scripts/init-project.sh" \
  --target "$HOME/projects/example-service" \
  --name "Example Service"
```

初始化后先检查：

```bash
cd "$HOME/projects/example-service"
git status --short
git status --ignored --short AGENTS.md CLAUDE.md docs temp
```

预期：`.env.example`、`.gitignore`、`README.md`、`LICENSE` 可以被 git 看到；`AGENTS.md`、`CLAUDE.md`、`docs/`、`temp/` 显示为 ignored，不参与提交。

业务项目是否添加 `pyproject.toml`、`package.json`、Docker、CI、部署配置，仍由项目技术栈与规模决定，不由初始化器代替决策。

## 远端仓库时机

现在不必为了“看起来正式”抢先建云端仓库。建议在以下条件同时满足后再建：

1. `init-project.sh` 已实现；
2. Windows 与 Linux 的 dry-run/真实 smoke 已跑通；
3. `VERSION`、`CHANGELOG.md`、打包脚本与 release 包已准备好；
4. 确认仓库公开或私有，以及是否使用 GitHub Releases。

在这之前，要马上给一台 VPS 使用时，可以从本地打出 `.tar.gz`，通过 `scp` 上传，不依赖远端仓库：

```bash
scp awz-workflow-v0.2.0.tar.gz user@server:/tmp/
```

远端仓库建立后，推荐把 tag 对应的 `.tar.gz` 附到 GitHub Release；VPS 只下载固定版本包，不直接运行 `main` 上的漂移脚本。

## 验证与回退

首次在 VPS 使用时，先在一个空的 `temp/smoke-*` 目标运行 `--dry-run` 和真实初始化，再初始化业务目录。

如果 release 脚本有问题：

1. 不覆盖已有业务项目中的本地 `AGENTS.md`、`CLAUDE.md`、`docs/`、`temp/`；
2. 保留失败的 release 包与命令输出到项目 `temp/logs/`；
3. 回退到上一个 tag 对应的完整 `.tar.gz`；
4. 修复后重新打包、验证，再创建新的 patch tag，不改写已发布 tag。

## 实施顺序

1. 增加 `VERSION`、`CHANGELOG.md` 和 `dist/` 忽略规则。
2. 实现并在 Ubuntu 环境验证 `init-project.sh`。
3. 为两个平台实现 release 打包，并做解压后隔离 smoke。
4. 以 `v0.2.0` 打第一个可用 release 包。
5. 再创建远端仓库、推送 `main` 和 tag，并按需发布 GitHub Release。

在第 2 步以前，AWZ Workflow 的可执行初始化范围仍是 Windows PowerShell。

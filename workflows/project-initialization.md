# 项目初始化工作流

用于新项目启动，或把已有项目整理到 AWZ Workflow 基线。

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
- 是否会执行 `git init -b main`；
- 哪些配置因为项目规模或技术栈不足而故意不生成。

`DryRun` 禁止：

- 创建目录；
- 写入文件；
- 初始化 git；
- 安装依赖；
- 修改用户环境。

`DryRun` 不是测试。它只是变更预演。真实验证仍要用 smoke/test/check。

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

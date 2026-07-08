# AGENTS.md

本项目遵循 AWZ Workflow。

## 核心规则

- 先读相关代码，再编辑。
- 改动保持小步、可 review。
- 不碰无关 dirty files。
- 能跑真实验证就跑真实验证。
- 如果无法验证，要说明原因。
- 不打印、不提交、不暴露 secrets。

## 本地路径

永远不要提交：

- `.codex/`
- `.claude/`
- `.vscode/`
- `AGENTS.md`
- `CLAUDE.md`
- `.env`
- `.env.*`
- `docs/`
- `temp/`

应该提交：

- `.env.example`

注意：`AGENTS.md` 和 `CLAUDE.md` 是本地 Agent 指令文件，初始化会生成，但默认不进 git。

## Agent 交流区

- 默认使用 ignored `docs/agent-room/` 作为 Agent 共享交流区。
- `status.md` 记录当前阶段、owner、阻塞项和下一步。
- `handoffs/` 存放跨 Agent 交接。
- `reviews/` 存放 P0/P1/P2/P3 checklist。
- 重要结论要沉淀到可提交文件、issue/PR 或正式文档，不要只留在 ignored `docs/`。

## 工具默认值

- Python：优先 `uv`；涉及部署时兼容 `venv`。
- Node/frontend：优先 `pnpm`；涉及部署时兼容 `npm`。
- 小项目不默认生成 `pyproject.toml` 或 `package.json`。
- 小项目默认不需要 Docker。
- Docker、CI、部署流在项目规模需要时再加。

## Git

- 默认分支：`main`。
- 使用环境里配置好的 git 用户名和邮箱。
- 禁止 AI attribution。
- 中大型阶段或多 Agent 协作用短生命周期 topic branch，完成后合并回 `main`。
- commit 按 logical change 切分，不要过碎，也不要把无关主题塞成一个大 commit。
- commit 格式：

```text
type: 中文一句话概括

1. **关键词**：具体改动点
```

## 架构

- 不要把整个项目塞进一个巨型文件。
- 不要拆成没有意义的小文件。
- 复杂度上来后按责任拆分。
- 大文件或高复杂度例外必须解释。

## 前端

- 避免通用 AI 味 UI。
- 先建立基础 UI 样式，再搭页面。
- 统一 buttons、inputs、modals、toasts、scrollbars、typography、focus states。
- 能用真实浏览器时优先真实浏览器预览。

## 必须停下等用户的情况

- CAPTCHA/MFA/password；
- destructive 文件或数据库操作；
- secret rotation；
- 大范围架构重写；
- 新增 heavyweight production dependency。

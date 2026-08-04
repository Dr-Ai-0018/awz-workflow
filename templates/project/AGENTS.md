# AGENTS.md

本项目遵循 AWZ Workflow。

## 核心规则

- 先读相关代码，再编辑。
- 改动保持小步、可 review。
- 不碰无关 dirty files。
- 能跑真实验证就跑真实验证。
- 如果无法验证，要说明原因。
- 不打印、不提交、不暴露 secrets。

## 阅读顺序

- 先读本文件，再读 `README.md` 和 `docs/agent-room/status.md`。
- 新 Agent 进入项目时，读 `docs/agent-room/onboarding.md`。
- 按任务类型读取 `docs/agent-room/guides/` 下的对应指南。
- 多 Agent 协作时，读 `docs/agent-room/guides/collaboration.md`、`docs/agent-room/handoffs/` 和当前 owner 表。
- 共享 room 时间线时，读 `docs/agent-room/guides/room-ledger.md`，并使用 `docs/agent-room/room-ledger.py` 追加。
- review/debug/hardening 时，读 `docs/agent-room/guides/review.md`，并读或创建 `docs/agent-room/reviews/` 下的 checklist。
- 不要机械读取所有文件；按任务类型扩展上下文。

## 参考项目

- 项目 reference mapping 位于可提交的 `.awz/references.json`。
- 如果存在 `docs/agent-room/reference-context.md`，只在当前任务命中其用途时读取对应 reference。
- 先读 reference 的 `readFirst`，不要递归扫描整个机器级参考库。
- reference 默认是 `source-only` 外部代码；不要自动安装、构建、执行或复制非平凡代码。
- reference 只能提供思路和证据，最终实现必须遵循当前项目 contract 与 license。

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
- `room.ndjson` 是 append-only 时间线；禁止用 `apply_patch`、通用分隔符或署名定位追加，历史修正只能追加 `amend`。
- 重要结论要沉淀到可提交文件、issue/PR 或正式文档，不要只留在 ignored `docs/`。

## 工具默认值

- Python：优先 `uv`；涉及部署时兼容 `venv`。
- Node/frontend：优先 `pnpm`；涉及部署时兼容 `npm`。
- 小项目不默认生成 `pyproject.toml` 或 `package.json`。
- 小项目默认不需要 Docker。
- Docker、CI、部署流在项目规模需要时再加。

## 文件搜索

- 跨目录、跨盘、面向未知位置的文件定位，优先走本机 Everything HTTP API：`http://localhost:8080/?search=<QUERY>&json=1&count=<N>`。
- 不要用 `Get-ChildItem -Recurse` / `find` 去扫全盘或大目录树，数量级更慢，且会漏掉权限受限的路径。
- Everything 探测不到（服务未开、非 Windows/NTFS 环境）再回退到语言原生工具。
- 常用查询语法、探测和回退顺序见 `docs/agent-room/guides/verification.md`。

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

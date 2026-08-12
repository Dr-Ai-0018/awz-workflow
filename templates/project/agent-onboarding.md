# Agent Onboarding

本文件是任务路由图，位于 ignored `docs/agent-room/`。首次进入先按根目录 `AGENTS.md` 的短链读取项目事实与当前状态，再从这里按任务类型加载细则。

## 基础阅读链

1. `AGENTS.md`：始终生效的硬规则和信息边界。
2. `README.md`：公开项目目标、用法和已验证命令。
3. `docs/references/README.md`：稳定背景、目标、非目标、术语、约束和资料来源。
4. `docs/agent-room/status.md`：当前阶段、owner、dirty state、阻塞项和下一步。

## 按任务继续读

仓库整理、工具选择或初始化接入：

- `docs/README.md`
- `docs/agent-room/guides/repository-hygiene.md`
- `docs/agent-room/guides/verification.md`

多 Agent 协作：

- `docs/agent-room/guides/collaboration.md`
- `docs/agent-room/guides/room-ledger.md`
- `docs/agent-room/status.md`
- `docs/agent-room/handoffs/`

review、debug、hardening：

- `docs/agent-room/guides/review.md`
- `docs/agent-room/guides/blockers-and-safety.md`
- `docs/agent-room/reviews/review-checklist.template.md`

后端、架构、重构：

- `docs/agent-room/guides/code-architecture.md`
- `docs/agent-room/guides/verification.md`

前端、UI、浏览器预览：

- `docs/agent-room/guides/frontend.md`
- `docs/agent-room/guides/verification.md`

外部资料或第三方源码借鉴：

- `docs/references/README.md`
- `.awz/references.json`
- `docs/references/reference-context.md`（由 Reference Library 生成且存在时）
- 只按用途和 `readFirst` 定向读取，不扫描整个机器级参考库

Git、分支、commit、版本：

- `docs/agent-room/guides/git-workflow.md`

大阶段或发布：

- `docs/agent-room/guides/git-workflow.md`
- `docs/agent-room/guides/verification.md`
- `docs/plans/release-checklist.template.md`

方案选择或架构取舍：

- `docs/references/README.md`
- `docs/agent-room/guides/code-architecture.md`
- `docs/agent-room/decisions/decision-record.template.md`

## 回写位置

- 稳定项目事实与资料来源：更新 `docs/references/README.md`；适合共享的内容再提升到公开文档。
- 当前阶段、owner、阻塞项：更新 `docs/agent-room/status.md`。
- 跨 Agent 交接：写入 `docs/agent-room/handoffs/`。
- 多步骤 review：维护 `docs/agent-room/reviews/` checklist。
- 普通 room 时间线：只能使用 `room-ledger.py append`，不要为每轮聊天新建文件。

不要机械读取所有文件，也不要把背景事实复制到 status、handoff 和多个 guide 中形成互相漂移的副本。

# Agent Onboarding

本文件引导新进入项目的 AI Agent 了解本项目规则。它位于 ignored `docs/agent-room/`，默认不进 git。

## 先读这些

1. `AGENTS.md`：本地 Agent 硬规则。
2. `CLAUDE.md`：Claude Code 入口，通常导入 `AGENTS.md`。
3. `README.md`：项目目标和公开运行方式。
4. `docs/agent-room/status.md`：当前阶段、owner、阻塞项和下一步。

## 按任务继续读

初始化、仓库整理、工具选择：

- `docs/README.md`
- `temp/README.md`
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

Git、分支、commit、版本：

- `docs/agent-room/guides/git-workflow.md`

大阶段或发布：

- `docs/agent-room/guides/git-workflow.md`
- `docs/agent-room/guides/verification.md`
- `docs/plans/release-checklist.template.md`

方案选择或架构取舍：

- `docs/agent-room/guides/code-architecture.md`
- `docs/agent-room/decisions/decision-record.template.md`

## 回写要求

较大任务开始前，在 `docs/agent-room/status.md` 或 handoff 中写清：

```text
已读：
任务理解：
范围：
Owner：
验证计划：
未确认问题：
```

小任务可以不写完整回执，但最终交接仍要说明关键上下文和验证结果。

## 注意

- 不要机械读取所有文件来制造上下文噪音。
- 不要把重要结论只留在 ignored `docs/`；需要长期保存的内容要沉淀到可提交文件、issue/PR 或正式文档。

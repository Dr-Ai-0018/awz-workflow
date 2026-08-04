# Agent Onboarding 工作流

用于引导新进入项目的 AI Agent 快速理解 AWZ Workflow，而不是把所有规则一次性塞进上下文。

## 核心原则

- `AGENTS.md` 是入口，不是百科全书。
- 先读短规则，再按任务类型读取相关细则。
- 不需要每次都读完所有文档；高风险、大范围、多 Agent 协作时再扩大阅读范围。
- 读完后要在 `docs/agent-room/status.md` 或 handoff 中写回自己的理解、范围和验证计划。

## 默认阅读顺序

1. `AGENTS.md`：读取本项目硬规则、仓库边界、Git 禁区和工具默认值。
2. `CLAUDE.md`：如果当前 Agent 是 Claude Code，确认是否导入了 `AGENTS.md` 和额外限制。
3. `README.md`：理解项目目标、运行方式、公开约定。
4. `docs/agent-room/status.md`：理解当前阶段、owner、阻塞项和下一步。
5. 根据任务类型读取补充材料。

## 任务类型到文档映射

初始化或整理项目：

- `workflows/project-initialization.md`
- `workflows/verification-baseline.md`
- `style/git-style.md`

Ubuntu/VPS 初始化、release 包或远端发布：

- `workflows/release-and-vps.md`
- `workflows/project-initialization.md`
- `workflows/verification-baseline.md`
- `style/git-style.md`

多 Agent 协作：

- `workflows/dual-agent-development.md`
- `workflows/room-ledger.md`
- `docs/agent-room/status.md`
- `docs/agent-room/handoffs/`

review、audit、debug、hardening：

- `workflows/review-and-fix.md`
- `workflows/verification-baseline.md`
- `docs/agent-room/reviews/`

代码架构、拆分、重构：

- `style/code-architecture-baseline.md`
- `style/git-style.md`

前端、UI、浏览器验证：

- `style/frontend-baseline.md`
- `workflows/verification-baseline.md`

第三方参考源码、方案借鉴、AI context：

- `.awz/references.json`
- `docs/agent-room/reference-context.md`（存在时）
- `workflows/reference-library.md`

需求、偏好、边界规则不确定：

- `requirements/awz-workflow-v0.1.md`

## 读完后的回写

较大任务开始前，在 `docs/agent-room/status.md` 或 handoff 中写清：

```text
已读：
任务理解：
范围：
Owner：
验证计划：
未确认问题：
```

小任务可以不写完整回执，但最终回复仍要说明读了哪些关键上下文、跑了哪些验证。

## 防止过载

不要在每次小改动前机械读取所有文件。建议：

- 小任务：`AGENTS.md` + 相关代码；
- 中等任务：再读对应 `workflows/` 或 `style/`；
- 大任务：读需求沉淀、工作流、风格基线，并维护 `docs/agent-room/status.md`。

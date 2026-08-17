# Agent Onboarding 工作流

用于引导新进入项目的 AI Agent 快速理解 AWZ Workflow，而不是把所有规则一次性塞进上下文。

## 核心原则

- `AGENTS.md` 是入口，不是百科全书。
- 先读短规则，再按任务类型读取相关细则。
- 不需要每次都读完所有文档；高风险、大范围、多 Agent 协作时再扩大阅读范围。
- 较大任务开始、owner/阶段变化或需要交接时，再在 `docs/agent-room/status.md` 或 handoff 写回理解、范围和验证计划；小任务不机械制造回执。

## 默认阅读顺序

1. `AGENTS.md`：读取本项目硬规则、仓库边界、Git 禁区和工具默认值。
2. `CLAUDE.md`：如果当前 Agent 是 Claude Code，确认是否导入了 `AGENTS.md` 和额外限制。
3. `README.md`：理解公开项目目标、运行方式和共享约定。
4. `docs/agent-room/status.md`：理解当前阶段、owner、dirty state、阻塞项、下一步和恢复指针。
5. 只读取 status 或当前任务明确指向的 references、decision、handoff、review、plan 和补充规则。

## 项目构建启动顺序

首次构建、已有项目接入或跨多步骤任务，除非用户明确要求直接处理一个孤立小事，默认执行：

1. **探测**：核对真实目录/代码、Git/dirty state、OS 与 shell、编码/行尾、实际 runtime/package manager、启动和验证入口。
2. **必要沉淀**：稳定环境与项目事实写入 `docs/references/README.md`；当前阶段、owner、范围和阻塞写入 status。已有且仍有效的事实不重复制造副本。
3. **锁定主线**：建立一个由 status 指向的主 checklist；普通计划放 `docs/plans/`，专项 review 可放 `docs/agent-room/reviews/`。副清单只服务确实独立的切片，并反向链接主清单。
4. **实现与验证**：按主 checklist 小步推进、验证、review 和收口。

低风险单步任务、纯回答或已有可信环境基线的重复操作，可以省略无意义的探测与写回。环境、编码与文本写入细则按需读取 `workflows/verification-baseline.md`。

## 主线与插入请求

- 用户当前明确目标优先；status 和主 checklist 只保存连续性。用户明确取消、替换或重定义目标时，及时迁移主线，不能用旧计划对抗新决定。
- 其余新消息视为补充或插入请求：可以先回应，随后回到未完成主线；若与主线冲突、显著扩权或改变交付物，先说明影响并确认。

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

- `workflows/agent-collaboration.md`
- `workflows/room-ledger.md`
- `docs/agent-room/status.md`
- `docs/agent-room/handoffs/`

review、audit、debug、hardening：

- `workflows/review-and-fix.md`
- 改代码或验证行为时，再读 `workflows/verification-baseline.md`
- 跨多轮、包含修复或需要持续追踪时，再维护 `docs/agent-room/reviews/`

代码架构、拆分、重构：

- `style/code-architecture-baseline.md`
- `style/git-style.md`

前端、UI、浏览器验证：

- `style/frontend-baseline.md`
- 由其中的任务路由按需读取 `style/frontend/` 专题，不默认全量加载
- `workflows/verification-baseline.md`

第三方参考源码、方案借鉴、AI context：

- `docs/references/README.md`
- `.awz/references.json`
- `docs/references/reference-context.md`（存在时）
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

## 阶段收口与恢复

Checkpoint 是人为选择的语义边界，不是 token 阈值，也不替代 Harness 自己的 compaction。出现以下任一情况时做一次阶段收口：

- 一个 feature 完成，或 root cause 已确认；
- 关键架构/方案决策落定，或一轮实验结束；
- 准备换 Agent、换会话、暂停较大任务或进入下一阶段。

收口时先核对真实代码、配置、Git 和验证结果，再更新 `docs/agent-room/status.md`：当前目标与阶段、已完成、已验证事实、当前有效状态、branch/commit/dirty state、未解决项、下一步 1–3 项，以及恢复工作必须先读的入口。

其他材料只在职责命中时更新：有长期取舍才写 decision/ADR；发生责任交接或跨会话继续才写 handoff；需要追溯的协作事件才进 ledger；稳定背景、约束或资料来源变化时才更新 references。低风险小改若不改变阶段、owner 或长期事实，不必制造 checkpoint 文档。

新 Agent 或新会话恢复时，按 `AGENTS.md` → `README.md` → `docs/agent-room/status.md` → status 指向的 references/decision/handoff/review/plan → 当前任务 guide 读取。没有明确指针时，不为“补上下文”遍历旧聊天和历史草稿。

## 信息归属与单一来源

| 内容 | 应放位置 | 不应复制到 |
| --- | --- | --- |
| 始终生效的 Agent 硬边界 | `AGENTS.md` | 多个 guide |
| 公开目标、安装、运行、测试命令 | `README.md` 或正式文档 | status、handoff |
| 本地稳定背景、约束、术语、资料证据 | `docs/references/README.md` | status、notes |
| 当前阶段、owner、dirty state、阻塞项 | `docs/agent-room/status.md` | README、长期背景副本 |
| 特定任务的操作方法 | `docs/agent-room/guides/` | `AGENTS.md` 全量复制 |
| 当前主线、阶段计划与验收项 | status 指向的唯一主 checklist；普通计划用 `docs/plans/`，专项 review 可用 `docs/agent-room/reviews/` | room 普通聊天、多份平行主计划 |
| 方案取舍及原因 | decision/ADR | 代码注释长篇复述 |
| 可清理产物、截图、实验与日志 | `temp/` | docs 正文、git |

同一规则出现两次时，保留离执行位置最近且职责最稳定的一份，其余位置只留链接。规则已能通过 lint、test、schema 或脚本强制时，文档保留意图与入口，不复制实现细节。

## 防止过载

不要在每次小改动前机械读取所有文件。建议：

- 小任务：`AGENTS.md` + 相关代码；
- 中等任务：再读对应 `workflows/` 或 `style/`；
- 大任务：读需求沉淀、工作流、风格基线，并维护 status 指向的单一主 checklist。

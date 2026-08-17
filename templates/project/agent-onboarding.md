# Agent Onboarding

本文件是任务路由图，位于 ignored `docs/agent-room/`。首次进入先按根目录 `AGENTS.md` 的短链读取项目事实与当前状态，再从这里按任务类型加载细则。

## 基础阅读链

1. `AGENTS.md`：始终生效的硬规则和信息边界。
2. `README.md`：公开项目目标、用法和已验证命令。
3. `docs/agent-room/status.md`：当前阶段、owner、dirty state、阻塞项、下一步和恢复指针。
4. 只继续读取 status 或当前任务明确指向的 references、decision、handoff、review、plan 和 guide。

## 项目构建启动顺序

首次构建、已有项目接入或跨多步骤任务，除非用户明确要求直接处理一个孤立小事，默认按以下顺序：

1. **探测**：核对真实代码与目录、Git/dirty state、OS 与 shell、编码/行尾、实际 runtime/package manager、已有启动与验证入口。
2. **必要沉淀**：稳定且会影响后续执行的环境/项目事实写入 `docs/references/README.md`；当前阶段、owner、范围和阻塞写入 `status.md`。已存在且仍有效的事实不重复改写。
3. **锁定主线**：多步骤任务建立一个主 checklist，并把路径、当前主线和验收方式写入 status；普通计划放 `docs/plans/`，专项 review 可放 `docs/agent-room/reviews/`。副清单只服务独立切片，不能争夺主状态源。
4. **开始实现**：按 checklist 小步推进、验证和回写；不要在环境未明时先堆代码或用猜测补文档。

低风险单步任务、纯回答或已经具备可信环境基线的重复操作，可以跳过无意义的探测和文档写入。

## 主线与插入请求

- 用户当前明确目标优先；status 和主 checklist 只保存连续性。用户明确取消、替换或重定义目标时，及时迁移主线，不能用旧计划对抗新决定。
- 其余新消息视为补充或插入请求：可以先回应，随后回到未完成主线；若与主线冲突、显著扩权或改变交付物，先说明影响并确认。

## 按任务继续读

仓库整理、工具选择或初始化接入：

- `docs/README.md`
- `docs/agent-room/guides/repository-hygiene.md`
- 实际改动初始化器、生成器或验证行为时，再读 `docs/agent-room/guides/verification.md`

多 Agent 协作：

- `docs/agent-room/guides/collaboration.md`
- `docs/agent-room/guides/room-ledger.md`
- `docs/agent-room/status.md`
- `docs/agent-room/handoffs/`

review、debug、hardening：

- `docs/agent-room/guides/review.md`
- 只读、一次性 review 到此即可
- 涉及真实安全风险、权限、破坏性操作或阻塞时，再读 `docs/agent-room/guides/blockers-and-safety.md`
- 跨多轮、包含修复或需要持续追踪时，再使用 `docs/agent-room/reviews/review-checklist.template.md`

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

跨目录、跨盘或未知位置查找文件：

- `docs/agent-room/guides/file-search.md`

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
- 当前主线与主 checklist：status 只指向一个主 checklist；普通计划放 `docs/plans/`，专项 review 可放 `docs/agent-room/reviews/`，必要副清单反向链接主清单。
- 跨 Agent 交接：写入 `docs/agent-room/handoffs/`。
- 多步骤 review：维护 `docs/agent-room/reviews/` checklist。
- 普通 room 时间线：只能使用 `room-ledger.py append`，不要为每轮聊天新建文件。

不要机械读取所有文件，也不要把背景事实复制到 status、handoff 和多个 guide 中形成互相漂移的副本。

## 阶段收口与恢复

Checkpoint 按语义边界触发，不按 token 数触发，也不接管 Harness 的 compaction。feature 完成、root cause 确认、关键决策落定、实验结束、换 Agent/会话或切换阶段时：

1. 核对真实代码、配置、Git 和验证结果；
2. 更新 `status.md` 的阶段快照、已验证事实、有效状态、未解决项、下一步和恢复入口；
3. 只有职责命中时才更新 decision、handoff、ledger 或 references，不机械全写；
4. 新会话按 `AGENTS.md` → `README.md` → `status.md` → status 指向的 references/decision/handoff/review/plan → 当前任务 guide 恢复，不默认遍历旧聊天。

低风险小改若不改变阶段、owner 或长期事实，最终说明验证结果即可，不必制造 checkpoint 文档。

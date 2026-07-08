# 双核 Agent 开发工作流

本文件说明 Codex 和 Claude Code 在较大项目中如何协作。

## 共同交流区

每个项目默认使用 ignored `docs/agent-room/` 作为 Agent 交流区。

推荐结构：

```text
docs/agent-room/
├─ status.md
├─ handoffs/
├─ reviews/
├─ decisions/
└─ notes/
```

用途：

- `status.md`：当前阶段、owner、阻塞项、下一步；
- `handoffs/`：跨 Agent 交接；
- `reviews/`：review checklist 和发现的问题；
- `decisions/`：本地 ADR 草稿或方案对比；
- `notes/`：调研摘记、非正式讨论、待确认想法。

交流区允许 Agent 留下自己的判断、担忧和建议。它的目标是让协作更像真实团队，而不是让多个工具互相覆盖上下文。

边界：

- 交流区默认不进 git；
- 事实、验证和决策要写清楚；
- 闲聊可以轻量存在，但不能替代任务状态；
- 重要结论要及时沉淀到可提交文件、issue/PR 或正式 ADR。

## 默认分工

Codex 负责：

- 后端逻辑；
- API contract；
- 数据模型和持久化逻辑；
- 正确性敏感的 refactor；
- root-cause debug；
- 关键 blocker 的兜底处理。

Claude Code 负责：

- 前端设计和实现；
- 浏览器预览和视觉迭代；
- 工具调用和流程串联；
- 跨文档、浏览器、项目工具的探索；
- planning 和第二视角 review。

小任务可以由任意一个 Agent 单独完成。

## 协作模式

### Single-Agent Mode

适用场景：

- 任务很小；
- 不需要浏览器预览；
- 只影响一个代码区域；
- 验证方式明确。

输出要求：

- 简短变更总结；
- 运行过的命令；
- 如有剩余风险要说明。

### Paired-Agent Mode

适用场景：

- 同时涉及 backend 和 frontend；
- API 与 UI 需要对齐；
- 架构选择不确定；
- 需要另一个 Agent review。

推荐流程：

1. Codex 先定义 contract、后端行为和测试。
2. Claude 根据 contract 实现或预览前端行为。
3. Codex 验证后端正确性和集成假设。
4. Claude 验证真实浏览器里的 UX。
5. 最终 handoff 说明双方各自验证了什么。

### Reviewer Mode

适用场景：

- 改动风险较高；
- 测试薄弱；
- UI 质量主观性强；
- 大 refactor 触及共享行为。

Reviewer 重点看：

- bug；
- regression；
- missing tests；
- scope drift；
- unverified claims；
- 与 AWZ 前端规则冲突的 UX 细节。

## Handoff 格式

Agent 之间交接时用这个形状：

```text
目标：
阶段：
Owner：
范围：
已完成：
关键文件：
验证结果：
剩余风险：
需要对方确认：
下一步建议：
```

## 协调规则

- 不要让两个 Agent 同时编辑同一文件范围。
- 按文件或职责明确 owner。
- 如果一个 Agent 改了 contract，必须显式告诉另一个 Agent。
- 每个阶段开始时更新 `docs/agent-room/status.md`。
- 每次跨 Agent handoff 放到 `docs/agent-room/handoffs/`，文件名带日期和主题。
- 需要浏览器预览时，优先用 Claude/browser tooling，除非 Codex 的浏览器连接更可靠。
- 后端正确性是主要风险时，优先让 Codex 做最终 verifier。

## Owner 和文件占用

多 Agent 协作时，不做复杂锁系统，默认使用轻量 owner 表。

在 `docs/agent-room/status.md` 里维护：

```text
## Owner 表

| 范围 | Owner | 状态 | 备注 |
| --- | --- | --- | --- |
| backend/api | Codex | editing | contract 变更需通知 Claude |
| frontend/views | Claude | waiting | 等待 API contract |
```

状态建议：

- `editing`：正在改，其他 Agent 不要碰同范围；
- `waiting`：等待输入或依赖；
- `reviewing`：只读 review，不直接改 owner 范围；
- `done`：阶段完成，可以交接或合并。

规则：

- owner 按目录、模块、contract 或任务切，不按“整个项目”粗暴占用；
- 需要修改别人 owner 范围时，先写 handoff 或在状态板说明；
- 小任务可以不建表，但一旦两个 Agent 同时动手，就要有 owner 表；
- 不能把 owner 当永久领地，阶段结束要释放或更新状态。

## 阶段节奏

推荐把大任务拆成这些阶段：

1. `discover`：读代码、确认需求、列风险；
2. `design`：确定 contract、架构边界、验证方式；
3. `build`：实现最小闭环；
4. `verify`：测试、预览、review；
5. `stabilize`：修 bug、补文档、清理无关产物；
6. `merge`：整理 commit、合并回 `main`。

阶段不是官僚流程。小任务可以合并多个阶段；大任务必须让状态可追踪。

## 必须停下等用户的情况

- 需要输入密码、CAPTCHA、MFA 或进入私有会话；
- 需要轮换 secret；
- 涉及 destructive 数据库或文件系统操作；
- 大范围架构重写；
- 新增 heavyweight production dependency；
- 变更部署目标或费用敏感基础设施。

# Agent 协作工作流

本文件定义单 Agent 到多 Agent 团队的协作基线。AWZ 不限定 Codex、Claude Code、Grok、DeepSeek、Qwen、Kimi 或任何特定 model/harness；分工以实际能力、工具权限、任务风险和验证结果为准。

## 项目配置

初始化项目在 `docs/agent-room/guides/collaboration.md` 选择当前策略并填写参与者；`docs/agent-room/status.md` 维护当前 owner、状态、依赖和阻塞项。

配置原则：

- model 名称只是线索，不是能力证明；
- harness 的浏览器、终端、文件、connector、并发和审批能力都影响分工；
- 一个 Agent 可以覆盖多个角色，但每个切片只能有一个明确 owner；
- Agent 数量或能力变化时允许动态切换策略，先更新配置和 owner，再继续编辑。

## 协作策略

### 单 Agent

一个 Agent 负责理解、设计、实现、验证和交接。如果能调节 reasoning effort：明确检索、格式化和低风险小改用浅；普通实现与 review 用中；架构、高风险变更、复杂 root-cause 和不可逆决策用深。思考深度跟随风险，不按模型品牌固定。

### 双 Agent

按能力互补选择边界，常见形态是：

- 实现 + 独立 review；
- backend/contract + frontend/interaction；
- 调研/方案 + 实现/验证。

Codex + Claude Code 只是一个可选示例：在能力与工具状态匹配时，Codex 可偏复杂逻辑、backend/API、高风险 debug 和正确性验证；Claude Code 可偏工具串联、浏览器/UI、frontend 和第二视角。项目必须根据实际参与者重写分工，不能照抄品牌默认值。

### 三 Agent

选择一个闭环拓扑，不要把同一任务复制三份：

- lead + implementer + independent reviewer；
- backend + frontend + integration；
- research + build + verify。

明确谁收敛 contract、谁拥有实现、谁给出独立验收结论。

### 四个及以上 Agent

采用主次分明的团队拓扑：

- 一名 lead/coordinator 维护目标、contract、依赖和合并顺序；
- domain owners 按模块或职责切片；
- 至少一名 independent verifier 不参与被审改动；
- 设置合理并发上限，不让所有 Agent 通读全部材料或编辑同一范围。

## Owner 与动态切换

`status.md` 的 owner 表按目录、模块、contract 或任务划分，状态使用 `editing`、`waiting`、`reviewing`、`done`。owner 不是永久领地；需要越界时先交接，阶段完成后及时释放。

Agent 加入、退出、工具失效或阶段变化时：

1. 更新协作配置中的 Agent 数量、策略与切换原因；
2. 更新 status 的 owner、依赖和等待事项；
3. 写清已完成验证、未覆盖风险和下一接收方；
4. 不因换 Agent 重做已经有可靠证据的工作。

## 协作记录

- `status.md`：当前快照；
- `room.ndjson`：append-only 时间线，只能通过 `room-ledger.py` 写入；
- `handoffs/`：跨 Agent 交接；
- `reviews/`：问题清单和验证结果；
- `decisions/`：需要保留原因与权衡的方案选择。

重要结论要提升到代码、测试、README、正式文档、ADR、issue 或 PR，不能只留在 ignored `docs/`。

## 停止条件

遇到密码、CAPTCHA、MFA、secret rotation、破坏性数据操作、费用敏感基础设施、大范围架构重写或新增 heavyweight production dependency 时，按项目规则等待用户确认；增加 Agent 数量不能扩大已有授权范围。

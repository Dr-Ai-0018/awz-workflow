# Agent 协作配置

本文件由项目维护，用来选择当前协作策略。不要按模型品牌预设职责；先看实际参与的 Agent、model、harness、工具权限和已验证能力，再分配 owner。参与者变化时可以切换策略，但必须同步 `status.md`。

## 当前配置

- Agent 数量：`[待填写]`
- 当前策略：`[single / pair / triad / team]`
- 选择依据：`[任务风险、能力互补、可用工具、并发需求]`
- 切换条件：`[何时增减 Agent 或调整角色]`

以下模式只激活一项，并填写该项中的 `[]`。

## [ ] 单 Agent

- Agent / model / harness：`[]`
- 任务范围：`[全流程负责]`

单 Agent 默认完成理解、设计、实现、验证和交接，不因只有一个 Agent 就降低验收标准。如果环境支持调节思考深度，可按任务切换：检索、格式化和明确小改用浅；普通实现与 review 用中；架构、高风险变更、复杂 root-cause 和不可逆决策用深。以足够解决问题为准，不机械拉满。

## [ ] 双 Agent

- Agent A：`[]`；优势与 owner：`[]`
- Agent B：`[]`；优势与 owner：`[]`
- 协作形态：`[实现 + review / backend + frontend / 调研 + 落地 / 其他]`

按能力互补和任务边界分工，不按模型名称分工。示例：当组合确实是 Codex + Claude Code 时，可以让 Codex 偏复杂逻辑、backend/API、高风险 debug 与正确性验证；Claude Code 偏工具串联、浏览器/UI、frontend 和第二视角。能力证据与当前工具状态优先于这个示例。

## [ ] 三 Agent

- Agent A：`[]`；角色：`[]`
- Agent B：`[]`；角色：`[]`
- Agent C：`[]`；角色：`[]`
- 协作形态：`[主导 + 实现 + 独立 review / backend + frontend + integration / 调研 + 实现 + 验证 / 其他]`

三者必须形成互补闭环，不能只是把同一任务复制三遍。明确谁收敛方案、谁拥有实现范围、谁做独立验证。

## [ ] 四个及以上 Agent

- Lead / coordinator：`[]`
- Domain owners：`[]`
- Independent verifier：`[]`
- 并发上限与合并门槛：`[]`

采用主次分明的团队拓扑：一名 lead 维护目标、contract 和合并顺序；其余按模块或职责拥有切片；至少一名 verifier 不参与被审改动。不要让所有 Agent 通读全部材料或同时编辑同一范围。

## 动态切换

Agent 加入、退出、能力受限或任务阶段变化时：

1. 更新本文件的 Agent 数量和激活模式；
2. 在 `status.md` 更新 owner、状态、依赖和等待事项；
3. 释放旧 owner，必要时写 handoff；
4. 已完成验证不重复做，未覆盖风险明确转交。

`room.ndjson` 只能通过 `room-ledger.py` 追加；重要结论要提升到代码、README、正式文档、ADR、issue 或 PR。

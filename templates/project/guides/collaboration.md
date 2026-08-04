# Agent 协作指南

## 默认分工

Codex 默认负责：

- 复杂逻辑；
- 后端和 API；
- 高风险改动；
- root-cause debug；
- 容错率低的兜底场景。

Claude Code 默认负责：

- 工具调用和流程串联；
- 浏览器预览和 UI 反馈；
- 前端设计与开发；
- 大方向把控和第二视角。

小任务可以单 Agent 完成。大项目可以双 Agent 协作，但每个切片必须有清楚 owner。

## 交流区

`docs/agent-room/` 是本地 Agent 交流区，默认不进 git。

- `status.md`：当前阶段、owner、阻塞项、下一步；
- `room.ndjson`：受锁保护的 append-only 时间线，必须通过 `room-ledger.py` 写入；
- `handoffs/`：跨 Agent 交接；
- `reviews/`：P0/P1/P2/P3 checklist；
- `decisions/`：本地 ADR 草稿和方案对比；
- `notes/`：调研摘记和待确认想法。

Agent 可以在交流区留下判断、疑问和风险提示，但要服务项目进展，不写无意义表演文本。

## Owner 表

多 Agent 协作时，在 `docs/agent-room/status.md` 维护 owner 表：

```text
| 范围 | Owner | 状态 | 备注 |
| --- | --- | --- | --- |
| backend/api | Codex | editing | contract 变更需通知 Claude |
```

状态建议：

- `editing`：正在改，其他 Agent 不要碰同范围；
- `waiting`：等待输入或依赖；
- `reviewing`：只读 review，不直接改 owner 范围；
- `done`：阶段完成，可以交接或合并。

重要结论要沉淀到代码、README、公开文档、ADR、issue/PR 或正式记录，不要只留在 ignored `docs/`。

时间线记录不得使用重复的 `---`、署名或标题作为追加锚点。旧记录需要修正时，追加 `amend` 并引用原记录 ID，不能原地改写别人的记录。具体命令和校验规则见 `room-ledger.md`。

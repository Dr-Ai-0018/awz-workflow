# Room 追加日志指南

`docs/agent-room/status.md` 是当前状态快照；`docs/agent-room/room.ndjson` 是共享时间线。时间线不是普通 Markdown，不能用 `apply_patch` 或重复的 `---` 来追加。

## 写入规则

- 新记录只能通过 `docs/agent-room/room-ledger.py append` 写入；
- 工具会持锁分配递增序号、UTC 时间、唯一 ID 和 SHA-256 链，并在追加后确认记录位于 EOF；
- 旧记录不得移动、删除或原地修改；修正只能追加 `kind=amend --ref <原记录 ID>`；
- `verify` 失败时停止写入并报告，不得猜测位置或覆盖 ledger；
- `---` 只是视觉分隔，不能作为写入锚点。

## 常用命令

```text
python docs/agent-room/room-ledger.py append --writer codex --kind handoff --body-file temp/handoff.md
python docs/agent-room/room-ledger.py verify
python docs/agent-room/room-ledger.py tail --count 10
```

`chat.md` 或 `handoff.md` 等旧式单文件时间线迁移后冻结为历史，不要继续向中段或文件尾部手工追加。稳定结论应提升到正式文档、ADR、issue 或 PR。

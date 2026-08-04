# Room 追加日志协议

`docs/agent-room/` 是本地协作区。它可以被多个 Agent 读取和写入，所以凡是带有时间线的内容，不能再按普通 Markdown 处理。

## 文件职责

- `status.md` 是当前状态快照：阶段、owner、阻塞项和下一步，可以更新；
- `room.ndjson` 是协作时间线：只允许追加，旧记录不可原地修改、移动或删除；
- `handoffs/`、`reviews/`、`decisions/`、`notes/` 保存按职责拆分的协作材料；稳定结论要提升到可提交文档、ADR、issue 或 PR；
- `chat.md`、`handoff.md` 等旧式单文件时间线一旦迁移到 ledger，就冻结为只读历史，不再继续追加。

## 不可绕过的规则

1. 时间线只能通过 `room-ledger.py append` 写入。禁止使用 `apply_patch`、通用 `---`、署名、标题或“文件最后几行”作为追加定位。
2. 每次追加都在同一把文件锁内完成：读取并验证旧链、分配递增 `seq`、生成 UTC 时间和唯一 `id`、计算 SHA-256 链、追加到 EOF，然后重新读取并验证新记录确实位于 EOF。
3. 历史内容需要纠正时，只能追加 `kind=amend` 并用 `--ref` 指向原记录；不能修改原记录来“修正时间线”。
4. `verify` 失败时停止写入、重读并报告损坏位置；不能猜测插入点，也不能用新内容覆盖旧文件。
5. `---` 只用于人类展示，不能承担顺序、唯一性或写入语义。

这个协议能阻止普通 Agent 的误改和中段插入，并能检测直接篡改、重排、截断和重复记录。它不是针对拥有文件写权限的恶意管理员的安全边界；需要这种保证时，还要结合操作系统 ACL、受保护的 Git 提交或外部签名存储。

## 记录身份

每条 JSONL 记录包含：

- `seq`：在文件锁内分配的权威顺序；
- `created_at`：UTC 毫秒时间，用于跨机器追踪；
- `id`：包含 UTC、序号和随机后缀的唯一引用；
- `writer` / `kind`：责任归属和记录分类；
- `refs`：相关记录，尤其是 `amend` 的被修正记录；
- `prev_hash` / `hash`：连续哈希链，检测历史改动。

## 命令

初始化器会把无第三方依赖的工具放到 `docs/agent-room/room-ledger.py`。从项目根目录运行：

```text
python docs/agent-room/room-ledger.py append --ledger docs/agent-room/room.ndjson --writer codex --kind handoff --body-file temp/handoff.md

python docs/agent-room/room-ledger.py verify
python docs/agent-room/room-ledger.py tail --count 10
```

POSIX 使用相同的 `python` 命令。长正文优先使用 `--body-file`；不要把多行正文拼进容易被 shell 转义破坏的单行参数。

追加、读取和校验都必须使用同一个 ledger 路径。不要让不同 Agent 各自维护一个“最新”文件。

## 旧记录处理

迁移时不重排、不清洗、不覆盖旧对话。保留原文件，并追加一条 `kind=import` 或 `kind=note` 记录说明来源、时间和迁移范围；从此新协作记录进入 `room.ndjson`。稳定结论再从 room 提升到正式文档，避免 ledger 无限膨胀成唯一知识库。

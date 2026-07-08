# 本地 docs/ 结构

`docs/` 默认被 git 忽略。它是本地协作工作台，不是公开文档目录。

推荐结构：

```text
docs/
├─ agent-room/
│  ├─ status.md
│  ├─ handoffs/
│  ├─ reviews/
│  ├─ decisions/
│  └─ notes/
└─ plans/
```

使用规则：

- `agent-room/status.md` 记录当前阶段、owner、阻塞项和下一步；
- `agent-room/handoffs/` 放跨 Agent 交接；
- `agent-room/reviews/` 放 P0/P1/P2/P3 checklist；
- `agent-room/decisions/` 放本地 ADR 草稿和方案对比；
- `agent-room/notes/` 放调研摘记和待确认想法；
- `plans/` 放任务计划、版本计划和实现 checklist。

初始化脚本会在对应目录放入轻量模板：

- `agent-room/handoffs/handoff.template.md`
- `agent-room/reviews/review-checklist.template.md`
- `agent-room/decisions/decision-record.template.md`
- `plans/release-checklist.template.md`

重要结论不要只留在 ignored `docs/`。需要进入长期项目历史的内容，应沉淀到代码、README、公开文档、issue/PR 或正式 ADR。

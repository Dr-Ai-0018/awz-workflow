# 本地 docs/ 导航

`docs/` 默认被 git 忽略，是本地项目知识与协作工作台。进入后先按内容寿命选择位置，不要把所有东西都塞进 `agent-room/`。

```text
docs/
├─ references/
│  ├─ README.md                 # 稳定项目背景、约束和资料索引
│  └─ reference-context.md      # Reference Library 生成，可再生
├─ agent-room/
│  ├─ onboarding.md             # 任务到 guide 的路由
│  ├─ status.md                 # 当前阶段与 owner 快照
│  ├─ room.ndjson               # append-only 协作时间线
│  ├─ room-ledger.py            # 时间线唯一写入入口
│  ├─ guides/
│  ├─ handoffs/
│  ├─ reviews/
│  ├─ decisions/
│  └─ notes/
└─ plans/                       # 通用阶段计划与 checklist
```

## 放置规则

- “这个项目长期是什么、为什么这样、结论来自哪里”：`references/`。
- “现在谁在做什么、哪里卡住”：`agent-room/status.md`。
- “本轮任务怎么推进”：status 只指向一个主 checklist；普通计划放 `plans/`，专项 review 放 `agent-room/reviews/`，只有独立切片确实需要时才拆副清单。
- “Agent 之间需要追溯的消息”：通过 `room-ledger.py` 追加到 `room.ndjson`。
- “可清理的大文件或生成物”：放 `temp/`，只在这里留下索引。

## 持久化边界

`docs/` 是本地层。稳定结论若需要跨机器或跨成员共享，应提升到代码、README、正式文档、ADR、issue 或 PR。不要在 references、status、handoff 和 notes 中维护同一事实的多个副本。

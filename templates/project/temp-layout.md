# 本地 temp/ 结构

`temp/` 被 git 忽略。它用于任务级临时材料，不是无结构垃圾堆。

推荐结构：

```text
temp/
├─ scripts/
├─ output/
├─ assets/
├─ screenshots/
├─ experiments/
└─ logs/
```

使用规则：

- 按任务创建子目录；
- generated output 不进 git；
- 持久决策移到项目文件或本地 `docs/`；
- 过期临时文件及时清理。

如果临时材料会影响多个 Agent 的判断，优先把说明放到 `docs/agent-room/`，把大文件或生成产物留在 `temp/`。

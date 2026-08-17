# Review And Fix 工作流

用于用户要求 review、audit、hardening 或修复代码库时。

## Review 姿态

发现问题优先，按严重程度排序：

1. bug；
2. regression；
3. security/privacy risk；
4. missing tests；
5. 可能真实导致维护问题的架构/可读性问题。

除非用户明确要求 style review，否则纯风格偏好放在后面。

## 调查顺序

1. 读取相关文件和项目指令。
2. 查看 git status，避免覆盖用户改动。
3. 能复现就先复现或验证用户声称的问题。
4. 明确 root cause 和 blast radius。
5. 做最小安全修复。
6. 运行 targeted verification。
7. 如果改动影响共享行为，再扩大验证范围。

## Checklist 文档

一次性只读 review 可以直接报告发现。跨多轮、包含修复或需要持续追踪时，在目标项目 ignored `docs/` 下创建或更新本地 checklist。

推荐形状：

```text
# Debug / Review Checklist

## Scope

## Findings

### P0
- [ ] ...

### P1
- [ ] ...

### P2
- [ ] ...

### P3
- [ ] ...

## Fix Plan

## Acceptance Criteria

## Progress
- [ ] ...
```

注意：除非项目明确例外，`docs/` 默认是本地 ignored 工作区。

## 优先级定义

- `P0`：数据丢失、严重安全/隐私风险、主流程不可用、构建/启动完全失败。
- `P1`：明确 bug、重要 regression、用户可见错误、关键测试缺失。
- `P2`：维护性风险、边界处理不足、性能隐患、体验明显不顺。
- `P3`：轻量清理、命名、注释、低风险 polish。

每个 checklist item 推荐格式：

```text
- [ ] [P1] 文件或模块：问题描述
  - 修复计划：
  - 验证方式：
  - 当前状态：
```

修复完成后把 `[ ]` 改成 `[x]`，并补一句验证结果。不要只在最终回复里说完成，过程文档也要对齐。

模板可参考 `templates/project/review-checklist.template.md`。

## 修复边界

- 遵守用户给出的范围，例如 “backend only” 或 “不要动 frontend”。
- 不格式化无关文件。
- 不回滚用户改动。
- 有无关 dirty files 时保持不碰。
- 如果任务必须扩大范围，先说明原因。

## 验证证据

最终 handoff 说明：

- 改了什么；
- 改了哪些文件；
- 跑了哪些命令；
- 测试是否通过；
- 哪些东西没法验证；
- 剩余风险。

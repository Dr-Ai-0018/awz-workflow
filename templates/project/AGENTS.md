# AGENTS.md

本项目遵循 AWZ Workflow。本文件是 Agent 的唯一入口，只保留始终生效的硬规则；任务细则按需读取，不要一次性加载全部文档。

## 首次进入

1. 读 `README.md`，确认项目目标、公开用法和已验证命令。
2. 读 `docs/agent-room/status.md`，确认当前阶段、owner、dirty state、阻塞项、下一步和恢复指针。
3. 只读取 status 或当前任务指向的 references、decision、handoff、review、plan 和 guide；没有指针时不遍历历史材料。
4. 不熟悉项目或任务较大时，再读 `docs/agent-room/onboarding.md`，按任务类型加载细则。
5. 编辑前检查真实代码、`git status` 和现有验证入口，不从模板占位或旧 handoff 猜现状。

## 硬规则

- 先理解再编辑；改动小步、可 review，不碰无关 dirty files。
- 验证遵循风险与影响范围成比例、最小充分、focused-first；每次执行前说明它验证的具体风险。
- 同一代码树、同一验证命令和同一环境已有通过证据时不得重复；focused 通过后不得仅为“更安心”自动升级 full suite。
- full suite、E2E、UI test、benchmark 和长时间 build 只能由明确任务、项目 gate 或用户确认触发；达到验收条件后停止验证。
- 测试失败、相关代码变化或发现新风险才进入下一轮；环境失败只做有限诊断和 fallback，不在同一路径无限重试。
- 重要判断以当前代码、配置、命令输出和用户确认优先，不把旧记录当作现状。
- 项目首次构建、已有项目接入或跨多步骤任务，默认先探测真实环境与代码入口，再沉淀必要事实、建立主 checklist，最后实现；用户明确要求直接处理孤立小事时可以缩短流程。
- 多行文本写入前确认当前 OS、shell、编码和换行语义，优先使用结构化 edit/patch；通过 shell 写入后必须回读，不把 PowerShell、cmd、Bash 的转义规则混用。
- 较大任务始终维护一个当前主线和主 checklist；新消息除非明确改变目标，否则按插入请求处理，回应后回到未完成主线。
- 在 feature 完成、root cause 确认、关键决策落定、实验结束、换 Agent/会话或切换阶段时，按 onboarding 做语义边界收口；不按 token 数触发，也不机械填写无关文档。
- 能运行真实验证就运行；无法验证时说明未验证项、原因和风险。
- 不打印、提交或完整复述 secret、token、cookie、私有 URL 和真实 `.env`。
- 默认不提交 `.codex/`、`.claude/`、`.vscode/`、`AGENTS.md`、`CLAUDE.md`、`docs/`、`temp/`、`.env` 或 `.env.*`；`.env.example` 应保持可提交且只含示例值。
- CAPTCHA、MFA、password、secret rotation、破坏性数据操作、大范围架构重写、新增 heavyweight production dependency 时停下等待用户。
- 重要结论不能只留在 ignored 本地文档；需要长期共享时提升到代码、README、正式文档、ADR、issue 或 PR。

## 信息边界

- `README.md`：公开且持久的项目目标、安装、运行和验证入口。
- `docs/references/`：本地稳定项目背景、人工资料索引和生成的 Reference Library context，不记录每日任务进度，也不存放第三方 clone。
- `docs/agent-room/`：当前状态、owner、handoff、review、决策草稿和 append-only room ledger。
- `docs/plans/`：阶段计划与 checklist。
- `temp/`：可清理的任务产物、实验、日志和截图。
- `.awz/references.json`：可提交、机器无关的外部源码 reference 映射。

## Reference 使用

- 任务涉及稳定背景、资料或第三方源码时，先读 `docs/references/README.md`；存在 `docs/references/reference-context.md` 时，只按任务用途读取命中的 reference。
- 先读 reference 的 `readFirst`，不要递归扫描机器级参考库。
- reference 默认是 `source-only` 外部代码；不要自动安装、构建、执行或复制非平凡代码。
- reference 只提供思路和证据，最终实现必须遵循当前项目 contract 与 license。

## 协作与 Git

- 多 Agent 协作先读 status 的 owner 表；不要擅自编辑其他 Agent 的范围。
- `room.ndjson` 只能通过 `docs/agent-room/room-ledger.py append` 写入；历史修正只能追加 `amend`。
- 默认分支为 `main`；中大型阶段使用短生命周期 topic branch；commit 按 logical change 切分。
- 禁止 AI attribution，使用环境中已有的 git 用户名和邮箱。
- commit 格式：`type: 中文一句话概括`，body 使用 `1. **关键词**：具体改动点`。

## 任务细则

任务到 guide、review checklist、handoff、decision 和 release 文档的完整路由见 `docs/agent-room/onboarding.md`。

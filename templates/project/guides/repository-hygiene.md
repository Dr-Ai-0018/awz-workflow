# 仓库卫生指南

## 默认不提交

- `.codex/`
- `.claude/`
- `.vscode/`
- `AGENTS.md`
- `CLAUDE.md`
- `.env`
- `.env.*`
- `docs/`
- `temp/`

## 应该提交

- `.env.example`
- `.gitignore`
- `README.md`
- `LICENSE`
- 项目真正需要的源码、测试和公开文档。

`AGENTS.md` 和 `CLAUDE.md` 会生成在项目根目录，方便本地 Agent 读取，但默认不进 git。

## docs 和 temp

`docs/` 是本地 AI 协作工作台，用于计划、debug checklist、实现 checklist、调研记录、本地 review 报告和 handoff 草稿。

`temp/` 是任务级临时材料区，不要把所有东西丢到根目录。按任务使用：

- `temp/scripts/`
- `temp/output/`
- `temp/assets/`
- `temp/screenshots/`
- `temp/experiments/`
- `temp/logs/`

密钥和日志默认打码，不打印、不提交、不完整复述 token、cookie、API key、refresh token、私有唯一 ID。

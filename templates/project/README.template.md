# {{PROJECT_NAME}}

本项目使用 AWZ Workflow 初始化。可选参考项目通过 `.awz/references.json` 声明；该文件不保存本机绝对路径，初始化过程不会联网或自动 clone。

## 项目简介

说明这个项目做什么、给谁用、解决什么问题。

## 快速开始

当前基线尚未假定技术栈。确定项目实际使用 Python、Node 或其他工具链后，再在这里写入已经验证过的安装、启动和测试命令。

- Python 本地开发优先 `uv`；涉及部署时兼容 `venv`。
- Node/frontend 本地开发优先 `pnpm`；涉及部署时兼容 `npm`。
- 不要因为这份模板存在，就生成不需要的 `pyproject.toml`、`package.json` 或依赖文件。

## 常用命令

在这里补充已经验证过的项目命令。

```powershell
# lint

# test

# dev server

# build
```

## 仓库说明

- 根目录 `AGENTS.md` 和 `CLAUDE.md` 被 git 忽略，用来给本地 AI Agent 读取。
- 本地 `docs/` 被 git 忽略，用来写计划、debug、AI 协作记录。
- 本地 `docs/agent-room/` 是 Agent 交流区，用来放状态板、handoff、review checklist 和决策草稿。
- 本地 `temp/` 被 git 忽略，用来放结构化临时产物。
- `.env` 被忽略；`.env.example` 进 git，但只能放示例值。
- AI 工具必须遵循 `AGENTS.md`。

## License

默认 MIT，除非本项目明确选择其他协议。

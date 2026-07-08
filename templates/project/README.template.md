# {{PROJECT_NAME}}

## 项目简介

说明这个项目做什么、给谁用、解决什么问题。

## 快速开始

```powershell
# Python 项目本地优先 uv
uv sync
uv run pytest

# 前端项目本地优先 pnpm
pnpm install
pnpm test
```

如果没有 `uv` 或 `pnpm`，使用下面的部署兼容 fallback。

## Fallback Setup

Python：

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
pytest
```

Node：

```powershell
npm install
npm test
```

## 常用命令

在这里补充项目自己的命令。

```powershell
# lint

# test

# dev server

# build
```

## 仓库说明

- 本地 `docs/` 被 git 忽略，用来写计划、debug、AI 协作记录。
- 本地 `docs/agent-room/` 是 Agent 交流区，用来放状态板、handoff、review checklist 和决策草稿。
- 本地 `temp/` 被 git 忽略，用来放结构化临时产物。
- `.env` 被忽略；`.env.example` 进 git，但只能放示例值。
- AI 工具必须遵循 `AGENTS.md`。

## License

默认 MIT，除非本项目明确选择其他协议。

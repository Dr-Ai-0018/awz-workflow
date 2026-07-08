# AGENTS.md

本仓库定义 AWZ Workflow，也就是程林个人开发工作流的可复用基线。

这份文件给 Codex 和其他 AI coding agents 读取。它必须短、硬、可执行。详细理由放到 `requirements/`、`workflows/`、`style/`。

## 默认语言

- 面向用户的说明、总结、交接默认使用中文。
- 工具名、命令、文件名、配置键、commit type 等关键词保留英文，以保证语义准确。
- 不为了“专业感”把中文文档硬写成英文。
- 语义准确性优先，其次是中文表达、易读性和专业性。

## 仓库定位

本仓库是 AWZ Workflow 的源头。

- `AGENTS.md`：跨 Agent 的共同指导入口。
- `CLAUDE.md`：给 Claude Code 使用，导入 `AGENTS.md`。
- `requirements/`：保存程林的需求、偏好和边界规则。
- `workflows/`：保存具体工作流。
- `style/`：保存代码架构、前端、git 等风格基线。
- `templates/project/`：保存新项目初始化模板。

## Agent 交流区

- 新项目默认使用 ignored `docs/agent-room/` 作为 Agent 共享交流区。
- 交流区用于状态板、handoff、review checklist、阶段计划、决策草稿和必要的轻量讨论。
- Agent 可以在交流区留下自己的判断、疑问和风险提示，但要服务于项目进展，不写无意义表演文本。
- 重要结论要沉淀到代码、README、公开文档、ADR 或 issue/PR；不要只留在 ignored `docs/`。

## 编辑规则

- 手工编辑文件时使用 `apply_patch`。
- 改动范围要贴合任务，不做无关重构。
- 除非程林明确改变规则，不要把 `docs/` 或 `temp/` 做成需要提交的目录。
- 不提交生成产物、截图缓存、本地工具状态、密钥、日志噪音。
- 如果某条规则越来越长，把解释移到 `requirements/`、`workflows/` 或 `style/`，保持 `AGENTS.md` 轻量。

## Git 规则

- commit 禁止添加 AI attribution。
- 不使用 AI 工具的 `Co-authored-by`。
- 使用当前环境配置好的 git 用户名和邮箱。
- commit message 格式：

```text
type: 中文一句话概括

1. **关键词**：具体改动点
2. **关键词**：具体改动点
```

常用 `type`：`init`、`docs`、`style`、`feat`、`fix`、`refactor`、`test`、`chore`。

## 工作原则

- 先读相关上下文，再动手改。
- 任务模糊或风险较高时，先说明范围和验证方式。
- 改动要小步、可 review；一个阶段可以有多个合理 commit，但不要把不相关文件一次性交成一团。
- 能跑真实检查就跑真实检查。
- 没法验证时，要说清楚为什么。
- DNS、网络、权限、sandbox 等问题阻塞关键工作时，先按规则申请重试；仍失败再换安全路径，不要原地打转。

## 默认技术取向

- 使用现代主流工具和框架。
- Python 本地开发优先 `uv`；涉及部署时要兼容 `venv`。
- 前端包管理优先 `pnpm`；涉及部署时要兼容 `npm`。
- Python API 默认倾向 FastAPI 这类现代 typed framework，除非项目已有明确选择。
- 小项目不默认生成 `pyproject.toml`、`package.json`、Docker、CI 或部署配置；确实用到对应技术栈和规模时再加。
- 小项目保持简单；Docker、GitHub Actions、Cloudflare Pages 等在规模需要时再引入。
- 默认开源协议为 MIT，除非项目明确需要其他宽松协议。

## 架构基线

- 不要把整个应用塞进一个大文件。
- 也不要拆成一堆没有稳定职责的小文件。
- 按责任拆分：接口/路由层、业务/use-case 层、domain/model 层、infrastructure/data access 层、config、tests。
- 大文件和长函数允许存在，但要说明原因、风险和未来拆分点。
- 命名优先遵循语言生态，不自造方言。

详见 `style/code-architecture-baseline.md`。

## 前端基线

- 避免 AI 味 UI：嵌套卡片、随机 left-border、圆角堆叠、间距不齐、原生控件裸奔、乱滚动。
- 先建立基础 UI 语言：字体、按钮、输入框、modal、toast、focus、scrollbar、布局节奏。
- 有浏览器工具时，用真实浏览器预览。
- 遇到登录、密码、MFA、验证码、人机验证时停下来等用户操作。

详见 `style/frontend-baseline.md`。

## 密钥处理

- 不打印、不提交、不完整复述 token、cookie、API key、refresh token、私有唯一 ID。
- `.env` 和 `.env.*` 只留本地。
- `.env.example` 只能放假值或示例值。
- 日志和报告默认打码。

## Codex / Claude 分工

- Codex 默认负责复杂逻辑、后端、API、高风险改动、兜底和 debug。
- Claude Code 默认负责工具调用、浏览器预览、前端设计/实现、大方向把控和二次视角。
- 大项目可以双核协作，但每个切片必须有清楚 owner。

详见 `workflows/dual-agent-development.md`。

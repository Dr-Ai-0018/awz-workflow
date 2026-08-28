# AWZ Workflow

AWZ Workflow 是程林自己的个人开发工作流基线，用来把长期和 AI Agent 协作时反复强调的偏好、边界、工具约定和工程习惯固化下来。

它不是“大厂制度大全”，也不是为了显得专业而堆流程。它的目标很朴素：

- 新项目启动时，不再每次重新训 AI；
- 不同 model 与 harness 可以按数量、能力和任务风险动态协作；
- 多个 Agent 有本地交流区，可以对齐状态、handoff、review 和决策；
- 在语义阶段边界留下可恢复快照，不依赖某个 Harness 的 token 或 compaction 实现；
- 仓库默认干净，不把密钥、本地文档、临时产物塞进 git；
- 代码默认现代、可测、可拆、能维护；
- 前端不再长出那种一眼 AI 味的圆角卡片拼盘。

## 核心想法

AWZ Workflow 把开发过程看成一个轻量但有纪律的循环：

1. 先理解项目和任务边界；
2. 探测真实开发环境与已有入口，只沉淀会影响后续执行的必要事实；
3. 较大任务建立一个主 checklist，再决定 Agent、工具和分工；
4. 沿主线小步实现，不让临时插入请求无声替换总目标；
5. 用真实命令、真实浏览器、真实测试给出证据；
6. 在 feature、决策、实验或责任边界收口当前事实；
7. 交接时说清楚做了什么、验证了什么、哪里还不确定。

规则可以例外，但例外必须说清楚原因、风险和后续处理。

## 当前范围

当前仓库在 `v0.2.0` 发布基线上继续覆盖这些事情：

- `AGENTS.md` / `CLAUDE.md` 的跨工具指导；
- 新项目初始化卫生；
- `.gitignore`、`.env.example`、本地 `docs/`、`temp/` 规则；
- 本地 ignored `AGENTS.md` / `CLAUDE.md` 指令文件；
- `docs/agent-room/` 交流区、handoff 和 review checklist；
- append-only room ledger、并发追加和历史篡改检测；
- 以语义边界触发的阶段收口与新会话恢复链；
- 经探测填写的开发环境基线，以及 status 指向的单一主 checklist；
- 单 Agent、双 Agent、三 Agent 与多 Agent 团队的自适应协作方式；
- git 分支、阶段、版本和 commit 节奏；
- 代码架构和文件复杂度基线；
- 前端 UI 质量底线；
- 新项目模板和初始化脚本。
- 无第三方依赖的 Windows/POSIX 终端交互入口。
- 位于业务项目之外、可跨项目映射的 Reference Library。

它暂时不追求成为完整脚手架、CI 平台或文档站。

## 阶段收口

AWZ 的 checkpoint 是轻量的信息收口约定，不监测 token，不介入 Codex、Claude Code、OpenCode 等 Harness 的上下文压缩。feature 完成、root cause 确认、关键决策落定、实验结束、换 Agent/会话或切换阶段时，先以真实代码、Git 和验证结果更新 `docs/agent-room/status.md`；decision、handoff、ledger 与 references 只在各自职责命中时更新。新会话从短入口和 status 指针恢复，不默认重读全部旧聊天。详细规则见 [Agent Onboarding 工作流](workflows/agent-onboarding.md)。

## 仓库结构

```text
.
├─ requirements/
│  └─ awz-workflow-v0.1.md
├─ workflows/
│  ├─ agent-collaboration.md
│  ├─ room-ledger.md
│  ├─ agent-onboarding.md
│  ├─ project-initialization.md
│  ├─ reference-library.md
│  ├─ review-and-fix.md
│  ├─ release-and-vps.md
│  ├─ tui.md
│  └─ verification-baseline.md
├─ style/
│  ├─ code-architecture-baseline.md
│  ├─ frontend-baseline.md
│  ├─ frontend/
│  │  ├─ visual-composition.md
│  │  ├─ motion-and-interaction.md
│  │  └─ responsive-and-verification.md
│  └─ git-style.md
├─ scripts/
│  ├─ awz.bat
│  ├─ awz.ps1
│  ├─ awz.sh
│  ├─ lib/AwzTui.psm1
│  ├─ init-project.ps1
│  ├─ init-project.bat
│  ├─ init-project.sh
│  ├─ reference-library.py
│  ├─ reference-library.ps1
│  ├─ reference-library.sh
│  ├─ refresh-project.py
│  ├─ refresh-project.ps1
│  ├─ refresh-project.sh
│  ├─ smoke-awz-tui.ps1
│  ├─ smoke-awz-tui.sh
│  ├─ smoke-init-project.ps1
│  ├─ smoke-init-project.sh
│  ├─ smoke-reference-library.ps1
│  ├─ smoke-reference-library.sh
│  ├─ room-ledger.py
│  ├─ smoke-room-ledger.py
│  ├─ package-release.ps1
│  └─ package-release.sh
├─ VERSION
├─ CHANGELOG.md
└─ templates/
   └─ project/
      ├─ AGENTS.md
      ├─ CLAUDE.md
      ├─ agent-onboarding.md
      ├─ references-layout.md
      ├─ room-ledger.py
      ├─ guides/
      ├─ agent-status.template.md
      ├─ handoff.template.md
      ├─ decision-record.template.md
      ├─ gitignore.template
      ├─ env.example
      ├─ docs-layout.md
      ├─ review-checklist.template.md
      ├─ release-checklist.template.md
      ├─ references.json
      └─ temp-layout.md
```

## 默认选择

- Python 本地开发优先用 `uv`，必要时回退到 `python -m venv`。
- 前端包管理优先用 `pnpm`，必要时回退到 `npm`。
- 部署文档在涉及 Python/Node 时，要兼容 `venv` 和 `npm`。
- 小项目不默认生成 `pyproject.toml` 或 `package.json`；确实用到对应技术栈时再生成。
- 默认开源协议用 MIT，除非项目明确需要别的宽松协议。
- git 默认分支用 `main`。
- 中大型阶段或多 Agent 协作优先使用短生命周期 topic branch，完成后合并回 `main`。
- commit 按 logical change 切分，不要过碎，也不要把无关主题塞进一个大 commit。
- 小项目保持轻量；Docker、GitHub Actions、Cloudflare Pages 等在项目规模需要时再加入。

## VPS 与发布

当前发布版本由 `VERSION` 管理。Windows 使用 `scripts/init-project.ps1`，也可通过薄封装 `scripts/init-project.bat` 从 `cmd` 调用；Ubuntu/POSIX 使用 `scripts/init-project.sh`。默认新项目模式只接受不存在或空目录，已有项目必须显式选择 `Existing` 模式；两端都先运行 dry-run，再进行真实初始化。跨平台 release 包和 VPS 使用方式见 [Release 与 VPS 初始化工作流](workflows/release-and-vps.md)。每个正式 tag 都必须经过两端初始化器、解压隔离 smoke 和 release 包验证。

模板或初始化器变更后，先运行对应平台的轻量回归 smoke：`./scripts/smoke-init-project.ps1` 或 `bash scripts/smoke-init-project.sh`。它只验证初始化器本身，不替代 release 前的解压隔离 smoke。

初始化生成的项目 README 只提供中英文占位骨架，不声明 AWZ、Agent 工作区或默认技术栈。真实项目应按产品、安装、部署、贡献和合规需求自由增删或完整重写。

## 参考项目库

Reference Library 把 GSAP 这类长期参考源码放在业务项目之外，通过可提交的 `.awz/references.json` 映射给具体项目。Windows 默认优先 `D:\AWZ References`，没有 D 盘时回退 `%USERPROFILE%\AWZ References`；本机可以显式配置其他位置。

初始化器只生成空 mapping 和 `docs/references/README.md` 背景/资料入口，不联网、不 clone。`context` 默认把本机解析结果写入同目录的 `reference-context.md`；真实第三方源码始终位于业务项目之外。参考库的 configure、add、map、context 和 doctor 使用独立命令，详见 [参考项目库工作流](workflows/reference-library.md)。

Reference Library 的写操作会在机器级 reference root 的 `logs/transactions/` 留下脱敏 transaction 记录，包含计划 hash、已完成/未完成 action、终态和失败恢复步骤。它用于审计与恢复，不保存 credential-bearing URL、token 或 cookie。

## 安全刷新已有项目

`refresh-project` 是独立于 `init` 的 AWZ 管理文件升级路径。它只管理通用 Agent 入口、guide 和模板，不覆盖项目自有的 README、LICENSE、status、references、collaboration 或 frontend 配置。首次运行会用 `docs/agent-room/.awz-manifest.json` 接管与当前模板完全一致的文件；遇到本地改写、目录/符号目标或损坏 manifest 时整体阻止。

PowerShell：

```powershell
$preview = & '.\scripts\refresh-project.ps1' --target 'E:\Project\Example' --dry-run --json | ConvertFrom-Json
& '.\scripts\refresh-project.ps1' --target 'E:\Project\Example' --apply --plan-hash $preview.plan.planHash
```

POSIX：

```bash
bash scripts/refresh-project.sh --target "$HOME/projects/example" --dry-run
```

apply 必须携带上一轮 DryRun 的 `planHash`；源模板、目标文件或 manifest 状态变化时拒绝执行。覆盖前备份位于项目本地 ignored `docs/agent-room/refresh-backups/`。该可选命令使用 Python 3 标准库，不改变初始化器无 Python 前置的边界。

## 终端交互入口

Windows 推荐直接运行 BAT。它会使用 `-NoProfile` 启动 PowerShell，并进入 AWZ 控制中心：

```powershell
.\scripts\awz.bat
```

从任意目录调用带空格的绝对路径时，PowerShell 必须使用 `&` 和引号：

```powershell
& 'E:\Project\AWZ Workflow\scripts\awz.bat'
```

也可以直接使用 PowerShell 脚本：

```powershell
.\scripts\awz.ps1
& 'E:\Project\AWZ Workflow\scripts\awz.ps1'
```

Ubuntu/POSIX：

```bash
bash scripts/awz.sh
```

Windows 与 POSIX 主菜单统一提供：创建新项目、接入已有项目、Reference Library、安全刷新检查和 Doctor。当前 Reference Library 支持结构化只读的全局列表、详情、本地仓库状态和项目 mapping（含 purpose、required、unresolved）；Doctor 只报告配置与离线问题；安全刷新检查只运行 manifest DryRun，绝不从控制中心 apply。初始化子流程继续使用编号选择、原生单行输入、完整 DryRun、危险确认和结果页面，并在输入/预览步骤统一提供 B 返回、Q 退出、H/? 帮助，避免逐键重绘在 Windows Terminal/ConPTY 下造成残影或错位。

Reference root 配置、Reference `add` 以及项目 `map/unmap/context` 已接入控制中心：先执行 DryRun，再使用 planHash 绑定 apply，并留下 transaction 记录；更新、trash/restore 等其他写入生命周期仍建议使用 CLI，直到各自的预览与恢复界面完成。自动化环境可以传入完整 init 参数和 `-Yes` / `--yes`，但不能跳过预览与底层安全检查。详细契约见 [TUI 与 CLI 工作流](workflows/tui.md)。

## 硬边界

- 默认不提交 `.env`、`.codex/`、`.claude/`、`.vscode/`、`docs/`、`temp/`。
- 初始化到项目根目录的 `AGENTS.md`、`CLAUDE.md` 默认不提交。
- 必须提交 `.env.example`，但里面只能放假值或示例值。
- commit 里禁止出现 `Co-authored-by AI`、`Generated by AI`、`Authored by Codex/Claude` 之类痕迹。
- 使用用户环境里配置好的 git 用户名和邮箱。
- AI 改动必须可 review：不要无解释的大文件、不要空口说修好了、不要没验证就结束。
- 前端先建立基础 UI 语言，再搭页面，禁止默认裸奔和拼装感。

## 关键参考

- Codex `AGENTS.md`：<https://developers.openai.com/codex/guides/agents-md>
- Claude Code `CLAUDE.md`：<https://code.claude.com/docs/en/memory>
- Google Python Style Guide：<https://google.github.io/styleguide/pyguide.html>
- Google TypeScript Style Guide：<https://google.github.io/styleguide/tsguide.html>
- Microsoft 架构指导：<https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures>
- FastAPI 大项目结构：<https://fastapi.tiangolo.com/tutorial/bigger-applications/>
- React Thinking in React：<https://react.dev/learn/thinking-in-react>

# 参考项目库工作流

本文件定义 AWZ Workflow 如何管理位于业务项目之外、可跨项目复用的第三方参考源码。

参考项目库用于定向阅读和方案借鉴，不是业务依赖目录、Git submodule、vendored source 或可自动执行的工具仓库。

## 目录与默认值

Windows 公共默认路径：

1. 存在 `D:\` 时使用 `D:\AWZ References`；
2. 不存在 `D:\` 时使用 `%USERPROFILE%\AWZ References`；
3. 用户配置可以覆盖默认值。

当前开发机器显式使用 `E:\Project\AWZ References`。

POSIX 默认使用 `${XDG_DATA_HOME:-$HOME/.local/share}/awz-workflow/references`。

参考库内部结构：

```text
AWZ References/
├─ catalog/          # 一项目一份 JSON metadata
├─ repos/            # 第三方 Git clone
├─ context-cache/    # 可再生成的 AI 摘要
└─ logs/             # 本地操作日志，不进入业务项目
```

机器级配置位于：

- Windows：`%LOCALAPPDATA%\AWZ Workflow\config.json`
- POSIX：`${XDG_CONFIG_HOME:-$HOME/.config}/awz-workflow/config.json`

可使用 `AWZ_CONFIG_DIR` 覆盖配置目录，主要用于隔离 smoke；它不应写进项目文件。

## 项目映射

项目通过可提交的 `.awz/references.json` 声明需要哪些 reference id：

```json
{
  "schemaVersion": 1,
  "references": []
}
```

映射文件只能保存机器无关信息，例如 id、用途和是否 required，不保存本机绝对路径、凭据或私有 remote。

初始化器生成空映射，但不会创建外部参考库、修改机器级配置、联网或 clone。已有项目中的 `.awz/references.json` 视为项目自有文件，即使 `Existing -Force` 也不能覆盖。

## 项目内的 Reference 信息架构

项目内只保留一个本地入口 `docs/references/`，统一承载稳定背景和参考资料：

- `docs/references/README.md`：人工维护的项目背景、目标、约束、术语和资料索引；
- `.awz/references.json`：可提交、机器无关的外部源码映射；
- `docs/references/reference-context.md`：由 `context` 生成的本机解析结果，可随时再生成；
- 真实第三方 clone：始终位于项目外的机器级 Reference Library。

当前任务状态、owner 和 handoff 不属于 reference，继续放在 `docs/agent-room/`。大文件、截图和导出物放 `temp/`，只在资料索引中记录来源与用途。

## 首版命令

Windows：

```powershell
.\scripts\reference-library.ps1 configure --root 'E:\Project\AWZ References' --dry-run
.\scripts\reference-library.ps1 configure --root 'E:\Project\AWZ References'
.\scripts\reference-library.ps1 add --id gsap --url https://github.com/greensock/GSAP.git --category frontend --dry-run
.\scripts\reference-library.ps1 list
.\scripts\reference-library.ps1 show --id gsap
.\scripts\reference-library.ps1 map --project 'E:\Project\Example' --id gsap --purpose '前端交互动效参考'
.\scripts\reference-library.ps1 context --project 'E:\Project\Example'
.\scripts\reference-library.ps1 status --project 'E:\Project\Example'
.\scripts\reference-library.ps1 doctor --project 'E:\Project\Example'
```

POSIX：

```bash
bash scripts/reference-library.sh configure --root "$HOME/AWZ References" --dry-run
bash scripts/reference-library.sh list
```

首版支持 `configure`、`add`、`list`、`show`、`status`、`map`、`unmap`、`context`、`doctor`。`update` 和自动删除延后。

参考库命令使用 Python 3 标准库核心；这只是可选 reference 能力的前置条件，不影响 `init-project.ps1` 或 `init-project.sh`。

首版把相关命令集中在一个标准库 CLI 中，是为了让 Windows/POSIX 共享同一份 JSON、路径和 Git 语义；各 command 已按函数分离。引入 remote update、private auth 或更多 provider 后，应再按 config/catalog/git/context 职责拆 module，而不是继续无界增长单文件。

## Add 边界

- 首版只接受不含内嵌凭据的 public `https://` Git URL。
- 默认 shallow clone，默认不初始化 submodule。
- clone 前验证 id、category、目标路径和 Git。
- clone 后记录 remote、HEAD、version 线索、license 线索和推荐阅读入口。
- 不运行依赖安装、构建、测试、package lifecycle script 或第三方 hook。
- metadata 原子写入；clone 成功但 metadata 失败时保留 clone 并报告恢复路径。
- reference repo 默认为 `source-only` trust。

本地路径 clone 只允许通过显式 `--allow-local`，用于离线 smoke 和受控迁移，不是 public add 的默认入口。

## AI 阅读规则

`context` 根据当前项目映射生成 ignored `docs/references/reference-context.md`，内容包括：

- reference 的用途、tags、useWhen 和 avoidWhen；
- 本机解析路径；
- catalog revision 与实际 HEAD；
- readFirst 文件；
- trust 与 license；
- missing、dirty、drifted 等状态。

Agent 必须先读当前项目，再按任务命中情况读取 reference。默认只读 `readFirst`，不得机械扫描整个参考库，也不得因为 reference 存在而自动执行其代码。

## Status 与 Doctor

`status` 默认只读、离线，检查配置、catalog、路径越界、repo、remote、HEAD、dirty state、readFirst 文件和项目 mapping 的 unresolved id。

`doctor` 执行更严格的完整检查，发现错误时返回非零退出码。首版不访问远端判断是否有更新。

## 安全与 lifecycle

- reference id 和 category 必须通过安全字符校验。
- resolved repo path 必须仍位于 reference root 内。
- 不输出 credential-bearing URL。
- dirty reference repo 不自动清理。
- `unmap` 只解除项目映射，不删除全局 clone。
- license 缺失必须显示为 `unknown`，不能当作可自由复制。
- reference repos、机器配置、context cache 和 logs 不进入业务项目或 AWZ release 包。

### Transaction 与失败恢复

- `configure`、`add`、`map`、`unmap` 和 `context` 的真实写入会在 `<referenceRoot>/logs/transactions/` 创建 transaction JSON。
- transaction 状态按 `planned → applying → completed/failed` 流转，并记录 `planHash`、actions、completed、remaining、recovery 和脱敏错误。
- JSON apply 成功时在 `data.transaction` 返回 transaction 摘要；失败时使用 `blockedBy`、`recovery` 和可用的 transaction 摘要说明阻塞与恢复入口。
- 文本 CLI 失败时也必须打印 transaction 路径和 recovery，不让用户只能从半成品猜测发生了什么。
- transaction 不得记录 credential-bearing URL、token、cookie、password、secret 或 API key；日志自身也不进入业务项目或 release 包。

## 验证

变更 reference 功能后至少运行：

```powershell
.\scripts\smoke-reference-library.ps1
.\scripts\smoke-init-project.ps1
```

```bash
bash scripts/smoke-reference-library.sh
bash scripts/smoke-init-project.sh
```

smoke 使用隔离配置目录和本地 Git fixture，不依赖公网，也不能修改真实参考库。

模块级离线测试：

```powershell
python -m unittest discover -s scripts/tests -v
```

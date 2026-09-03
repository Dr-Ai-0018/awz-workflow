# 验证指南

先识别项目已有的 README、脚本、配置和测试入口，再选择最小有效验证。不要为了跑检查生成项目并不需要的依赖或配置。

## 验证层级

- `DryRun`：回答“如果执行，会改什么”，且不写文件、不创建目录、不初始化 git、不安装依赖、不修改用户环境。
- `Smoke`：回答“用户的最小闭环能不能跑”。
- `Full Check`：回答“这个阶段能不能交付或合并”。

优先运行项目已经定义的 test、lint、typecheck、build、health check 或浏览器入口；具体命令以当前项目事实为准。

## 风险比例与停止策略

问题优先级 `P0/P1/P2/P3` 与验证级别分开：

| 验证级别 | 典型改动 | 默认验证 |
| --- | --- | --- |
| `V0` | 文案、注释、格式、无行为配置 | diff review、语法或静态检查 |
| `V1` | 单函数、单模块局部逻辑 | 相关 test file 或最小 smoke |
| `V2` | 跨模块、API、schema、数据流 | 受影响模块 + 必要 integration/contract check |
| `V3` | 公共核心、安全、并发、持久化、依赖、release | 明确范围的 Full Check；必要时 E2E/UI/build |

### 标准开发节奏

范围基线 → 风险分级 → 单切片实现 → diff review → 最小验证 → 停止/交接。每一步都要保持当前范围可解释；发现新风险时更新验证级别，不通过无关重构扩大任务。

默认 focused-first，并遵守：

- 每次验证前说明它验证的具体风险。
- 同一代码树、同一命令、同一环境已经通过时，不重复执行。
- focused 通过后不自动升级 full suite；只有失败、相关代码变化、新风险或明确 gate 才能升级。
- full suite、E2E、UI test、benchmark 等昂贵验证必须由用户要求或项目 gate 触发；V3 风险只提高评估等级，不单独授予昂贵验证授权，否则先报告成本并等待确认或交给 CI。
- 环境失败只做有限诊断和一次合理 fallback，之后报告 blocker，不无限换工具或重跑。
- 达到验收条件后停止，并记录命令、结果、未覆盖风险和下一步。

## 环境与文本写入

- 首次构建、已有项目接入或环境变化时，探测 OS、实际 shell executable/version、编码/行尾、runtime/package manager 和验证入口，再把有效事实写入 `docs/references/README.md`。
- PowerShell、cmd 与 Bash 的引号和转义不能互相照搬。PowerShell 的“反引号 + n”只在正确的可展开字符串中表示换行；Windows PowerShell 5.1 与 PowerShell 7 的默认编码也可能不同。
- 多行文档优先用结构化 edit/patch；必须经 shell 写入时立即回读实际字符、编码和行尾。生成器还应增加文件尾或字节级回归断言。

## 按需扩展

- 前端视觉、交互、多端和可访问性：读 `frontend/responsive-and-verification.md`。
- 跨目录、跨盘或未知位置查找文件：读 `file-search.md`。
- 初始化脚本、生成器或一次性输出：使用本项目 `temp/smoke-<timestamp>/`、`temp/dryrun-<timestamp>/` 或 `temp/output/`。
- 只有共享行为、公共 contract、release 或合并边界受影响时，才扩大到 Full Check。

## 用户入口

用户可见功能交付前至少确认：

- README、根命令 `--help` 或主菜单能找到该能力；
- 文档入口、参数和界面名称与真实实现一致；
- smoke 从用户实际入口进入，不绕过编排层只测内部函数；
- 交互能力覆盖取消、错误和结果回看，静态 render 不能替代真实交互；
- CLI backend 与 TUI lifecycle 分开验收，未接入主入口时明确标为内部或未完成。

## 交接

最终交接说明：

```text
验证层级：
运行命令：
结果：
未验证：
原因：
后续建议：
```

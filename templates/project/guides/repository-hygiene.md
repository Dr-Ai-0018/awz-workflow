# 仓库卫生指南

根目录 `AGENTS.md` 定义始终生效的提交边界；当前跟踪与忽略状态通过 `.gitignore` 和 `git status` 核验。本指南只处理项目特化与临时材料放置，不复制整份 ignore 清单。

## 项目特化

- 根据真实语言、框架和构建产物补充 `.gitignore`，不要从模板猜技术栈。
- `.env.example` 只保留假值或示例值；真实 `.env`、密钥和私有配置不得提交。
- 提交前检查 `git status` 和 staged diff，确认源码、测试、公开文档与必要配置齐全。
- 不提交编辑器状态、Agent 本地状态、日志、缓存和可再生成产物。

## 本地材料

`docs/` 的信息归属以 `docs/README.md` 为准；不要在本指南重复维护目录职责。

`temp/` 是任务级临时材料区，不要把所有东西丢到根目录。按任务使用：

- `temp/scripts/`
- `temp/output/`
- `temp/assets/`
- `temp/screenshots/`
- `temp/experiments/`
- `temp/logs/`

临时产物若形成长期结论，应提升到代码、README、正式文档、ADR、issue 或 PR，而不是把整个产物提交进仓库。

## AWZ 管理文件刷新

- 项目升级使用 AWZ 的独立 `refresh-project` DryRun/apply 入口，不用 `Existing + Force` 猜测覆盖范围。
- `docs/agent-room/.awz-manifest.json` 记录 AWZ 管理文件的最后应用 hash；由工具维护，不手工修改。
- 项目自有 README、LICENSE、status、references、collaboration 和 frontend 配置不属于 refresh 覆盖范围。
- 发现 local modification/conflict 时整体停止；先 review 本地改动，再决定保留、手工合并或恢复通用模板。
- refresh 覆盖前的备份和 transaction 位于 ignored `docs/agent-room/`，不能提交进业务仓库。

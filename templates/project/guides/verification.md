# 验证指南

## 三层验证

`DryRun`：回答“如果执行，会改什么”。

- 不写文件；
- 不创建目录；
- 不初始化 git；
- 不安装依赖；
- 不修改用户环境。

`Smoke`：回答“最小闭环能不能跑”。

`Full Check`：回答“这个阶段能不能交付或合并”。

## Python

- 本地开发、依赖管理、测试优先用 `uv`。
- `uv` 不可用或项目约束不适合时，回退到 `python -m venv`。
- 涉及部署时，文档必须兼容 `venv`。
- 不因为想跑 pytest 就自动生成 `pyproject.toml`。
- 只有确实是 Python 包、服务、测试工程或需要依赖锁定时，才生成 `pyproject.toml`。

## Node / Frontend

- 本地开发和测试优先用 `pnpm`。
- `pnpm` 不可用或项目约束不适合时，回退到 `npm`。
- 涉及部署时，文档必须兼容 `npm`。
- 不因为想跑 TypeScript 检查就自动生成 `package.json`。
- 只有确实需要 Node 工具链、前端工程、构建脚本或测试脚本时，才生成 `package.json`。

## 测试目录

验证初始化脚本、生成器或一次性输出时，默认使用本项目的 `temp/` 目录。

推荐：

```text
temp/smoke-<timestamp>/
temp/dryrun-<timestamp>/
temp/output/
```

不要默认写到 `C:\tmp`、桌面、下载目录或其他项目外路径。

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

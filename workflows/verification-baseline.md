# 验证和检测基线

本文件定义 Agent 在项目中如何选择检查命令。核心原则：先检测已有入口，再执行最小有效验证；不要为了验证而强行生成项目并不需要的配置文件。

## 三层验证

### DryRun

回答“如果执行，会改什么”。

适用：

- 初始化项目；
- 批量生成文件；
- 可能覆盖已有文件；
- 涉及目录结构或配置写入。

要求：

- 不写文件；
- 不创建目录；
- 不初始化 git；
- 不安装依赖；
- 清楚列出将写入、将跳过、将覆盖、将不生成的内容。

### Smoke

回答“最小闭环能不能跑”。

适用：

- 初始化后；
- 修复后；
- 交接前；
- 不确定完整测试是否昂贵时。

例子：

- Python：导入主模块、启动 app、跑一个最小 pytest；
- Frontend：启动 dev server、打开页面、确认无白屏；
- CLI：运行 `--help` 或最小命令；
- API：命中 health check 或最小 contract。

### Full Check

回答“这个阶段能不能交付或合并”。

适用：

- 合并回 `main` 前；
- 大功能完成；
- release 前；
- 触及共享逻辑或公共 contract。

可能包括：

- test；
- lint；
- typecheck；
- build；
- browser preview；
- migration dry-run；
- security/privacy spot check。

## Python 检测顺序

1. 如果存在 `pyproject.toml`，优先检查是否可用 `uv`：
   - `uv sync`
   - `uv run pytest`
2. 如果没有 `uv` 或项目明确不用 `uv`，检查 venv 路径：
   - `python -m venv .venv`
   - `.\.venv\Scripts\Activate.ps1`
   - `pip install -r requirements.txt`
   - `pytest`
3. 如果只有脚本，没有测试框架：
   - 运行主脚本的 `--help`、导入检查或最小示例。
4. 不因为想跑 pytest 就自动生成 `pyproject.toml`。

## Node / TypeScript 检测顺序

1. 如果存在 `package.json`，先读取 `scripts`。
2. 优先使用 `pnpm`：
   - `pnpm install`
   - `pnpm test`
   - `pnpm lint`
   - `pnpm typecheck`
   - `pnpm build`
3. 如果没有 `pnpm` 或部署路径要求，回退 `npm`：
   - `npm install`
   - `npm test`
   - `npm run lint`
   - `npm run typecheck`
   - `npm run build`
4. 如果存在 `tsconfig.json` 但没有 script，可以说明缺少 typecheck 入口，必要时建议补 `typecheck` script。
5. 不因为想跑 TypeScript 检查就自动生成 `package.json`。

## 前端浏览器验证

前端变更不能只看 build。

至少确认：

- 页面不是白屏；
- console 没有关键 error；
- 核心交互可点击；
- 主要 viewport 不重叠、不溢出；
- modal、toast、滚动条、focus 等基础 UI 没有裸奔。

有真实浏览器控制工具时，优先真实浏览器。遇到登录、MFA、验证码时停下等用户操作。

## 输出格式

最终交接里写清楚：

```text
验证层级：
运行命令：
结果：
未验证：
原因：
后续建议：
```

不要只说“测试通过”。要说明跑了什么，以及没跑什么。

## 测试目录

验证初始化脚本、生成器或一次性输出时，默认使用本项目的 `temp/` 目录。

推荐：

```text
temp/smoke-<timestamp>/
temp/dryrun-<timestamp>/
temp/output/
```

如果本项目还没有 `temp/`，先创建 `temp/`，再把 smoke/dryrun 目标放进去。

避免默认写到 `C:\tmp`、用户桌面、下载目录或其他项目外路径。只有在用户明确指定、权限限制必须绕开，或需要模拟外部路径时，才使用项目外测试目录，并在交接里说明原因。

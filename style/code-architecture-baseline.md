# 代码架构基线

这份基线用来防止两种常见 AI 失败：

- 所有代码从头莽到尾塞进一个巨型文件；
- 为了显得“工程化”，拆成一堆没有稳定职责的小文件。

目标不是仪式感，而是清楚的责任边界。

## 通用原则

- 先跟随现有项目风格。
- 再跟随语言生态约定。
- 优先使用现代、主流、朴素的架构，不发明聪明但难维护的模式。
- 非平凡项目里，业务规则不要和 transport detail 搅在一起。
- 基础设施细节尽量放在明确边界后面。
- 让后来的人和后来接手的 AI 都能按职责定位代码。

## 责任分层

非平凡 Backend/API 项目默认采用这个心智模型：

```text
api/routes/controllers   # 外部请求/响应边界
schemas/dto/contracts    # 输入/输出数据形状
services/usecases        # 业务流程编排
domain/models            # 核心规则、实体、不变量
repositories             # 持久化抽象
infrastructure           # DB、文件系统、外部 API、队列
config                   # 配置和环境加载
tests                    # 镜像重要源码结构
```

简单项目可以合并层次，但复杂度上来后不能继续把多个职责藏在一个文件里。

## 文件和函数大小

这些是 review trigger，不是绝对阻塞。

### Function / Method

- 目标：20-40 行。
- 超过 40 行：主动评估拆分是否能提升可读性。
- 超过 80 行：必须解释为什么仍保持一个函数。

### Frontend Component

- 目标：80-150 行。
- 超过 200 行：考虑拆 subcomponent、hook、utility 或 style module。
- 超过 300 行：默认要求 refactor，除非有明确理由。

### Source File

- 普通源码目标：200-500 行。
- 超过 800 行：说明责任边界。
- 超过 1200 行：默认拆分，或写明例外。

### Complexity

- Cyclomatic complexity <= 10 最理想。
- 10-15 可接受，但要有测试和清楚结构。
- 15-20 需要解释。
- 20+ 默认要求 refactor 或显式例外。

## 例外模板

超过阈值时使用：

```text
Exception:
- Reason:
- Risk:
- Why splitting now would hurt:
- Future split point:
- Verification added:
```

## 各语言命名

跟随语言生态，不自造项目方言。

### Python

- files/modules/packages：`snake_case`
- functions/methods/variables：`snake_case`
- classes/exceptions：`CapWords`
- constants：`CAPS_WITH_UNDER`
- 内部名需要时用单前导 `_`
- 避免滥用双下划线隐私

### TypeScript / JavaScript

- classes/types/interfaces/enums/React components：`UpperCamelCase`
- variables/functions/methods/properties：`lowerCamelCase`
- global constants：`CONSTANT_CASE`
- 文件命名跟随本地项目；共享 utility 默认偏 lowercase + separator
- 避免含糊缩写和 Hungarian notation

### Java

- packages/modules：小写，不用下划线
- classes/interfaces：`UpperCamelCase`
- methods/fields/parameters/local variables：`lowerCamelCase`
- constants：`UPPER_SNAKE_CASE`
- test classes 通常以 `Test` 结尾

### C# / .NET

- public types 和 public members：`PascalCase`
- local variables 和 parameters：`camelCase`
- private fields：常见 `_camelCase`
- interfaces 常见 `I` 前缀

### Go

- package names：短、小写、不用下划线
- exported names：`MixedCaps`
- unexported names：`mixedCaps`
- 使用 `gofmt`，不要和 Go formatter 对抗

### Rust

- modules/functions/methods/local variables：`snake_case`
- types/traits/enums：`UpperCamelCase`
- constants/statics：`SCREAMING_SNAKE_CASE`
- 不确定时跟随 standard library 命名

## 抽象规则

好的抽象：

- 消除已经真实存在的重复；
- 命名一个稳定职责；
- 形成可测试边界；
- 把 infrastructure 藏在 contract 后面；
- 让未来改动更小。

坏的抽象：

- 只是因为“架构应该有层”；
- 包了一行没有稳定意义的代码；
- 用泛泛名称隐藏简单逻辑；
- 让导航更难；
- 按技术虚荣拆分，而不是按行为边界拆分。

## 注释

- 优先用清楚命名代替解释性注释。
- 注释解释 why、tradeoff、invariant、非显然约束。
- 不注释显而易见的赋值和流程。
- TODO 应包含上下文或 tracking reference，不写某个人名。

# 前端指南

## 质量底线

避免通用 AI 味前端：

- 随机圆角卡片；
- 用 left-border 假装层级；
- card 套 card；
- 间距不一致；
- 对齐混乱；
- 超长且失控的 div；
- 糟糕的内置滚动区；
- 原生控件裸奔；
- 没有系统性的假苹果味。

## 基础 UI 语言

前端开发应该先建立基础 UI 语言：

- typography；
- spacing scale；
- colors；
- buttons；
- inputs；
- focus states；
- modal/dialog；
- toast/notification；
- scrollbar；
- layout shell；
- responsive behavior。

较大的前端任务可以先预写 3-5 个明显不同的风格/布局方向，供初筛后再深入实现。

## 浏览器验证

- Web 预览优先使用真实浏览器扩展/控制。
- 如果预期使用真实浏览器，不要静默退回内部预览。
- 遇到 CAPTCHA、密码、MFA、人机验证时停下来，让用户操作。

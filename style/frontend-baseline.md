# 前端基线

AWZ 前端不能有通用 AI 味。

目标是形成统一的 interface system：对齐、稳定、响应式、交互有手感。

## 明确讨厌的模式

避免：

- card 套 card；
- 随机 left-border 假装层级；
- 到处都是大圆角矩形；
- 间距不一致、列不对齐；
- 原生控件裸奔；
- 超长失控 div；
- 尴尬的内部滚动条；
- 文本溢出、裁切、挡住内容；
- modal/toast 像事后补丁；
- 没有系统性的假苹果味。

## 构建顺序

在堆很多页面之前，先定义基础 UI 语言：

```text
styles/
  tokens.css       # color、spacing、font、radius、shadow scale
  base.css         # body、text、link、button、input、focus、scrollbar
  overlays.css     # modal、popover、toast
  layout.css       # shell、grid、responsive container
```

如果使用 Tailwind、CSS modules、styled system 或组件库，可以采用等价结构。

## 必备 UI 基础

非平凡前端默认统一：

- typography scale；
- spacing scale；
- color tokens；
- button variants；
- input/select/textarea states；
- disabled/loading/error states；
- focus rings；
- modal/dialog 行为，包含 backdrop blur 或 dim；
- toast 的位置、时长、动画；
- scrollbar 样式；
- responsive breakpoints；
- empty/loading/error/success states。

## Component 规则

- 一个 component 应有一个稳定职责。
- 当行为、布局、数据加载、样式缠在一起时要拆。
- 可复用 stateful logic 提取为 custom hook。
- pure transform 提取为 utility。
- page component 是组合入口，不是垃圾桶。
- 避免无意义 prop drilling；context 或 local store 只有在降低真实复杂度时才使用。

## Layout 规则

- 使用一致的 grid 和 spacing。
- 对齐必须明显且有意图。
- 除非产品真的需要，避免多个嵌套滚动区。
- 优先 page-level scrolling，不把内容藏进奇怪 panel scroll。
- 移动端和桌面端文本都必须能放下。
- 按钮在 hover/loading/disabled 等状态下不应乱跳尺寸。
- 关键控件尺寸要稳定。

## 交互规则

默认期待：

- button 有 hover、active、focus、disabled、loading 状态；
- destructive action 在可能丢数据时需要确认；
- toast 平滑进入/退出，并在合理时间后自动消失；
- modal 需要时 trap focus，并能可预测地关闭；
- form validation 靠近字段展示，必要时提供 summary-level feedback。

## 浏览器验证

有工具时使用真实浏览器预览。

检查：

- desktop viewport；
- mobile viewport；
- first load；
- error/empty/loading states；
- modal/toast 行为；
- scroll 行为；
- 没有明显 overlap、clipping、不可读文本。

如果浏览器扩展或控制不可用，直接说明。

## 设计方向探索

较大的 UI 任务，可以先做 3-5 个明显不同的方向再深入。

每个方向应在这些方面有实质差异：

- layout；
- density；
- navigation model；
- visual tone；
- component treatment。

不要做五个只是换颜色的同款弱布局。

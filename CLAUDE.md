@AGENTS.md

## Claude Code 补充说明

- Claude Code 读取 `CLAUDE.md`，不直接把 `AGENTS.md` 当作默认入口。
- 本文件通过 `@AGENTS.md` 导入共同规则，避免 Codex 和 Claude 维护两套互相漂移的说明。
- Claude 专属补充保持短小。
- 涉及大范围前端重构、项目架构、依赖变更、多文件 refactor 时，优先使用 plan mode。
- 可用时优先使用真实浏览器预览；如果浏览器扩展或连接不可用，要直接说明，不要静默退回内部预览。

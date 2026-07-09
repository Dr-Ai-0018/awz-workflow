# 阻塞和安全指南

## 基础设施阻塞

如果 DNS、网络、安装依赖、文件权限、sandbox 等基础设施问题阻塞关键工作：

1. 先按规则申请权限或提权重试；
2. 重试失败后选择合理 fallback；
3. 不要在同一个失败路径上反复打转；
4. 汇报真实 blocker 和已经尝试过的修复。

不要钻牛角尖。安全可行的替代路径优先。

## Codex 编辑

- Codex 手工编辑使用原生 `apply_patch`。
- 如果 `apply_patch` 不可用，说明真实限制，不要静默改用不相关写入方式。

## 必须停下等用户

- CAPTCHA；
- MFA；
- password；
- destructive 文件或数据库操作；
- secret rotation；
- 大范围架构重写；
- 新增 heavyweight production dependency；
- 变更部署目标或费用敏感基础设施。

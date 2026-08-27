# 修正 Codex 登录诊断 Skill 归属

状态：已确认
建立时间：2026-08-27T14:13:31+08:00
确认时间：2026-08-27T14:13:31+08:00
执行完毕时间：未执行完毕

## 背景与目标

此前已确认并实施 Codex CLI 登录失败的全局只读诊断方案，但误把 `C:\Users\Administrator\.agents\skills` 当作权威源码位置。FTLSoul Skill 的真实源码仓库是 `Z:\Code\FTLSoulSkill`；用户安装目录只应包含由仓库脚本维护、指向该仓库源码的目录链接。

本次修正要把诊断 Skill 纳入 FTLSoulSkill 仓库，使路由、版本控制、README 和用户安装链接拥有单一事实来源，同时清理此次误放产生的独立副本和错误项目记录。

## 修改范围

- 在 `skills/engineering/ftl-codex-auth-diagnostics/SKILL.md` 保存诊断 Skill 源码。
- 保留并提交 `skills/engineering/ftl-router/SKILL.md` 中的 Codex 登录失败专用路由。
- 更新 `README.md` 的 Skill 清单和路由图，使其包含新诊断 Skill。
- 使用 `scripts/link-skills.ps1` 将 `C:\Users\Administrator\.agents\skills\ftl-codex-auth-diagnostics` 替换为指向仓库源码的受管目录链接，并更新链接清单。
- 从 `Z:\Code\CodexTalk` 当前版本中删除误放的需求记录；不改写已经产生的 Git 历史，只创建前向清理提交。
- 删除本次误安装所产生、经核对只属于本任务的临时暂存目录；不触碰其他未跟踪文件。

## 保留的诊断与安全规则

- 诊断必须区分：同一 CLI 的不同包装器、不同 CLI、同一 CLI 但 Windows 安全身份或凭据上下文不同、以及证据不足。
- 沙箱中的 `Not logged in` 不能单独证明普通用户未登录。
- 默认只读，不读取或展示凭据内容，不自动执行登录、登出或设备码授权，不启动 App Server，不发起模型调用。
- 只有普通用户上下文中的目标 CLI 也明确报告未登录时，才能说明确实需要登录；认证动作仍由用户亲自完成。
- `ftl-soul` 继续只负责面向用户的表达风格，不承担认证判断。

## 验收预期

- 新 Skill 与路由均通过 Skill Creator 结构校验。
- 仓库内新 Skill 与用户安装目录中的实际 Skill 内容来自同一目录链接，不再存在独立副本。
- `scripts/link-skills.ps1 -WhatIf` 和实际同步均能识别全部 Skill，链接清单包含 `ftl-codex-auth-diagnostics`。
- README、路由与 Skill 职责一致，四类诊断结论均可从 Skill 正文中确认。
- FTLSoulSkill 的实现提交只包含本需求允许的源码和文档；CodexTalk 的清理提交只删除误放需求记录。
- `ftl-soul` 内容保持不变；不执行任何认证或模型调用。

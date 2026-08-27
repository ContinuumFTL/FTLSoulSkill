# 将 Codex 认证 Skill 改为直接恢复

状态：执行完毕
建立时间：2026-08-27T14:29:18+08:00
确认时间：2026-08-27T14:29:18+08:00
执行完毕时间：2026-08-27T14:34:27+08:00

## 关联历史

- `docs/ftl/requirements/2026-08-27-修正Codex登录诊断Skill归属.md`
- 本文替代其中“以诊断为主体”的 Skill 设计；保留其源码归属、只读凭据边界和安装链接规则。

## 已知故障与已验证解法

已知故障具有明确特征：普通 Windows 用户终端中的目标 Codex CLI 已登录，而 Codex Agent 沙箱中的同一 CLI 报告 `Not logged in`。根因不是 CLI 未登录，而是 `CodexSandboxOffline` 等隔离身份无法访问普通用户上下文中的系统凭据。

2026-08-27 已用只读宿主检查验证：同一 `Z:\Develop\node-v24.13.0-win-x64\codex.ps1`、同一 `codex-cli 0.146.1` 在宿主身份 `desktop-mai33sr\administrator` 下直接报告 `Logged in using ChatGPT`。因此本故障的标准解决方法是让需要 Codex 登录凭据的实际命令及其父进程运行在已登录的宿主用户上下文，而不是重新登录或更换凭据。

## 目标行为

- 不再保留以广泛环境枚举为主体的 `ftl-codex-auth-diagnostics`。
- 以一个直接恢复 Skill 取代它；Skill 只做最低限度的适用条件确认，然后立即执行已验证的宿主上下文恢复路线。
- 在 Codex 桌面 Agent 中，用户已授权实际任务且宿主/沙箱登录状态矛盾时，为真正启动 Codex CLI、App Server 或其父级验收脚本的命令请求一次范围明确的宿主上下文执行批准。不得为 `codex login`、`codex logout` 或设备码授权申请该批准。
- 必须把整个会启动 Codex 的父进程放到宿主上下文；只更换 `codex.ps1`、`codex.cmd` 或 `codex.exe` 路径不能解决继承的安全身份问题。
- 在同一宿主上下文先用路径、版本、`codex login status` 和 `whoami` 做无模型调用的快速前置检查。确认已登录后，才执行用户原本授权的实际项目命令。
- 若宿主执行能力不可用或用户拒绝批准，只给一条可在普通已登录终端运行的最短项目命令；不得退回设备码授权。

## 长期项目修复规则

- 依赖 Codex 的项目应把“选择哪个可执行文件”和“在哪个 Windows 安全身份中启动”视为两个独立配置维度。
- 项目检测到 `CodexSandboxOffline` 且操作需要用户登录凭据时，应快速失败并明确要求改由宿主入口运行，不得自动启动登录流程。
- 可以提供稳定的显式 CLI 路径配置，但不能把它描述成凭据隔离的修复；同一 CLI 在错误身份下仍然无法读取登录。
- 不复制、迁移或解析 `auth.json`，不读取系统凭据秘密，不通过设置相同 `USERPROFILE` 或 `CODEX_HOME` 冒充相同安全身份。

## 修改范围

- 删除 `skills/engineering/ftl-codex-auth-diagnostics/`。
- 新增 `skills/engineering/ftl-codex-sandbox-auth-recovery/SKILL.md`。
- 更新 `skills/engineering/ftl-router/SKILL.md`，让已知状态矛盾直接进入恢复 Skill。
- 更新 `README.md` 的 Skill 清单、流程图和说明。
- 使用 `scripts/link-skills.ps1` 删除旧受管链接并创建新受管链接。
- `ftl-soul`、其他工程 Skill 和凭据配置不在修改范围。

## 验收预期

- 新 Skill 通过 Skill Creator 结构校验，正文以直接解决动作和验收闭环为主体，不再要求完整枚举所有 CLI、PATH、配置和凭据元数据。
- 给定“普通终端已登录、同一 CLI 在 Agent 沙箱未登录”的已知场景，新 Agent 能直接得出：不需要登录；应在宿主用户上下文运行实际父命令；先做无模型前置检查；再继续已授权任务。
- 新 Agent 不会把更换包装器、复制凭据、修改 `CODEX_HOME`、设备码授权或仅提升子进程当成正确修复。
- 路由和 README 不再引用 `ftl-codex-auth-diagnostics`；安装清单不再保留旧链接，只包含新恢复 Skill。
- 所有 Skill 结构校验通过，`ftl-soul` 保持不变；验证过程不调用模型、不消耗模型额度。

## 实施结果

- 已删除 `ftl-codex-auth-diagnostics` 源码、空目录和受管安装链接。
- 已新增 `ftl-codex-sandbox-auth-recovery`，主体直接规定宿主上下文恢复、整个父命令执行、范围化批准、无模型前置检查、手动终端兜底和长期项目修复。
- `ftl-router` 与 README 已改为直接恢复路由，不再要求完整 CLI、PATH、配置或凭据元数据诊断。
- 已在宿主上下文实际执行只读前置检查：同一 `codex.ps1`、同一 `codex-cli 0.146.1` 直接报告 `Logged in using ChatGPT`，身份为 `desktop-mai33sr\administrator`；未调用模型。
- 链接脚本已移除旧入口并安装新受管符号链接；清单只保留新恢复 Skill。
- 仓库全部七个 Skill 均通过 Skill Creator 结构校验，最终审计全部通过；`ftl-soul` 未修改，未执行登录、登出、设备码授权或凭据操作。

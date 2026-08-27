---
name: ftl-codex-auth-diagnostics
description: 当 Codex CLI、Codex App Server 或依赖它们的项目出现 Not logged in、设备码提示、登录状态矛盾或疑似选错 CLI 时，执行只读的跨环境认证诊断；不用于普通 OpenAI API 密钥问题，也不自动登录、登出或读取凭据内容。
---

# Codex 登录失败诊断

判断故障来自真正缺少登录、选错可执行文件，还是 Agent 沙箱与普通用户使用了不同的 Windows 安全身份或凭据上下文。先证明原因，再决定是否需要项目修复；不得用重复登录掩盖尚未确认的环境差异。

## 面向用户的表达

在产生本次任务的面向用户聊天文本前，完整读取并使用 `ftl-soul`；其适用范围和正式产物例外以该 Skill 为准。结论应先用通俗语言说明，再给必要证据；避免把启动包装器、CLI 安装、用户配置和安全身份混成一件事。

## 默认边界

- 默认只读。允许检查命令解析、绝对路径、版本、`codex login status`、Windows 安全身份、`USERPROFILE`、`CODEX_HOME`、相关 PATH、认证存储配置和凭据文件元数据。
- 不读取、展示、解析或复制 `auth.json` 内容，不列出系统凭据库中的秘密。
- 不执行 `codex login`、`codex logout`、设备码授权、App Server 启动、模型调用、安装、卸载或凭据迁移。
- 某个 CLI 因沙箱或 WindowsApps 权限无法执行时记录原始失败；不得把“无法执行”写成“未登录”，也不得只为绕过该失败申请更高权限，除非用户另行明确授权。
- 诊断不授权修改项目代码、PATH、注册表、配置或凭据。用户明确要求实施修复时，完成诊断后回到 `ftl-router` 选择适用执行路线。

## 诊断顺序

### 1. 盘点可执行文件与启动包装器

在当前进程中检查：

- Windows：`Get-Command codex -All`、`Get-Command codex.exe -All`、`where.exe codex`；
- 项目实际使用 Python 时，在相同解释器和环境中检查 `shutil.which("codex.cmd")` 与 `shutil.which("codex.exe")`；
- 项目有自己的解析函数时，只调用解析函数并记录结果，不启动 App Server。

记录每个候选的绝对路径、版本和登录状态。检查包装器的目标或所属包：同一目录、同一 npm 包的 `codex.ps1`、`codex.cmd` 和无扩展脚本是同一套安装的不同入口，不得仅因后缀不同判为多套 CLI。

### 2. 记录身份与配置环境

同时记录：

- `[System.Security.Principal.WindowsIdentity]::GetCurrent().Name`；
- `USERNAME`、`USERPROFILE`；
- 进程、用户和机器范围的 `CODEX_HOME`；未设置时记录有效默认目录 `USERPROFILE\.codex`；
- PATH 中 Codex、Node、OpenAI 与 WindowsApps 相关条目的顺序。

`USERNAME` 或 `USERPROFILE` 相同不证明安全身份相同。`Administrator` 与 `CodexSandboxOffline` 等不同 Windows 身份可能看到同一路径，却不能使用同一份系统凭据库登录。

### 3. 只检查凭据元数据

- 只报告有效 `CODEX_HOME` 下 `auth.json` 是否存在及文件时间，不读取其正文；
- 只提取 `config.toml` 中 `cli_auth_credentials_store` 的值；未设置就明确写“未显式配置”，不要猜测当前版本的默认值；
- 解释 `file` 使用 `auth.json`，`keyring` 使用操作系统凭据库，`auto` 优先凭据库并可回退文件；
- `auth.json` 存在不证明当前 CLI 已登录，系统凭据库可用也与 Windows 安全身份有关。

### 4. 比较普通用户上下文

Agent 无法直接看到用户平常终端时，先完成 Agent 侧检查，再只要求用户在平常使用 Codex 的 PowerShell 执行最短只读命令：

```powershell
(Get-Command codex).Source; codex --version; codex login status; whoami
```

不得让用户手工展开复杂排查。若平台规则禁止代操作终端或认证界面，如实说明该边界。

## 判定路由

按证据选择且只选择能够成立的结论：

1. **同一 CLI，凭据上下文隔离**：普通终端与 Agent 指向同一安装和版本，普通终端已登录，Agent 未登录，且 Windows 安全身份不同。结论是不需要重复授权；真实账号调用应留在普通用户上下文，Agent 沙箱中的 `Not logged in` 不代表用户未登录。
2. **可能选错 CLI**：宿主与项目命中不同绝对路径或版本，且被项目选中的 CLI 未登录。建议为项目提供稳定、可验证的显式可执行文件配置；不要硬编码带版本号的 WindowsApps 包目录。
3. **宿主确实未登录**：普通用户上下文中的目标 CLI 也明确报告未登录。此时可以说明需要登录，但认证步骤必须由用户亲自完成。
4. **证据不足**：候选无法执行、普通终端环境不可见、版本或身份未核实。保持未知并给出一条最短的只读补充命令，不建议设备码授权。

## 结果要求

报告至少包含所选 CLI 的绝对路径、版本、当前上下文登录状态、Windows 安全身份、`USERPROFILE`、有效 `CODEX_HOME`、凭据存储配置和项目是否会选中它。最后明确回答：

- 是否真的选错 CLI；
- 证据是否足够；
- 当前是否需要登录或设备码授权；
- 修复应针对可执行文件选择、运行身份还是实际缺少登录。

若已证明是同一 CLI 的身份隔离，用一句通俗结论开头，例如：“你的 CLI 和登录都正常；只是 Agent 使用隔离身份，拿不到普通用户的登录凭据。”

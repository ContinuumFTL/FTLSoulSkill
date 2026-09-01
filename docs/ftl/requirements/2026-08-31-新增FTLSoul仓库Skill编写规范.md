# 新增 FTLSoul 仓库 Skill 编写规范

状态：执行完毕
建立时间：2026-08-31T19:15:17+08:00
确认时间：2026-08-31T19:22:07+08:00
执行完毕时间：2026-08-31T19:41:23+08:00

## 关联基线

- 直接关联：[2026-08-27-修正Codex登录诊断Skill归属.md](2026-08-27-修正Codex登录诊断Skill归属.md)。该历史需求已经确立“FTLSoulSkill 仓库是源码唯一事实来源，用户安装目录只保存受管目录链接”的原则。

## 背景与目标

此前部分会话在编写 `SKILL.md` 时按固定显示宽度插入了真实换行，导致源码阅读困难；Markdown 预览虽然会把段落内的单换行折叠为空白，但模型实际读取的仍是原始 Markdown。另有会话在其他项目中修改 FTLSoul Skill 时，直接使用 C 盘用户安装路径，而没有明确回到 `Z:\Code\FTLSoulSkill` 权威仓库路径开展编辑。

本次新增一个专门负责创建、修改、审查和格式化本仓库 Skill 的编写规范 Skill。它必须让后续会话稳定选择正确源码位置，保持适合源码阅读的 Markdown 排版，并在提交前执行可重复验证。

## 交付范围

- 新增 `skills/engineering/ftl-skill-authoring/SKILL.md`，Skill 名称为 `ftl-skill-authoring`。
- 在该 Skill 下提供必要的确定性校验脚本，用于发现 `SKILL.md` 正文中按固定宽度形成的段落或列表项续行；不创建无实际用途的占位资源。
- 更新 `skills/engineering/ftl-router/SKILL.md`，在创建、修改、审查或格式化 FTLSoul 仓库 Skill 时路由到 `ftl-skill-authoring`，但不让目标 Harness 自行批准治理语义变更。
- 更新 `README.md` 的 Skill 清单和相关架构说明，使新 Skill 可发现且职责描述一致。
- 不批量重写历史需求文档，不修改与本需求无关的 Skill 内容，不把本规范扩展为所有项目的通用 Skill 编写规则。

## 适用边界与触发

- 用户要求创建、修改、审查或格式化 `FTLSoulSkill` 仓库中的 Skill，或者请求直接涉及该仓库 `skills/` 下的内容时，使用 `ftl-skill-authoring`。
- 即使当前会话工作目录位于其他项目，只要目标是 FTLSoul Skill，仍应使用本规范并切换到已验证的 FTLSoul 权威源码仓库。
- 用户在其他项目中编写该项目自己的本地 Skill 时，不因系统中存在本 Skill 就强制改到 FTLSoul 仓库；除非用户明确要求把它纳入 FTLSoul。
- 本 Skill 负责仓库位置、编写质量、格式和验证，不替代 `ftl-router` 对只读讨论、需求确认、实施授权及 Harness 自修改边界的判断。
- 创建或修改治理语义时仍进入需求确认与外部执行路线；错字、格式、失效链接等可证明不改变语义的机械修正可以走明确小改动路线。

## 权威源码位置

- 本机当前唯一权威源码根目录是 `Z:\Code\FTLSoulSkill`。开始编辑前必须确认该路径存在、是 Git 工作树，并包含本仓库的 `AGENTS.md`、`README.md`、`scripts/link-skills.ps1` 和 `skills/`。
- `%USERPROFILE%\.agents\skills\ftl-*`、`%USERPROFILE%\.codex\skills\ftl-*`、插件缓存及其他 C 盘发现路径均视为安装、链接或缓存表面，不作为源码编辑目标。
- 当前受管链接清单 `C:\Users\Administrator\.agents\skills\.ftl-soul-skill-links.json` 的 `sourceRoot` 应指向 `Z:\Code\FTLSoulSkill`；安装路径即使是指向 Z 盘的符号链接，编辑命令和交付说明也必须使用 Z 盘规范路径。
- 若 Z 盘仓库不存在、签名文件不匹配、Git 根目录不符、受管清单指向其他来源或目标 Skill 只存在于 C 盘独立副本，停止编辑并报告冲突；不得为了继续任务而直接修改、复制或删除 C 盘内容。
- 只有用户明确变更并验证了新的 FTLSoul 权威 checkout，才能替换当前根目录约定；普通会话不能从当前工作目录、安装副本或缓存路径推断新的事实来源。
- 用户安装链接的创建、更新和清理只能通过仓库的 `scripts/link-skills.ps1` 完成，并受当前任务授权约束；修改源码不自动授权同步用户安装目录。

## Markdown 编写规范

- 普通 prose 段落采用“一个语义段落对应一个物理行”；不得按 80、100、120 列或编辑器窗口宽度插入硬换行。
- 每个无序或有序列表项采用一个物理行；不得仅因行长把同一列表项拆成缩进续行。真正的嵌套列表、代码块或独立段落仍使用 Markdown 所需结构。
- YAML frontmatter 的普通标量保持完整，不因显示宽度折行；长 `description` 仍保留为一个物理行。
- 标题、段落间空行、代码围栏、代码内容、表格、引用块及明确要求的 Markdown 硬换行不进行错误合并。
- 编辑器阅读时使用视觉软换行，不把视觉宽度写回文件。格式化工具可能改写 prose 时，必须选择保留或禁止 prose 硬折行的配置或调用方式。
- 不为满足格式规范改写措辞。纯格式修复必须能够证明除空白外的字符序列保持不变。

## 编写与验证流程

- 先读取当前项目规则、`ftl-router`、`skill-creator` 和目标 Skill 的完整内容，检查 Git 状态并保留其他任务已有改动。
- 新 Skill 的 frontmatter `name`、目录名和职责保持一致；`description` 必须准确说明适用任务和排除边界，使其他项目会话也能在目标涉及 FTLSoul Skill 时发现它。
- 只加入会改变模型决策的仓库专用规则；不复制通用 Skill Creator 手册，不创建 README、示例、资源目录或脚本占位符。
- 对新增或修改的 Skill 运行 Skill Creator `quick_validate.py`，在 Windows 中文环境中必要时使用 Python UTF-8 模式。
- 对整个仓库运行新增的 Markdown 排版校验，确认普通段落、列表项和 frontmatter 没有固定宽度续行，同时验证代码围栏等允许结构不会被误报。
- 运行 `scripts/link-skills.ps1 -WhatIf`，验证 Skill 名称唯一、frontmatter 可解析且新 Skill 能进入受管链接集合；除非用户另行授权，不执行实际用户目录同步。
- 执行 `git diff --check`、精确路径审计和与风险相称的内容复核。通过后由适用上游流程使用 `ftl-local-commit` 创建隔离的本地提交，不自动 push。

## 验收预期

- `ftl-skill-authoring` 的名称、目录、frontmatter 和说明通过 Skill Creator 校验，且 README 与路由引用一致。
- 从非 FTLSoul 项目发起“修改某个 FTLSoul Skill”的任务时，规范会要求验证并编辑 `Z:\Code\FTLSoulSkill`，不会把 C 盘安装或缓存路径当作源码根目录。
- 当 Z 盘仓库或受管来源存在冲突时，规范会停止并报告，不会回退修改 C 盘独立副本。
- 新写的普通中文或英文段落、列表项和 frontmatter 不会按固定列宽产生真实续行；编辑器可以通过视觉软换行保持可读性。
- 校验脚本能拒绝本次已经修复过的段落硬折行形态，并允许代码围栏、真正嵌套列表、表格、引用块和明确硬换行。
- 仓库现有全部 Skill 均能通过新增排版校验、Skill Creator 校验和链接预演；实施不改变现有 Skill 的授权、路由或生命周期语义，除新增的编写规范及其必要路由外。
- 实施提交只包含本需求允许的 Skill、校验脚本、路由、README 和需求生命周期更新；不修改 C 盘安装内容，不执行 push。

## 实施结果

- 已新增 `skills/engineering/ftl-skill-authoring/SKILL.md` 和 `skills/engineering/ftl-skill-authoring/scripts/validate-skill-markdown.ps1`，并通过 `ftl-router` 与 README 暴露仓库编写入口；实现检查点为 `5658227`（`feat: add FTLSoul skill authoring standard`）。
- 状态提交前审阅发现校验器相对路径可能被其他项目工作目录错误解析，已按检查点纪律创建前向修复 `ed5b609`（`fix: use canonical validator path in authoring skill`），将调用路径完整锚定到 Z 盘；未 amend 或 squash 已有提交。
- 新 Skill 将 `Z:\Code\FTLSoulSkill` 固定为本机权威源码根目录，要求验证 Git 根目录、仓库签名文件和受管 `sourceRoot`；C 盘用户目录、Codex Skill 目录及插件缓存均不得作为源码编辑目标，来源冲突时停止而不回退修改副本。
- 已安装的 `C:\Users\Administrator\.agents\skills\ftl-router` 经核对是指向 Z 盘路由器的受管符号链接，并能直接读取新规范的 Z 盘精确路径；因此即使没有修改 C 盘安装内容，其他项目会话通过现有路由器也能定位权威 Skill。
- 排版校验器已用负向夹具验证能够同时拒绝 frontmatter、普通段落和列表项续行，用正向夹具验证代码围栏、嵌套列表、表格、引用和显式 Markdown 硬换行不会误报；临时夹具及空目录均已清理。
- 仓库 10 个 Skill 均通过 Skill Creator `quick_validate.py` 和整仓 Markdown 排版校验；`scripts/link-skills.ps1 -WhatIf` 成功识别 `ftl-skill-authoring` 并完成预演，未写入清单或用户安装目录。
- `git diff --check`、提交后工作树检查、权威 Git 根目录与受管清单一致性检查均通过；实施未执行用户目录同步、push、合并、PR、部署、发布或历史改写。

---
name: ftl-skill-authoring
description: 为 FTLSoulSkill 仓库创建、修改、审查和格式化 Skill，从当前源码位置或受管安装清单确定并验证权威源码工作树，再执行仓库专用编写与 Markdown 校验；目标是 FTLSoul Skill 时即使当前会话位于其他项目也适用，不用于其他项目自己的 Skill。
---

# 编写 FTLSoul Skill

把 FTLSoul Skill 的源码位置、Markdown 排版和仓库验证固定在同一条可靠路径上。安装目录可以暴露 Skill，但不能取代版本库中的权威源码。

## 面向用户的表达

在产生本次任务的面向用户聊天文本前，完整读取并使用 `ftl-soul`；其适用范围和正式产物例外以该 Skill 为准。

## 保留任务路线

开始前读取当前项目规则和 `ftl-router`，确认当前请求属于只读讨论、需求形成还是明确实施；本 Skill 只补充 FTLSoul 仓库的源码位置、编写质量、排版与验证，不替代授权判断。请求创建或修改 FTLSoul 的治理语义时仍使用需求确认及适用执行器；只有能够证明不改变权威语义的错字、格式或失效链接修正才可走明确小改动路线。

完整读取并使用 `skill-creator` 编写或更新目标 Skill。只保留会改变模型决策的仓库专用内容，不复制通用手册，不创建没有真实用途的 README、示例、资源目录或占位脚本。

## 锁定权威源码

- 开始读取、编辑、差异审查、验证或提交前，运行当前已加载 `ftl-skill-authoring` 目录中的 `scripts/resolve-source-root.ps1`，把它唯一输出的规范化路径作为本次任务的 FTLSoul 权威源码根目录；后续路径都从该根目录拼接，不重新猜测来源。
- 解析器只接受两类确定来源：脚本自身位于有效 FTLSoul Git 工作树时使用该工作树；脚本从受管全局 Skill 链接调用时使用相邻 `.ftl-soul-skill-links.json` 中经过验证的 `sourceRoot`。解析器会核对 Git 根目录、仓库签名文件和 `ftl-skill-authoring` 目标，来源缺失、无效或冲突时必须停止。
- 不搜索磁盘，不根据当前会话工作目录随意选择同名仓库，也不把用户安装目录、Codex Skill 目录、插件缓存或独立复制的 Skill 当作可编辑源码。安装路径即使能读取 Skill，也只有解析器返回的 Git 工作树可以承载修改、差异和提交。
- 找不到有效来源时，提示用户从实际 FTLSoul 克隆目录运行 `scripts/link-skills.ps1`；用户安装链接只通过该脚本创建、更新或清理。源码修改不自动授权同步用户目录。

## 编写与排版

- 先检查 Git 状态、目标 Skill 的完整内容、调用者和相邻职责，保留其他任务已有改动。新 Skill 的目录名、frontmatter `name` 和职责必须一致，`description` 要准确区分适用任务与排除边界。
- 普通 prose 段落使用一个语义段落对应一个物理行，不按固定列数或编辑器窗口宽度插入硬换行。阅读长行时使用编辑器视觉软换行。
- 每个无序或有序列表项使用一个物理行，不因行长拆成缩进续行。真正的嵌套列表、独立段落和代码块继续使用 Markdown 所需结构。
- YAML frontmatter 的普通标量保持在一个物理行；长 `description` 不折行。标题、段落间空行、代码围栏、代码内容、表格、引用块和明确要求的 Markdown 硬换行保持其结构。
- 不为排版改写措辞。纯格式修复必须验证去除空白后的字符序列与修改前一致。

## 验证与提交

- 对新增或修改的 Skill 运行 `skill-creator` 提供的 `quick_validate.py`；Windows 默认编码不能读取 UTF-8 时使用 Python UTF-8 模式重跑，不把环境编码错误报告为 Skill 内容错误。
- 从解析后的源码根目录运行 `skills/engineering/ftl-skill-authoring/scripts/validate-skill-markdown.ps1`，检查该根目录下的整个 `skills/`。修复全部普通段落、列表项和 frontmatter 续行；代码围栏、真正嵌套列表、表格、引用块和明确硬换行不得误报。
- 从仓库根目录运行 `scripts/link-skills.ps1 -WhatIf`，验证 frontmatter、名称唯一性和受管链接集合；没有单独授权时使用隔离的预演目标，不实际同步用户目录。
- 运行 `git diff --check`，审计精确路径和实际差异，并执行与修改风险相称的内容或行为检查。验证通过后由适用上游流程使用 `ftl-local-commit` 创建隔离的本地提交；不得由源码编辑推导 push、合并、发布或其他外部动作。

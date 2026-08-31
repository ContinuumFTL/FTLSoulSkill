---
name: ftl-skill-authoring
description: 为 FTLSoulSkill 仓库创建、修改、审查和格式化 Skill，强制从已验证的 Z:\Code\FTLSoulSkill 权威源码工作树编辑并校验 Markdown 排版；目标是 FTLSoul Skill 时即使当前会话位于其他项目也适用，不用于其他项目自己的 Skill。
---

# 编写 FTLSoul Skill

把 FTLSoul Skill 的源码位置、Markdown 排版和仓库验证固定在同一条可靠路径上。安装目录可以暴露 Skill，但不能取代版本库中的权威源码。

## 面向用户的表达

在产生本次任务的面向用户聊天文本前，完整读取并使用 `ftl-soul`；其适用范围和正式产物例外以该 Skill 为准。

## 保留任务路线

开始前读取当前项目规则和 `ftl-router`，确认当前请求属于只读讨论、需求形成还是明确实施；本 Skill 只补充 FTLSoul 仓库的源码位置、编写质量、排版与验证，不替代授权判断。请求创建或修改 FTLSoul 的治理语义时仍使用需求确认及适用执行器；只有能够证明不改变权威语义的错字、格式或失效链接修正才可走明确小改动路线。

完整读取并使用 `skill-creator` 编写或更新目标 Skill。只保留会改变模型决策的仓库专用内容，不复制通用手册，不创建没有真实用途的 README、示例、资源目录或占位脚本。

## 锁定权威源码

- 本机 FTLSoul 唯一权威源码根目录是 `Z:\Code\FTLSoulSkill`。所有读取、编辑、差异审查、验证和提交路径都以这个规范路径为准，即使当前会话工作目录属于其他项目。
- 编辑前确认该目录是 Git 工作树根目录，并包含 `AGENTS.md`、`README.md`、`scripts/link-skills.ps1` 和 `skills/`。`git rev-parse --show-toplevel` 的规范化结果必须等于该目录。
- 若 `C:\Users\Administrator\.agents\skills\.ftl-soul-skill-links.json` 存在，读取其 `sourceRoot` 并确认同样指向 `Z:\Code\FTLSoulSkill`。清单缺失可以作为安装状态报告，但不得改变已经验证的源码根目录；清单指向其他来源则属于冲突，必须停止编辑。
- `%USERPROFILE%\.agents\skills\ftl-*`、`%USERPROFILE%\.codex\skills\ftl-*`、插件缓存和其他 C 盘发现路径都是安装、链接或缓存表面，不是源码编辑目标。即使某个路径当前是指向 Z 盘的符号链接，命令、差异和交付说明仍使用 Z 盘路径。
- Z 盘仓库不存在、签名文件不匹配、Git 根目录不符、受管来源冲突或目标只存在于 C 盘独立副本时，停止并报告；不得直接修改、复制或删除 C 盘内容。只有用户明确变更并验证新的 FTLSoul 权威 checkout 后，才能替换本机根目录约定。
- 用户安装链接只通过仓库的 `scripts/link-skills.ps1` 创建、更新或清理。源码修改不自动授权实际同步用户目录。

## 编写与排版

- 先检查 Git 状态、目标 Skill 的完整内容、调用者和相邻职责，保留其他任务已有改动。新 Skill 的目录名、frontmatter `name` 和职责必须一致，`description` 要准确区分适用任务与排除边界。
- 普通 prose 段落使用一个语义段落对应一个物理行，不按固定列数或编辑器窗口宽度插入硬换行。阅读长行时使用编辑器视觉软换行。
- 每个无序或有序列表项使用一个物理行，不因行长拆成缩进续行。真正的嵌套列表、独立段落和代码块继续使用 Markdown 所需结构。
- YAML frontmatter 的普通标量保持在一个物理行；长 `description` 不折行。标题、段落间空行、代码围栏、代码内容、表格、引用块和明确要求的 Markdown 硬换行保持其结构。
- 不为排版改写措辞。纯格式修复必须验证去除空白后的字符序列与修改前一致。

## 验证与提交

- 对新增或修改的 Skill 运行 `skill-creator` 提供的 `quick_validate.py`；Windows 默认编码不能读取 UTF-8 时使用 Python UTF-8 模式重跑，不把环境编码错误报告为 Skill 内容错误。
- 运行 `Z:\Code\FTLSoulSkill\skills\engineering\ftl-skill-authoring\scripts\validate-skill-markdown.ps1` 检查整个 `Z:\Code\FTLSoulSkill\skills`。修复全部普通段落、列表项和 frontmatter 续行；代码围栏、真正嵌套列表、表格、引用块和明确硬换行不得误报。
- 从仓库根目录运行 `scripts/link-skills.ps1 -WhatIf`，验证 frontmatter、名称唯一性和受管链接集合；没有单独授权时使用隔离的预演目标，不实际同步用户目录。
- 运行 `git diff --check`，审计精确路径和实际差异，并执行与修改风险相称的内容或行为检查。验证通过后由适用上游流程使用 `ftl-local-commit` 创建隔离的本地提交；不得由源码编辑推导 push、合并、发布或其他外部动作。

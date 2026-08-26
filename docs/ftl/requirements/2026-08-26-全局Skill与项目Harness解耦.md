# 全局 Skill 与项目 Harness 解耦

状态：已确认
建立时间：2026-08-26T17:02:41+08:00
确认时间：2026-08-26T17:08:17+08:00
吸收时间：未吸收
吸收记录：未吸收
执行完毕时间：未执行完毕

## 目标

调整 FTLSoul 全局工程工作流，使其负责通用的任务分类、需求澄清、执行授权和回退执行，同时发现并尊重当前项目真实声明的 Harness。全局 Skill 不把上一版 Copawlot 的 Planner、Generator、Evaluator、Milestone、Spec、Plan、Implementation 或 Eval 结构强加给其他项目。

保留“项目 Harness 治理机制本身是修改对象时，不能把该 Harness 作为自己替代规则的唯一执行器”这一通用原则；它只解决自修改循环，不把全局工作流描述成项目 Harness 的组成部分。

## 已达成的规则

1. `ftl-router` 继续区分只读分析、明确小改动、复杂需求和已确认需求执行，但以项目实际声明的工作流为准，不假定项目具有 Planner、Generator 或 Evaluator。
2. `ftl-simple-change` 继续拒绝绕过权威治理语义和项目已有执行流程，但不再以“当前有效 Plan”或固定角色状态机作为所有项目的通用准入条件。
3. `ftl-requirements` 的通用核心生命周期收敛为`编辑中`、`已确认`和`执行完毕`；项目若声明额外的吸收、规划或评估状态，全局 Skill 只识别并遵循，不把它们设为默认必经状态。
4. `ftl-requirements-execution` 在项目存在适用于当前需求的执行工作流时交由该工作流；项目没有适用执行器时才作为全局回退。直接修改项目 Harness 治理机制时保留外部执行例外。
5. 新需求文档继续统一写入 `docs/ftl/requirements/YYYY-MM-DD-简短标题.md`。这一全局约定优先于项目自定义的新需求目录；维护既有需求时仍原地更新。
6. `README.md` 明确区分 Codex 用户环境中的全局 FTLSoul Skills 与仓库内部的项目 Harness，并更新路由关系和需求生命周期说明。
7. 不回退历史提交。以当前 `main` 为基础创建新的前向重构提交，保留后来已经形成的授权、验证、本地检查点和历史需求保护规则。

## 修改范围

- `skills/engineering/ftl-router/SKILL.md`
- `skills/engineering/ftl-simple-change/SKILL.md`
- `skills/engineering/ftl-requirements/SKILL.md`
- `skills/engineering/ftl-requirements-execution/SKILL.md`
- `README.md`

安装目录 `C:\Users\Administrator\.agents\skills\` 当前通过符号链接指向本仓库，不单独编辑。`AGENTS.md`、`ftl-local-commit`、`ftl-soul`、链接脚本和 AI commit 脚本不在修改范围。

## 验收预期

- 四个工程工作流 Skill 不再把 Planner、Generator、Evaluator、Milestone、Spec、Plan、Implementation、Eval 或`吸收完毕`描述为所有项目都具有的固定机制。
- 项目声明的适用工作流优先，全局回退和 Harness 自修改例外的触发条件互不冲突。
- 简单改动不能绕过项目权威规则，需求确认仍不自动授权执行，执行结果仍需相称验证。
- 新需求目录仍固定为 `docs/ftl/requirements/`，已有历史需求不迁移或重写。
- README 的职责说明和流程图与四个 Skill 一致，不把全局 Skill 归入任一项目 Harness。
- 仓库检查和 Skill 元数据检查通过；最终差异不包含 Copawlot-ai 仓库文件或安装目录副本。

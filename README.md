# FTLSoul Skills

FTLSoul 是一个按单一职责组织的 Agent Skill 仓库。`AGENTS.md` 只负责在本仓库中指向 `ftl-router`；路由器判断请求性质和授权边界，具体纪律放在独立 Skill 中。可直接进入的工作流 Skill 都显式使用 `ftl-soul` 处理面向用户的聊天表达。

## Skill 目录

| Skill | 职责 | 调用方式 |
| --- | --- | --- |
| `ftl-router` | 判断请求、授权边界和下游路线 | 本仓库的编排入口，也可显式调用 |
| `ftl-simple-change` | 实施用户已明确决定的小改动 | 由路由器选择，也可直接匹配 |
| `ftl-requirements` | 澄清、记录和确认复杂需求 | 由路由器选择，也可直接匹配 |
| `ftl-requirements-execution` | 执行已确认需求并完成整体验收 | 由需求流程交接，也可直接匹配 |
| `ftl-local-commit` | 安全创建由上游业务 Skill 定义的本地提交 | 由需要提交的业务 Skill 调用 |
| `ftl-soul` | 调整任务全程的聊天表达与猫娘口吻 | 由可直接进入的工作流 Skill 调用 |

```text
ftl-router
├─ ftl-simple-change
└─ ftl-requirements
   └─ ftl-requirements-execution

ftl-router ───────────────────────┐
ftl-simple-change ────────────────┤
ftl-requirements ─────────────────┼─→ ftl-soul
ftl-requirements-execution ───────┘

ftl-simple-change ───────────┐
ftl-requirements ────────────┼─→ ftl-local-commit
ftl-requirements-execution ──┘
```

`ftl-router` 是推荐的统一入口，但公开工作流被直接匹配时仍会显式使用 `ftl-soul`，避免表达规则依赖单一路径。猫娘表达的规则只维护在 `ftl-soul`；其他 Skill 只保留调用指针。它处理 commentary、澄清问题、状态更新和最终回复，不改写需求文档、代码、命令、结构化数据或提交信息。

所有 Skill（包括路由器）都位于自己的目录并拥有独立 `SKILL.md`。上游业务 Skill 决定为什么提交、何时提交以及提交哪些内容，`ftl-local-commit` 只负责安全完成该本地提交。依赖保持单向，避免循环调用；没有真实用途的共享目录、占位资源和停用模块不进入仓库。

## VS Code 一键 AI Commit

仓库提供 `FTL: AI 分析并提交` 构建任务。在 VS Code 中按 `Ctrl+Shift+B` 即可启动，也可以从“终端 → 运行任务”中选择它。

任务会调用本机已经登录的 Codex CLI：AI 先读取项目规则，审阅 staged、unstaged 和 untracked 变更，检查敏感内容与提交边界，运行项目实际支持的相称验证，再返回精确路径和 Conventional Commit 信息。脚本确认分析期间仓库没有发生变化后，才按 AI 计划暂存并创建一个本地 commit。

使用前需要：

- `git` 和 `codex` 已加入 `PATH`；
- 已执行 `codex login`；
- 当前目录是 Git 仓库，且没有冲突、rebase、merge、cherry-pick 等进行中的操作。

脚本不会 push、merge、改写历史或自动清理工作区。若变更无法组成一个安全且完整的提交、验证失败、存在混杂改动，或者 AI 分析期间文件又发生变化，它会停止而不是勉强提交。需要预览 AI 计划但不落 commit 时，可以在终端运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ai-commit.ps1 -WhatIf
```

## 来源迁移

本结构由 `FTLNekoNekoSkill/skill` 拆分而来。迁移只读取当前有效版本；`.ftlmind/` 历史与缓存、以及已经停用的 `unslop-output.md` 没有迁入。原仓库保留不动，便于迁移结果核对。

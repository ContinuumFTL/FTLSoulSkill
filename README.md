# FTLSoul Skills

FTLSoul 是一个按单一职责组织的 Agent Skill 仓库。`AGENTS.md` 只负责指向 `ftl-router`；路由器判断请求性质和授权边界，具体纪律放在独立 Skill 中。

## Skill 目录

| Skill | 职责 | 调用方式 |
| --- | --- | --- |
| `ftl-router` | 判断请求、授权边界和下游路线 | 由 `AGENTS.md` 指向的编排入口 |
| `ftl-simple-change` | 实施用户已明确决定的小改动 | 由入口调用 |
| `ftl-requirements` | 澄清、记录和确认复杂需求 | 由入口调用 |
| `ftl-requirements-execution` | 执行已确认需求并完成整体验收 | 由需求流程交接 |
| `ftl-local-commit` | 安全创建由上游业务 Skill 定义的本地提交 | 由需要提交的业务 Skill 调用 |
| `ftl-soul` | 调整最终表达与猫娘口吻 | 最终输出前调用 |

```text
ftl-router
├─ ftl-simple-change
├─ ftl-requirements
│  └─ ftl-requirements-execution
└─ ftl-soul

ftl-simple-change ───────────┐
ftl-requirements ────────────┼─→ ftl-local-commit
ftl-requirements-execution ──┘
```

所有 Skill（包括路由器）都位于自己的目录并拥有独立 `SKILL.md`。上游业务 Skill 决定为什么提交、何时提交以及提交哪些内容，`ftl-local-commit` 只负责安全完成该本地提交。依赖保持单向，避免循环调用；没有真实用途的共享目录、占位资源和停用模块不进入仓库。

## 来源迁移

本结构由 `FTLNekoNekoSkill/skill` 拆分而来。迁移只读取当前有效版本；`.ftlmind/` 历史与缓存、以及已经停用的 `unslop-output.md` 没有迁入。原仓库保留不动，便于迁移结果核对。

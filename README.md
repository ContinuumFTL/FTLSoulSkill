# FTLSoul Skills

<p align="center">
  <img src="assets/neko.png" alt="FTLSoul 猫猫" width="720">
</p>

FTLSoul 是一个按单一职责组织的用户级 Agent Skill 仓库。它运行在具体项目 Harness 之外，负责通用的任务分类、需求澄清、执行授权和回退执行；进入项目后先读取并尊重项目实际声明的规则，不把 FTLSoul 角色或生命周期描述成项目 Harness 的组成部分。

本仓库的 `AGENTS.md` 只负责指向 `ftl-router`；路由器判断请求性质和授权边界，具体纪律放在独立 Skill 中。可直接进入的工作流 Skill 都显式使用 `ftl-soul` 处理面向用户的聊天表达。

## Skill 目录

| Skill | 职责 | 调用方式 |
| --- | --- | --- |
| `ftl-router` | 区分只读讨论、形成需求和明确实施，并选择项目工作流或全局回退路线 | 本仓库的编排入口，也可显式调用 |
| `ftl-skill-authoring` | 约束 FTLSoul Skill 的权威源码位置、Markdown 排版和仓库验证 | 创建、修改、审查或格式化 FTLSoul Skill 时由路由器选择，也可直接匹配 |
| `ftl-codex-sandbox-auth-recovery` | 宿主 Codex 已登录而 Agent 沙箱报告未登录时，把已授权的 Codex 父命令恢复到宿主用户上下文 | 由路由器在已知沙箱凭据隔离故障时选择，也可直接匹配 |
| `ftl-simple-change` | 实施未被项目专用工作流接管的明确小改动 | 由路由器选择，也可直接匹配 |
| `ftl-vscode-launch` | 为项目创建、合并并验证 VS Code 一键启动配置 | 用户要求配置 F5、Run and Debug 或复用 launch.json 规则时直接匹配 |
| `ftl-requirements` | 澄清、记录和确认复杂需求；选择 B 后以自包含目标交给实际执行器 | 由路由器选择，也可直接匹配 |
| `ftl-requirements-execution` | 在没有适用项目工作流或目标 Harness 正被修改时执行已确认需求，并处理目标中的人工验收关口 | 由需求流程交接，也可直接匹配 |
| `ftl-local-commit` | 安全创建由上游业务 Skill 定义的本地提交 | 由需要提交的业务 Skill 调用 |
| `ftl-soul` | 调整任务全程的聊天表达与猫娘口吻 | 由可直接进入的工作流 Skill 调用 |
| `ftl-browser` | 为交互式网页任务选择执行路径，确需网页 UI 时默认使用 Codex 内置浏览器 | 由路由器在实际网页交互时选择，也可直接匹配 |

```mermaid
flowchart TD
    U[用户请求] --> R[ftl-router]
    R --> CA{宿主已登录而沙箱未登录}
    CA -->|是| AR[ftl-codex-sandbox-auth-recovery]
    CA -->|否| P[读取项目规则与真实状态]
    AR -->|立即恢复当前命令| HR[宿主用户上下文]
    AR -->|长期修复项目| P
    P --> K{请求性质}
    P -.目标是 FTLSoul Skill.-> SA[ftl-skill-authoring]

    K -->|只读讨论| A[调查并回答]
    K -->|形成需求| Q[ftl-requirements]
    K -->|明确实施| I{实施性质}

    I -->|明确小改动| S[ftl-simple-change]
    I -->|明确但不是小改动| NW{项目是否声明适用工作流}
    I -->|执行已确认需求| V[ftl-requirements：核对状态与版本]
    I -->|修改项目 Harness 治理机制| Q

    NW -->|是| H
    NW -->|否| Q
    V --> W{项目是否声明适用工作流}

    Q --> C{用户选择}
    C -->|继续讨论| Q
    C -->|A：确认定稿| D[确认需求文档]
    C -->|B：确认并执行| D
    D --> LC[ftl-local-commit：需求确认]
    LC --> X{是否有明确执行授权}
    X -->|否| Z[仅完成需求确认]
    X -->|是| W

    W -->|是| GH[创建自包含 /goal]
    W -->|否| GE[创建自包含 /goal]
    W -->|目标 Harness 正被修改| GE
    GH --> H[项目自己的 Harness 工作流]
    GE --> E[ftl-requirements-execution]

    S --> L[ftl-local-commit：实现检查点]
    E --> L

    P -.实际网页交互.-> B[ftl-browser]
    R -.聊天表达.-> N[ftl-soul]
    AR -.聊天表达.-> N
    B -.聊天表达.-> N
    SA -.聊天表达.-> N
    S -.聊天表达.-> N
    Q -.聊天表达.-> N
    E -.聊天表达.-> N
```

三条顶层路线按用户当前意图区分。项目话题、计划是否具体、是否存在设计取舍都不会自动把普通讨论升级成需求流程：自由探讨保持只读；只有用户明确希望形成后续工作依据或维护需求文档时才进入 `ftl-requirements`；明确实施后再按范围选择小改动、项目工作流或已确认需求执行。

实际需要打开、导航或操作网页 UI 时，路由器调用 `ftl-browser`。它先判断专用连接器、API
或 CLI 是否能够完成语义操作；确需浏览器时默认只使用 Codex 内置浏览器，不会静默切换到
Chrome 或 Edge，也不会为同一登录或设备授权流程同时打开两个浏览器。内置浏览器无法完成时，
先说明失败并等待用户决定是否切换。普通互联网资料检索不走这条交互式浏览器路径。

用户选择 `B：确认定稿并执行` 后，FTLSoul 先确认并提交需求文档、解析实际执行器，再创建
自包含的 `/goal`；目标正文包含文档路径、执行授权、执行器、停止条件和授权边界，不能只是
一个 `B`。目标遇到人工验收时先冻结待测状态，自动续跑每回合只做一次直接相关的最小权威
检查；用户用普通自然语言返回结果后，当前回合把它作为原目标证据并继续剩余工作。

普通 Windows 终端中的目标 Codex CLI 已登录、但 Agent 沙箱或其子进程对同一 CLI 报告 `Not logged in` 或要求设备码时，路由器直接调用 `ftl-codex-sandbox-auth-recovery`。该 Skill 不再展开完整诊断，而是先在宿主上下文做一次无模型的最短登录检查，然后把真正启动 Codex 的整个父级项目命令放到已登录的宿主用户上下文执行。它不会重新登录、复制凭据，或把仅更换 `codex.ps1`、`codex.cmd`、`codex.exe` 包装器当成修复。

图中的“项目自己的 Harness 工作流”属于目标项目，不属于 FTLSoul。项目存在 `AGENTS.md`、测试或某类文档并不自动证明存在适用执行器；只有项目规则和真实入口明确承担当前任务时才交接。项目 Harness 治理机制本身是修改对象时，全局执行器保留在目标规则之外，避免要求旧规则吸收或批准自己的替代方案。

`ftl-router` 是推荐的统一入口，但公开工作流被直接匹配时仍会显式使用 `ftl-soul`，避免表达规则依赖单一路径。猫娘表达的规则只维护在 `ftl-soul`；其他 Skill 只保留调用指针。它处理 commentary、澄清问题、状态更新和最终回复，不改写需求文档、代码、命令、结构化数据或提交信息。

所有 Skill（包括路由器）都位于自己的目录并拥有独立 `SKILL.md`。上游业务 Skill 决定为什么提交、何时提交以及提交哪些内容，`ftl-local-commit` 只负责安全完成该本地提交。依赖保持单向，避免循环调用；没有真实用途的共享目录、占位资源和停用模块不进入仓库。

编写 FTLSoul Skill 时使用 `ftl-skill-authoring`。本机权威源码根目录是 `Z:\Code\FTLSoulSkill`；C 盘用户 Skill 目录和插件缓存只作为安装或发现表面，即使当前是指向 Z 盘的目录链接，编辑、差异和提交仍使用 Z 盘规范路径。普通 Markdown 段落和列表项保持一个语义块一个物理行，不按固定显示宽度硬折行；仓库内置校验脚本会在提交前检查这一约束。

## 生成文档

`ftl-requirements` 新建的需求文档统一写入 `docs/ftl/requirements/`，文件名使用 `YYYY-MM-DD-简短标题.md`。只有用户在当前请求中明确指定其他位置时才改变新文档路径；项目自定义目录不会覆盖这项全局约定。既有需求文档继续原地维护，不会因目录规范更新而被自动迁移或重命名。

新文档的默认生命周期是`编辑中`、`已确认`和`执行完毕`。项目可以声明额外状态和工作流；FTLSoul 只在当前任务实际适用时遵循，不把某个项目的规划、吸收或评估结构推广到其他项目。

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

## 许可证

本项目采用 [Apache License 2.0](LICENSE) 开源许可证。

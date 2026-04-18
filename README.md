# claude-codex-orchestration

> Claude Code 作为 Tech Lead（总控），Codex 作为 Parallel Implementer（并行实现者），双 Agent 协同编码 skill。自包含运行（无强制外部插件依赖），可选集成 caveman / compound-engineering / superpowers 进一步增强。跨 harness 可用（Claude Code / Cursor / Codex / OpenCode）。

---

## 核心思路

```
Claude Code（Tech Lead）
    │
    ├─ 仓库探索、架构设计、需求拆分
    ├─ 后端逻辑、脚本、CI/CD、迁移
    ├─ 最终集成、回归测试、发布
    │
    └─▶ Codex（Parallel Implementer）
            ├─ 前端页面、UI 交互
            ├─ 独立 feature 模块实现
            ├─ 并行方案试解
            └─ 当前 diff review
```

**铁律：** 任何时候不允许两个 Agent 同时写同一个文件。

---

## 八大能力层

| 层 | 核心能力 |
|----|----------|
| 1. 跨 Harness 环境 | 4 种 harness 检测 + 配置映射 + hook 翻译 + AGENTS.md 通用基线 |
| 2. Token 预算 | 三档内联压缩（lite/full/ultra），阶段化上下文预算，compact-guard |
| 3. 规划与分派 | Phase 0 理解 → Execution Plan → Codex 调用协议（XML 结构化 prompt） |
| 4. Codex Co-Decision | CC 问题先路由到 Codex，置信度门控升级，减少 human-in-loop |
| 5. 安全与质量 | Smart Tool RAG、质量追踪（滚动 20 窗）、安全门、任务板原子认领 |
| 6. 思考与决策 | `/co:think`（产品/技术双模式）、`/co:plan-review`（CEO 级 4 模式） |
| 7. 工程原则 | Hyrum's Law、Beyoncé Rule、测试金字塔、Chesterton's Fence、Trunk-Based、Shift Left、Feature Flag、Deprecation |
| 8. 自我纠错与知识复利 | 三层自我纠错（eval/capture/promote）、darwin 棘轮、`/co:compound` 知识沉淀 |

---

## 安装

skill 放在 `~/.claude/skills/`，Claude Code 全局自动发现，无需 per-project 配置。

```bash
git clone https://github.com/dy9759/claude-codex-orchestration ~/.claude/skills/claude-codex-orchestration
```

**必需：**
- Claude Code CLI
- `codex@openai-codex` plugin（Codex 调度底层）

**可选增强（skill 无强依赖，未安装时自动走内联 fallback）：**

| 插件 | 能力增强 |
|------|----------|
| `superpowers@claude-plugins-official` | worktree 自动化、并行 subagent 分发 |
| `caveman` | 更深度输出 token 压缩 + 输入压缩工具 |
| `compound-engineering` | 更丰富的知识沉淀 subagent 流水线 |

**会话启动自动检测：** 第一次使用时自动扫描已安装插件，缺失的一次性提示安装链接，sentinel 文件避免重复打扰。

---

## 使用方式

```
使用 claude-codex-orchestration skill，帮我实现 <你的需求>
```

Claude Code 会自动：
1. 探索仓库，理解影响范围
2. 输出 Execution Plan（含 CC/Codex 分工、worktree、subagent 决策）
3. 等你确认后并行执行
4. 集成双方输出，输出验证结论

**前置可选：** 遇到复杂任务时先 `/co:think`（前置思考）或 `/co:plan-review`（计划审核）。

---

## 执行流程

```
Phase 0   理解任务
          ↓
          输出 Execution Plan（压缩格式，等用户确认）
          ↓
Phase 1   并行执行
          ├─ CC 处理主线任务
          └─ Codex 处理独立模块（task spec <200 词，XML 结构化）
          ↓
Phase 2   集成
          └─ 差异审查 → 回归检查 → 测试 → 最终结论
```

---

## 1. 跨 Harness 环境层

同一套编排逻辑可在 Claude Code、Cursor、Codex、OpenCode 中使用。

**Harness 检测：** 会话启动时通过 env var 或文件存在性判断当前 harness。

**配置映射表（部分）：**

| 概念 | Claude Code | Cursor | Codex | OpenCode |
|------|-------------|--------|-------|----------|
| 全局规则 | `~/.claude/CLAUDE.md` | `.cursorrules` | `AGENTS.md` | `opencode.json` |
| 项目规则 | `CLAUDE.md` | `.cursor/rules/*.mdc` | `AGENTS.md` | `.opencode/instructions/` |
| Skills | `~/.claude/skills/*.md` | `.cursor/skills/` | 无 | `.opencode/prompts/` |
| Hooks | `settings.json` | `.cursor/hooks.json` | `.codex/config.toml` | `.opencode/` events |

**AGENTS.md 作为通用基线** — 4 种 harness 都读它。用 AGENTS.md 放角色定义、工具权限、阻断文件模式等跨 harness 规则。

**Hook 翻译表：** `PreToolUse ↔ beforeShellExecution ↔ approval_policy` 等效映射。

---

## 2. Token 预算层（内联压缩）

所有 Agent 内部通信（执行计划、状态更新、Codex 任务说明、集成报告）默认使用 `full` 级内联压缩，削减约 75% 输出 token。

| 级别 | 风格规则 |
|------|----------|
| `lite` | 只去废话，保持完整句子 |
| `full` | 省略冠词，碎句 OK，短同义词（**默认**） |
| `ultra` | 缩写（DB/fn/impl/env），箭头因果（X → Y），极度紧张时用 |

**永远不压缩：** 代码块、安全警告、不可逆操作确认、最终交付物。

**阶段化上下文预算：** Phase 0 < 20% · 并行执行 < 60% · 集成 < 80% · Push < 90%。

**compact-guard：** compaction 前保存 5 个关键文件，因为只有 5 个能熬过压缩。

**身份重注入：** compaction 恢复后 CC 必须重注入自己的角色，否则会忘记 Codex 正在做什么而重复工作。

---

## 3. 规划与分派层

### 默认分工

| Claude Code 负责 | Codex 负责 |
|-----------------|-----------|
| 仓库探索与架构设计 | 前端页面、UI、交互细节 |
| 后端逻辑、API、数据流 | 截图/设计稿驱动的修复 |
| 脚本、迁移、CI/CD | 独立 feature 模块实现 |
| 高风险/跨模块改动 | 并行方案试解 |
| 最终集成与发布前检查 | 当前 diff review |

### Codex 调用协议

**前台/后台：**
- 小任务、< 10 分钟 → 前台阻塞
- 复杂多步任务 → 后台返回 `job-id`，CC 继续干其他事，稍后用 `result` 拉取

**Thread 持久化：**
- 新任务：不加 `--resume-last`
- 延续同一工作（"continue"、"dig deeper"）：加 `--resume-last`，只发增量指令
- 强制开新 thread：加 `--fresh`

**写权限和 effort：**
| 任务类型 | flags | sandbox |
|---------|-------|---------|
| 实现/改 bug | `--write` | `workspace-write` |
| review/诊断/调研 | 无 | `read-only` |
| 简单 UI | `--effort low` | — |
| 复杂后端/架构 | `--effort high` | — |
| 深度诊断 | `--effort xhigh` | — |

**XML 结构化 Prompt**（< 200 词）：
```xml
<task>[具体任务 + 完成标准]</task>
<structured_output_contract>[期望返回格式]</structured_output_contract>
<default_follow_through_policy>[遇到问题该怎么决策]</default_follow_through_policy>
<verification_loop>[实现任务必填]</verification_loop>
<grounding_rules>[review 任务必填]</grounding_rules>
<action_safety>[write 任务必填]</action_safety>
```

**结果处理铁律：**
- Codex 返回的 review 发现：**STOP**，不自动应用，明确询问用户修哪个
- Codex 失败：如实报告，不拿 CC 的答案顶替
- 从未调用 Codex：什么都不返回，不编造

---

## 4. Codex Co-Decision 协议

当 CC 本来要停下来问用户时 → **先路由到 Codex**，保持用户输入流不中断。

**流程：**
1. CC 组装问题 + 上下文（< 150 词）
2. 派发 Codex（read-only，`--effort medium`）
3. Codex 返回 `recommendation + rationale + confidence(high/medium/low)`
4. CC 按置信度决策：
   - `high` → 直接执行，计划里提 Codex 理由
   - `medium` → 执行 + 在计划里标注假设
   - `low` 或与已知约束冲突 → 向用户升级，附带 Codex 建议

**禁用场景：** 安全决策、不可逆操作、Dispatch Security Gate 的阻断项——这些必须用户确认。

**升级格式（一句话）：** "两个选择——[A] 或 [B]。Codex 倾向 [X] 因为 [一句话]。你决定。"

---

## 5. 安全与质量层

### Smart Tool RAG（中途技能检索）

卡住时，先在 `~/.claude/skills/` + `docs/solutions/` 做双阶段检索：

```
BM25 粗排（name + description + body[:2000]）
    ↓  top candidates（skills ≤ 10 时跳过粗排）
Semantic 精排（概念相似度 + 质量信号）
    ↓  quality filter：有 ≥ 2 次 dispatch/integration 错误的技能降权
    ↓
注入技能指导，继续执行
```

### Codex 质量追踪

| 指标 | 健康 | 警告 | 行动 |
|------|------|------|------|
| 成功率（滚动 20 次） | ≥ 70% | 40–70% | 收紧 spec 模板 |
| 平均 spec 字数 | < 150 | > 200 | 发送前压缩 |
| 连续失败 | 0–2 | 3+ | 暂停派发，诊断根因 |

**惩罚因子：** 成功率 < 40% → 强制显式列文件，范围减半；连续 3+ 失败 → 硬停。
**语义失败注入：** 集成阶段的 scope-creep / 尺寸违规 / 无关改动 = 硬失败同权重。

### 派发安全门

每次 Codex dispatch 前扫描 task spec：

**默认封锁（只允许 CC 执行）：**
- 数据库迁移 / 环境变量 / 包依赖文件 / CI/CD / 密钥 / 强制删除 / git 历史改写

**高风险（需用户明确确认，不用压缩格式）：**
- 批量重命名 / 跨模块 import / 测试套件修改 / 共享配置文件

### 任务板（多 Codex 并行）

`.tasks/*.json`，原子认领 `owner` 字段防止双写。集成阶段审计无重叠。

### Worktree

- 每 worktree 只有一个主写入者
- 命名 `feature/<agent>-<描述>`
- 合并前 diff 审查 → cherry-pick 或手动集成
- 生命周期 ≤ 1–3 天（Trunk-Based）

---

## 6. 思考与决策层

### `/co:think` — 前置思考（office-hours 风格）

**产品/设计模式**（新功能、API 设计）—— 5 问一问一答：
1. 最窄能证明核心的版本是什么？
2. 这是给谁用？他们现在在做什么替代？
3. 最可能的失败模式？
4. 资深工程师会说哪里不必要？
5. 如果只有 2 小时做 demo，你做什么？

**技术/方案模式**（实现不清）—— 4 问：
1. 最酷的版本长什么样？
2. 现有什么代码/模式能给到你 50%？
3. 无限时间会加什么？（再残忍砍掉）
4. 验证可行的最快路径？

**Premise Challenge（强制，问完之后）：**
```
PREMISES:
1. [陈述] — valid / questionable
2. [假设] — valid / questionable
```

**可选：Codex cold read** — 组装上下文递给 Codex，得到独立第二意见。

### `/co:plan-review` — Execution Plan 战略审核（CEO review 风格）

4 种模式（选其一）：

| 模式 | 姿态 |
|------|------|
| **EXPAND** | 做大 — 10 倍版本是什么？推动范围向上 |
| **SELECTIVE** | 守住基线 + 通过 AskUserQuestion 逐项 cherry-pick 扩展 |
| **HOLD** | 让当前计划无懈可击——找出每一个失败模式 |
| **REDUCE** | 最小可行版本——砍掉一切非核心 |

**Prime Directives（所有模式都应用）：**
1. Zero silent failures — 每个失败模式对系统/团队/用户都可见
2. Every error has a name — 不允许笼统 catch-all
3. Data flows have shadow paths — 新数据流必追踪 nil/empty/upstream-error 三条影子
4. Interactions have edge cases — 双击、导航中断、慢连接、stale 状态
5. Observability is scope — 新路径必须有 log/metric/trace
6. Everything deferred is written down — TODOS.md 或视为不存在
7. Security is scope — 新路径必须威胁建模

**铁律：** 任何 scope 改动必须经 AskUserQuestion 显式同意，不允许静默增删。

---

## 7. 工程原则层

| 维度 | 规则 |
|------|------|
| **Common Rationalizations** | "太简单不用测"、"以后再重构"、"只是配置"、"Feature flag 太复杂" 等话术一律拒绝 |
| **API 设计（Hyrum's Law）** | 有足够用户后，所有可观察行为都会被依赖。暴露即契约 |
| **测试（Beyoncé Rule）** | 值得保留的行为必有测试。Bug 修复必先写复现测试 |
| **测试金字塔** | 单元 80% / 集成 15% / E2E 5%。集成或 E2E 过重 → 违规 |
| **Change Sizing** | ≤ 100 行好 / ≤ 300 行可 / > 1000 行必须拆 |
| **Five-Axis Review** | Correctness / Readability / Architecture / Security / Performance |
| **Chesterton's Fence** | 删之前必先理解它为什么存在 |
| **Trunk-Based Dev** | 分支 ≤ 1–3 天，优先 feature flag 而非长期分支 |
| **Shift Left** | 提交时跑 lint + type check + test，不等到部署 |
| **Feature Flags** | 新功能 OFF → team → 5% → 25% → 50% → 100% → cleanup |
| **Deprecation** | Advisory/Compulsory 区分，Strangler/Adapter/Feature-Flag 三种迁移策略，Churn Rule |

---

## 8. 自我纠错 + 知识复利层

### Layer 1 — 会话自评 `/co:eval`

**双轴评分矩阵（锁定，不可改）：**

|                        | Poor | Adequate | Strong |
|------------------------|:----:|:--------:|:------:|
| **Low Ambition**       |  1   |    2     |   2    |
| **Medium Ambition**    |  2   |    3     |   4    |
| **High Ambition**      |  2   |    4     |   5    |

**强制魔鬼辩护：** 打分前必须分别论证 LOWER 和 HIGHER，再解决分歧。
**防通胀：** 最近 5 次 4 次同分 → 警告强制重评。
**锁定评估器：** 矩阵不可改（来自 karpathy/autoresearch）——分数不舒服只能走辩护，不能改矩阵。

### Layer 2 — 错误自动捕获

失败立即写入 `.error-log.jsonl`：
| 类型 | 触发 |
|------|------|
| `dispatch` | task spec 太模糊，Codex 跑偏 |
| `conflict` | 双 Agent 文件冲突 |
| `integration` | Codex 输出被拒 |
| `scope-creep` | Codex 改了范围外文件 |
| `token` | 压缩无效 |

### Layer 3 — 审查 + 晋升 `/co:review` + `/co:promote`

- 每 5 会话扫日志，找 2+ 次重复的弱点/根因
- 候选打分：Durability + Impact + Scope（各 0–3）
- **总分 ≥ 6 → 晋升到 SKILL.md**；4–5 观察；≤ 3 忽略
- 描述性 → 规范性：❌"Codex 总跑偏" → ✅"spec > 200 词必须先压缩"
- **棘轮规则：** 下一次同维度评分改善才保留，否则回滚

### 自主循环 `/co:loop`

- 运行 `/co:eval` + `/co:review` → 候选 ≥ 6 → `/co:promote` → commit
- `ScheduleWakeup` 270s（保持在 cache TTL 内）调度下一轮
- 绝不主动停止询问——持续到被中断

**策略升级：** 5/8/12/15+ 轮卡同一弱点 → 微调 / 段重写 / 激进重构 / 标记用户。

### 知识复利 `/co:compound`

**Full 模式 4 个并行 subagent：**
| Agent | 职责 |
|-------|------|
| Context Analyzer | 分类 problem_type、track、suggest filename |
| Solution Extractor | Bug 轨道或 Knowledge 轨道提取 |
| Related Docs Finder | `docs/solutions/` 搜索重叠，打分 High/Moderate/Low |
| Session Historian | 搜历史会话（`~/.claude/projects/` + `~/.codex/sessions/`） |

**Phase 2 重叠决策：** High → 更新旧文档；Moderate → 新文档 + flag；Low → 新文档。
**Phase 2.5 选择性 Refresh（内联 5 步）：** 读冲突文档 → 引用原文 → 标 Superseded → 追加 Changelog → 不重写。
**发现性检查：** 确保 AGENTS.md/CLAUDE.md 有指向 `docs/solutions/` 的一行。

### `/co:sessions` — 跨会话历史检索

通过内置 Agent tool 派发 general-purpose subagent，扫历史会话找：prior approaches、dead ends、key decisions。避免重复跑失败的路。

---

## Invocation Prompts（不是已注册的 slash command）

> **注意：** 下表的 `/co:*` 是 **记忆 prompt**，不是已注册的 Claude Code 命令。在聊天里输入 `/co:eval` 或"跑 co:eval"，CC 按 SKILL.md 里对应章节执行。不会出现在命令补全里。

| Prompt | 时机 |
|--------|------|
| `/co:think` | 复杂/模糊任务前置思考 |
| `/co:plan-review` | Execution Plan 草拟后战略审核 |
| `/co:eval` | 每次会话结束评分 |
| `/co:review` | 每 5 会话回顾错误日志 |
| `/co:promote` | `/co:review` 识别出 ≥ 6 分候选后晋升 |
| `/co:loop` | 开启自主后台打磨循环 |
| `/co:compound` | 解决非平凡问题后沉淀知识 |
| `/co:sessions` | 开工前检索历史会话 |

---

## 数据文件

| 文件 | 用途 |
|------|------|
| `.eval-scores.jsonl` | 双轴评分历史，防通胀检测 |
| `.error-log.jsonl` | 错误捕获日志（5 类） |
| `.codex-quality.jsonl` | 每次 Codex dispatch 质量记录 |
| `results.tsv` | 会话级汇总（兼容旧格式） |
| `.tasks/*.json` | 并行任务板，原子认领 |

---

## Codex 任务说明模板（旧版兼容）

如不使用 XML 结构化 prompt，简化模板也可用：

```
Goal: [一句话目标]
Scope: [可以改的文件/目录]
Off-limits: [不能动的文件]
Subagents: yes/no
Worktree: yes/no → branch: [名称]
Deliver: 改动摘要、修改文件、测试结果、风险点、待确认问题
Tone: 内联压缩 full
```

但新实现推荐 XML 格式——Codex 对结构化 prompt 执行更稳定。

---

## 集成阶段输出

```
## Integration
Modified: [文件列表]
Overlaps: [none / 冲突列表]
Regressions: [none / 描述]
Tests: [通过/失败摘要]
Size violations: [none / >500 行新文件]
Verdict: ready / needs-fix / codex-rejected
```

**Pre-push 强制：** push 前问用户"是否需要触发一次全量代码审核？"

---

## 设计灵感与参考来源

| 来源 | 借鉴内容 |
|------|---------|
| `superpowers:using-git-worktrees` | worktree 创建与管理 |
| `superpowers:dispatching-parallel-agents` | 并行 subagent 分发 |
| `codex:codex-rescue` / `codex-companion.mjs` | Codex 任务底层调用 |
| `JuliusBrussee/caveman` | token 压缩模式 |
| `alchaincyf/darwin-skill` | 自我进化评分灵感 |
| `alirezarezvani/claude-skills: self-eval` | 双轴评分矩阵 + 魔鬼辩护 |
| `alirezarezvani/claude-skills: self-improving-agent` | 错误捕获 + 晋升生命周期 |
| `karpathy/autoresearch` | 锁定评估器、简洁性原则、策略升级、永不停止循环 |
| `rohitg00/pro-workflow` | learn-rule 快速捕获、context 预算分阶段、compact-guard |
| `shareAI-lab/learn-claude-code` | agent harness（任务板 + 心跳 + cron + 身份重注入） |
| `HKUDS/OpenSpace: skill_engine` | Smart Tool RAG（BM25+embedding 双阶段 + 质量过滤） |
| `HKUDS/OpenSpace: quality` | Codex 质量追踪（滚动窗 + 惩罚因子 + 语义失败注入） |
| `HKUDS/OpenSpace: security` | 派发安全门（危险模式检测、范围执行、用户确认门控） |
| `openai/codex-plugin-cc` | Codex 调用协议（fg/bg、resume、effort、XML prompt） |
| `EveryInc/compound-engineering-plugin` | 知识复利 4-subagent 流水线 |
| `garrytan/gstack: office-hours` | 产品/技术双模式前置思考 |
| `garrytan/gstack: plan-ceo-review` | CEO 级 4 模式计划审核 + Prime Directives |
| `obra/superpowers` | 跨 harness 插件结构、skill 组织 |
| `affaan-m/everything-claude-code` | 跨 harness 配置映射、AGENTS.md 通用基线 |
| `addyosmani/agent-skills` | Hyrum/Beyoncé/Chesterton 等工程原则 + Common Rationalizations |

---

## 设计原则

1. **自包含** — 无强制外部插件依赖，可选插件仅增强不阻断
2. **先计划，再执行** — 不输出计划不写代码
3. **所有权明确** — 每个文件只有一个写入者
4. **Token 意识** — 编排通信永远压缩，代码永远正常
5. **人在回路最小化** — Codex Co-Decision 优先，只在 Codex 低置信度时升级用户
6. **自我修正** — 三层机制持续进化，锁定评估器防止作弊
7. **跨 harness** — AGENTS.md 为通用基线，每个 harness 有独立配置覆盖
8. **永不停止** — `/co:loop` 背景持续运行，直到被中断

---

## 相关链接

- GitHub: https://github.com/dy9759/claude-codex-orchestration
- Issues: https://github.com/dy9759/claude-codex-orchestration/issues

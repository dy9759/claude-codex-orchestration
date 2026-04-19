# claude-codex-orchestration

> Claude Code 作为 **Tech Lead + 主执行者**，Codex 作为**并行实现者**（边界清晰的后端/脚本模块），Gemini 作为**前端/UI 专项咨询**（可选，via gemini-cli MCP）。自持运行（无强制外部插件依赖），跨 4 种 harness 可用（Claude Code / Cursor / Codex / OpenCode），带 4 层自我纠错 + 知识复利机制。

---

## 三角色模型

```
Claude Code（Tech Lead + 主执行者）
    │
    ├─ 架构设计、跨模块决策、仓库探索
    ├─ 前端工作（UI、页面、交互、样式、设计系统）
    ├─ 迁移、CI/CD、发布协调
    ├─ 最终集成、回归测试
    │
    ├─▶ Codex（并行实现者）
    │       ├─ 边界清晰的后端模块 / 脚本
    │       ├─ 独立可验证的 feature
    │       ├─ 并行方案试解
    │       └─ 当前 diff review（只读）
    │
    └─▶ Gemini（前端/UI 专项咨询，可选）
            ├─ 大型 UI 改版方案发散
            ├─ 2–3 个视觉/交互方向
            ├─ CSS 架构 / a11y / 响应式审查
            ├─ 多文件 UI 一致性扫描
            └─ "不丑但不够好"第二意见
            * via mcp__gemini-cli__*，不走 API key
            * CC 永远负责实现和浏览器验证
```

**铁律：** 任何时候不允许两个 Agent 同时写同一个文件。

---

## 分层架构（progressive loading）

```
Layer 1 — CLAUDE.md           全局最小规则，每机可不同        (~20 行)
Layer 2 — SKILL.md            跨机一致的 router + 自持规则    (~83 行)
Layer 3 — references/*.md     深度内容，按需懒加载            (13 files)
Layer 4 — 项目 AGENTS.md      bootstrap 生成，项目特有        (~50 行)
```

**设计动机：**
- CLAUDE.md 每机可不一致 → SKILL.md 必须自持关键规则
- SKILL.md 每次 skill 调用都加载 → 必须瘦到只做路由
- 深度内容只在 CC 真需要时加载 → 上下文节省 ~9k tokens/次

**v2026-04 重构关键数据：**
- SKILL.md: 665 → 83 行（-87%）
- 按需加载平均每次 1–2 个 references（~1.5k–3k tokens）
- 净节省：典型会话 **~7k–9k tokens**

---

## Self-Sufficient Core Rules（跨机自持，写在 SKILL.md 内）

这 8 条规则无论本机 CLAUDE.md 如何都必须成立：

1. **Pre-push gate** — 每次 `git push` 前问用户："是否需要触发一次全量代码审核？"
2. **AGENTS.md write redirect** — 所有 agent 指令/规则/约定写入项目 AGENTS.md，永不 CLAUDE.md；CLAUDE.md 保持单行 `@AGENTS.md` 指针
3. **Token Budget** — 内部通信压缩（`full` 默认：省冠词、碎句、短同义词）；代码块、安全警告、用户交付物不压
4. **Execution Plan required** — 无 Plan 不写代码；每任务必带 `verify:` 步骤
5. **Single writer per file** — 同一文件同时只能一个 agent 写
6. **Size limits** — 新文件 ≤ 500 行；函数 ≤ 80 行；嵌套 ≤ 3 层
7. **Session Start (首次调用)** — 跑插件检测 + AGENTS.md bootstrap（各 one-shot）
8. **Post-edit score** — 任何 skill 文件编辑后，8 维加权打分写入 `.skill-scores.jsonl`

---

## Reference Index（深度内容按需加载）

SKILL.md 里的路由表，CC 根据任务匹配读哪个 reference：

| 需要 | 文件 | 触发时机 |
|------|------|---------|
| Session 启动（插件 + AGENTS 迁移 + 数据文件生命周期）| `references/session-start.md` | 首次 skill 调用 |
| 工作流核心（Phase 0 → Plan → 执行 → 集成）| `references/workflow-core.md` | 开始任何非平凡任务 |
| 决策协议（前置 + 末端 + Priority 1–4）| `references/decision-protocol.md` | Plan 有多个决策点 |
| Codex 完整协议（调用 + co-decision + 安全门 + 质量追踪）| `references/codex-protocol.md` | Codex 派发前 |
| Gemini 集成（何时咨询 + 路由 + hook 配置）| `references/gemini-integration.md` | 前端/UI 可能需设计输入 |
| 思考层（`/co:think` + `/co:plan-review`）| `references/thinking-decision.md` | 任务模糊/新颖 |
| 知识复利（`/co:compound` + `/co:sessions`）| `references/knowledge-compounding.md` | 解决非平凡问题后 |
| 自我纠错（Layer 0–3）| `references/self-correction.md` | 会话结束 / skill 编辑 |
| 跨 harness 配置 | `references/cross-harness.md` | Harness 迁移 |
| 工程原则（Hyrum/Beyoncé/Chesterton 等）| `references/engineering-principles.md` | 集成审查 |
| 维护性规范（20 节 + Hard Red Lines）| `references/maintainability-harness.md` | 每次 Codex 派发 / AGENTS.md seed |
| UI 样式规范（shadcn + radix-nova）| `references/ui-style-standard.md` | 任何前端任务 |
| 上下文预算（+ Smart Tool RAG）| `references/context-budget.md` | 上下文 > 60% 或卡住 |

---

## 安装

放到 `~/.claude/skills/`，Claude Code 全局自动发现：

```bash
git clone https://github.com/dy9759/claude-codex-orchestration \
  ~/.claude/skills/claude-codex-orchestration
```

**跨机部署：** 复制 `CLAUDE.md.template`（仓库根，20 行）到 `~/.claude/CLAUDE.md`，触发 `§Preferred skill` 规则自动调用本 skill。其他机器用户无需手动复制全部规则。

**必需：**
- Claude Code CLI
- `codex@openai-codex` plugin（Codex 调度底层）

**可选增强（skill 自带内联 fallback，未装不影响使用）：**

| 插件 | 增强 |
|------|------|
| `superpowers@claude-plugins-official` | worktree 自动化、并行 subagent 分发 |
| `caveman` | 更深度输出 token 压缩 |
| `compound-engineering` | 更丰富的知识沉淀 subagent 流水线 |
| `gemini-cli` MCP | Gemini 前端/UI 咨询（见 `gemini-integration.md`）|

---

## 使用方式

在任意项目中对 Claude Code 说：

```
使用 claude-codex-orchestration，帮我实现 <你的需求>
```

或对复杂任务先前置思考：

```
先跑 /co:think 再规划
```

Claude Code 会：
1. Session Start 自动 bootstrap（插件检测 + AGENTS.md 迁移，首次会话仅一次）
2. Phase 0 探索仓库 + 理解需求
3. 输出 Execution Plan（含分工 + verify:）
4. **Pre-flight 批量决策**（一次性问完所有预判决策）
5. 并行执行（期间只有硬阻塞才打断你）
6. **末端统一汇总**（队列决策 + 未决 issue + 下一 milestone → 一轮回完）
7. 集成审查 + pre-push 全量审核提示

---

## 8 大能力层概览

各层详细内容在对应 reference 文件。README 只给概念摘要。

### 1. 跨 Harness 环境
同一 skill 可在 Claude Code / Cursor / Codex / OpenCode 使用。AGENTS.md 作为跨 harness 通用基线，CLAUDE.md 自动作 `@AGENTS.md` 指针。Hook 翻译表覆盖 4 harness 等效事件。详见 `references/cross-harness.md`。

### 2. Token 预算
三档内联压缩：`lite` / `full` / `ultra`。阶段化上下文阈值（Plan < 20% / 执行 < 60% / 集成 < 80% / Push < 90%）。Compact-guard 保护 5 关键状态。详见 `references/context-budget.md`。

### 3. 规划与分派
Phase 0 理解 → Execution Plan 格式化 → 分派（边界清晰 → Codex；前端/架构 → CC；UI 判断 → Gemini）。Codex 调用走 XML 结构化 prompt + thread 持久化 + 置信度门控 Co-Decision。详见 `references/workflow-core.md` + `references/codex-protocol.md`。

### 4. 决策集中协议 🔥 v2026-04
所有用户决策**前置到 Plan 确认** + **末端一次性汇总**。执行中只有 5 类硬阻塞（安全 BLOCKED / 数据丢失 / 越 scope / CRITICAL 颠覆 / 真阻塞）才打断。其他中途决策写入 `.decisions-pending` 队列，应用安全默认，末端汇总一轮回完。

**问答格式标准**（所有交互强制）：
- 每个问题 **必带 recommendation + 置信度**
- 涉及代码/架构 → 追加 Codex 建议
- 涉及 UI/设计 → 追加 Gemini 建议
- 3 agent 一致 → 标"all agents agree"；分歧 → 用户决定
- 简单 y/n 可用紧凑格式（省 Codex/Gemini 视图）
- 禁止"A/B/C?" 单行 → 必须含 options + tradeoff + recommendation

详见 `references/decision-protocol.md` §Question Format Standard。

### 5. 安全与质量
- **Smart Tool RAG** — BM25 + 语义二阶段技能检索
- **Codex Quality Tracking** — 滚动 20 次窗口，< 40% 成功率触发惩罚
- **Dispatch Security Gate** — DB/env/CI/密钥/强删/git 历史改写一律阻断
- **Task Board** — `.tasks/` 原子认领防双写
- **Worktree** — `feature/<agent>-<desc>`，生命周期 ≤ 1–3 天

详见 `references/codex-protocol.md` + `references/workflow-core.md`。

### 6. 思考与决策
- `/co:think` — 产品/技术双模式前置思考（5/4 问一问一答 + Premise Challenge + 可选 Codex cold read）
- `/co:plan-review` — CEO 级 Plan 审核（EXPAND/SELECTIVE/HOLD/REDUCE 四模式 + 7 条 Prime Directives）

详见 `references/thinking-decision.md`。

### 7. 工程原则 + 维护性规范
- **Common Rationalizations** — 7+ 条开发借口强制拒绝
- **Hyrum's Law** — API surface 改动强制 gate
- **Beyoncé Rule + Test Pyramid** — 测试金字塔 80/15/5
- **Change Sizing** — 100/300/1000 行阈值 + Five-Axis Review
- **Chesterton's Fence** — 删除前先理解
- **Trunk-Based Dev** — 分支 ≤ 1–3 天
- **Shift Left + Feature Flags** — 测试前置 + rollout 生命周期
- **Deprecation Protocol** — Advisory/Compulsory + Strangler/Adapter/Flag
- **Maintainability Harness 20 节** — 文件/函数/嵌套/命名/Rule of 3/类型/错误/配置/依赖/Hard Red Lines

详见 `references/engineering-principles.md` + `references/maintainability-harness.md`。

### 7.5. UI 样式规范
**硬默认：** shadcn/ui + `"style": "radix-nova"` + `baseColor: neutral` + `iconLibrary: lucide`。

**次级风格库**（灵感源）：VoltAgent/awesome-design-md、pbakaus/impeccable、bergside/typeui、bergside/awesome-design-skills、dy9759/brandmd0419、dy9759/dembrandt0419。

**网页样式提取能力** — 用户说"做成像 [URL] 那样"时自动 WebFetch → 提取 tokens → 映射 shadcn 覆盖层 → 预览 branch 确认后应用。

**6 条前端 Hard Red Lines** — 禁第二 UI 库、禁第二图标库、禁硬编码 hex、禁绕 `@/components/ui`、禁改 radix-nova 主题、禁任意 Tailwind 值。

详见 `references/ui-style-standard.md`。

### 8. 自我纠错与知识复利（4 层）

#### Layer 0 — Skill Modification Score 🔥 v2026-04
每次修改 `SKILL.md` / `references/*.md` / `README.md` / `CLAUDE.md.template` / AGENTS.md 模板后，Layer 0 自动跑：

**Step 1 — README 同步检查（新）**
扫描本次 commit 改动的 skill 文件，grep README 是否引用，引用则 CC 语义对比描述是否仍准确。不准确 → **在同一 commit 更新 README**（优先），或 commit message 说明"README 未变，因为仅内部 X 改动，对外描述不变"。

**Step 2 — 8 维加权打分**
按下表 rubric 打分，写入 git-tracked `.skill-scores.jsonl`。任一维度 -3 以上 → commit message 必须解释 tradeoff。

8 维权重（锁定不可改）：
| 维度 | 权重 |
|------|:---:|
| Design Completeness | 20% |
| Documentation Quality | 15% |
| Self-Containment | 15% |
| Cross-Harness Coverage | 10% |
| Executability | 15% |
| Validation Evidence | 10% |
| Engineering Rigor | 10% |
| Usability | 5% |

**为什么 README 同步作为 Layer 0 的第一步？** README 跟 SKILL.md 脱节是用户对 doc 失去信任的首号原因；锁步更新在单个 commit 内完成，避免 GitHub 上出现"半更新"中间态。

**当前分数：83.2/100**（`c2b8283`，从 baseline 72.0 爬到 83.2 共 5 次正向修改）。

#### Layer 1 — Session Self-Eval `/co:eval`
会话结束双轴评分（Ambition × Execution），3×3 锁定矩阵出分 1–5，Devil's Advocate 强制论证，防通胀检测。写 `.eval-scores.jsonl`。

#### Layer 2 — 错误自动捕获
Codex 失败 / 集成被拒 / learn-rule 触发 → `.error-log.jsonl` 5 类：dispatch / conflict / integration / scope-creep / token。

#### Layer 2.5 — External Escalation 🔥 v2026-04
**只上报结构性信号，不上报单次噪音。** 本地捕获 → 阈值聚合 → 自动上报 skill repo（`dy9759/claude-codex-orchestration`，**非**宿主项目）。

**4 类触发条件：**

| 类别 | 触发 | Fingerprint |
|------|------|------------|
| Recurrent root cause | 同 `root_cause` ≥ 2 次 / 7 会话 | `darwin:<category>:<root_cause>` |
| Codex quality hard-stop | 滚动 20 次成功率 < 40% 或连续 ≥ 3 失败 | `quality:hard-stop:<category>` |
| Darwin regression | `/co:promote` 添加的规则下次同维度未改善 | `darwin:regression:<dim>` |
| Structural flaw | 同 `weak_point` 持续 ≥ 5 会话 | `structural:<weak_point>` |

**Dedup：** 按 fingerprint 查已有 open issue → 存在则 comment 追加，不存在则 `gh issue create`。

**Label-free 标题前缀：** `[Darwin]` / `[CE]` / `[Quality]` / `[Structural]`（label 作为可选增强，不依赖）。

**Fallback 队列：** `gh` 不可用时写 `.issue-candidates.jsonl`（本地），下次 Session Start Part 5 自动 flush。成功上报后移入 git-tracked `.issue-log.jsonl`。

**本地-only，永不上报：**
- 单次 dispatch/conflict/integration 失败
- 宿主项目已知脏状态、flaky test、无关失败
- `gh auth` 未配置

**用户关心的边界：** 这条上报链路**不是**宿主项目的 `todo/non-blocking` issue。那些仍按 Next-Step Decision Flow 处理，进入宿主项目的 issue tracker。Layer 2.5 只进入 **skill 自己的 issue tracker**，作为社区反馈通道，让 skill 演化跨用户汇聚。

**Opt-out：** `touch ~/.claude/.orch-escalation-disabled`（本地捕获继续，只停外部上报）。

#### Layer 3 — 审查 + 晋升 `/co:review` + `/co:promote`
每 5 会话找 2+ 次重复弱点 → Durability+Impact+Scope 打分 ≥ 6 → 晋升到 SKILL.md。Ratchet 规则 + 简洁性原则。

#### 知识复利 `/co:compound` + `/co:sessions`
`/co:compound` 4 子 agent 并行（Context / Solution / Related Docs / Session Historian）→ 写 `docs/solutions/[category]/[slug]-[date].md`。
`/co:sessions` 跨会话搜（`~/.claude/projects/` + `~/.codex/sessions/`）避免重复失败路径。

详见 `references/self-correction.md` + `references/knowledge-compounding.md`。

---

## Invocation Prompts（mnemonic，非注册 slash command）

> 这些 `/co:*` 不是真正的 Claude Code slash command（不会出现在补全里），而是**记忆 prompt**。在聊天里输入即触发对应 reference 文件的工作流。

| Prompt | 用途 | 加载 |
|--------|------|------|
| `/co:score` | Skill 编辑后 8 维打分（skill 文件 commit 自动触发）| `self-correction.md` |
| `/co:think` | 模糊任务前置思考 | `thinking-decision.md` |
| `/co:plan-review` | Plan 草拟后 CEO 级审核 | `thinking-decision.md` |
| `/co:eval` | 会话结束双轴评分 | `self-correction.md` |
| `/co:review` | 每 5 会话扫错误日志 | `self-correction.md` |
| `/co:promote` | 将 ≥6 分候选写回 SKILL.md | `self-correction.md` |
| `/co:loop` | 自主后台打磨（ScheduleWakeup 270s）| `self-correction.md` |
| `/co:compound` | 解决问题后沉淀知识 | `knowledge-compounding.md` |
| `/co:sessions` | 开工前检索历史会话 | `knowledge-compounding.md` |

---

## 数据文件

| 文件 | git 跟踪 | 用途 |
|------|:-------:|------|
| `.skill-scores.jsonl` | ✅ 跟踪 | Layer 0 skill 质量演化记录（跨用户共享）|
| `.eval-scores.jsonl` | ❌ gitignored | 每用户会话评分历史 |
| `.error-log.jsonl` | ❌ gitignored | 每用户错误捕获 |
| `.codex-quality.jsonl` | ❌ gitignored | 每用户 Codex 质量追踪 |
| `.decisions-approved` | ❌ gitignored | Plan-cycle 预批决策（执行后清）|
| `.decisions-pending` | ❌ gitignored | 执行中队列决策（末端消费后清）|
| `.tasks/*.json` | 视情况 | 并行任务板（原子认领）|
| `.issue-candidates.jsonl` | ❌ gitignored | Layer 2.5 待上报队列（`gh` 不可用时的 fallback）|
| `.issue-log.jsonl` | ✅ 跟踪 | Layer 2.5 已上报 skill 仓库 issue 的历史（跨用户可见）|

**重置：** `rm ~/.claude/skills/claude-codex-orchestration/.{eval-scores,error-log,codex-quality}.jsonl` 清除个人会话数据。

---

## Session Start（自动执行）

**首次调用时跑四件事（都有 sentinel 防重复）：**

### 1. Optional Plugin Detection
读 `~/.claude/plugins/installed_plugins.json`，缺失 `caveman` / `compound-engineering` / `superpowers` 时一次性提示安装链接。Sentinel 文件 `~/.claude/.orch-plugin-hints-shown`。**永不阻断。**

### 2. AGENTS.md Bootstrap（项目级）
扫描项目根 `AGENTS.md` / `CLAUDE.md`：

| 情况 | 动作 |
|------|------|
| 两者都无 | 从模板创建 `AGENTS.md`（含 Non-Negotiable Rules / Role Definitions / Workflow / Decision Flow / UI Style）+ `CLAUDE.md=@AGENTS.md` |
| 只有 AGENTS.md | 创建 `CLAUDE.md=@AGENTS.md` 指针 |
| 只有 CLAUDE.md | 备份 `CLAUDE.md.bak` → 迁移内容到 `AGENTS.md` → `CLAUDE.md=@AGENTS.md` |
| 两者都有 | CLAUDE.md 是指针 → OK 静默；否则 WARN 建议合并 |

**官方文档支持**（[code.claude.com/docs/en/memory.md](https://code.claude.com/docs/en/memory.md)）：Claude Code 自动展开 CLAUDE.md 中的 `@filename` 导入。

### 3. 全局 CLAUDE.md §5.2 Auto-Seed + 版本感知 🔥 v2026-04

检测**全局** `~/.claude/CLAUDE.md` 的 §5.2 状态（非项目 CLAUDE.md）：

| 情况 | 动作 |
|------|------|
| CLAUDE.md 无 §5.2 引用此 skill | 提示"手动调用推断，是否 add §5.2？(y/n/later)" |
| §5.2 无版本标记 `<!-- orch-skill-version: N -->` | 提示"你的 §5.2 早于版本化或手写，是否替换为 v${当前}?" |
| §5.2 版本 < 当前 shipped | 提示"v${你的} → v${当前}, 变更摘要: ..., 是否更新?" |
| §5.2 版本 = 当前 | 静默（up-to-date）|

**Surgical Replacement 算法：** 用 awk 提取 "前半部分 + 新 §5.2 block + 后半部分"，preserve CLAUDE.md 其他内容完好；每次更新前自动建 `CLAUDE.md.bak-YYYYMMDD-HHMMSS` 时间戳备份。

**当前 ship 版本：v1。** 升级 §5.2 内容时（新 trigger / 规则 / 结构变），同 commit 里 bump 版本号 + 更新 `CLAUDE.md.template`。

Sentinel: `~/.claude/.orch-claude-md-seeded`。重置：`rm` 这个文件即可重新走一轮检测。

### 4. Skill Self-Update Check（git 拉取）🔥 v2026-04

Skill 本身是 git 仓库（clone 自 `dy9759/claude-codex-orchestration`）。每 **3 天** 自动检查本地是否落后于 `origin/main`：

| 情况 | 动作 |
|------|------|
| 上次检查 < 3 天前 | 静默跳过（除非已开 `always` 模式）|
| 有本地未提交改动 | 静默跳过（不碰用户 WIP）|
| 本地 HEAD = 远程 HEAD | 标 sentinel 时间，静默 |
| 本地 HEAD 领先远程（开发者）| 静默跳过 |
| 本地落后 N 个 commit | 按 Question Format Standard 问用户：**y / n / always / never**，附最新 5 条 commit 摘要 |

**user preferences（持久）：**
- `~/.claude/.orch-auto-update` — 选 always，未来静默自动 pull
- `~/.claude/.orch-update-disabled` — 选 never，完全禁用此检查
- 都未设 → 每 3 天提示一次

**安全保障：**
- `git pull --ff-only`（不 merge 不 rebase，分叉就 abort）
- 本地有未提交改动 → 跳过
- 本地领先远程 → 跳过
- 离线 / 无网 → `fetch` 失败后静默忽略，skill 仍工作

**Sentinel：** `~/.claude/.orch-update-last-check`（timestamp）。
**重置：** `rm ~/.claude/.orch-update-disabled`（重新启用）、`rm ~/.claude/.orch-auto-update`（切回提问模式）、`rm ~/.claude/.orch-update-last-check`（强制下次会话检查）。

**与 §5.2 版本化联动：** pull 成功后，Part 3 会自动重新检查 §5.2 版本；如 skill 升级把 §5.2 从 v1 升到 v2，Part 3 会 offer surgical 更新用户的 CLAUDE.md。

---

## 设计原则

1. **Self-contained** — 无强制外部插件；可选插件自动检测 + fallback
2. **Plan before execute** — 无批准 Plan 不写代码
3. **Single writer per file** — 铁律，永远
4. **Token-aware** — 内部通信压缩；代码 + 用户交付物保持完整
5. **Human-in-loop minimization** — Codex Co-Decision 优先，低置信度才升级；决策集中到两个时刻
6. **Self-correcting** — 4 层纠错（Layer 0 打分 / Layer 1 评估 / Layer 2 捕获 / Layer 3 晋升），锁定评估器防作弊
7. **Cross-harness** — AGENTS.md 通用基线，CLAUDE.md 指针
8. **Maintainability over speed** — 优化 6 月后的可读性，不优化行数
9. **Progressive loading** — SKILL.md 是 router；深度内容按需 load

---

## 设计灵感与参考来源（20+）

| 来源 | 借鉴 |
|------|------|
| `superpowers:using-git-worktrees` | worktree 创建与管理 |
| `superpowers:dispatching-parallel-agents` | 并行 subagent 分发 |
| `codex:codex-rescue` / `codex-companion.mjs` | Codex 任务底层调用 |
| `JuliusBrussee/caveman` | token 压缩模式 |
| `alchaincyf/darwin-skill` | 自我进化评分灵感 |
| `alirezarezvani/claude-skills: self-eval` | 双轴评分矩阵 + 魔鬼辩护 |
| `alirezarezvani/claude-skills: self-improving-agent` | 错误捕获 + 晋升生命周期 |
| `karpathy/autoresearch` | 锁定评估器、简洁性原则、策略升级、永不停止循环 |
| `rohitg00/pro-workflow` | learn-rule 快速捕获、context 预算分阶段、compact-guard |
| `shareAI-lab/learn-claude-code` | agent harness（任务板 + 心跳 + cron + 身份重注入）|
| `HKUDS/OpenSpace: skill_engine` | Smart Tool RAG（BM25+embedding 双阶段 + 质量过滤）|
| `HKUDS/OpenSpace: quality` | Codex 质量追踪（滚动窗 + 惩罚因子 + 语义失败注入）|
| `HKUDS/OpenSpace: security` | 派发安全门（危险模式检测、范围执行、用户确认门控）|
| `openai/codex-plugin-cc` | Codex 调用协议（fg/bg、resume、effort、XML prompt）|
| `EveryInc/compound-engineering-plugin` | 知识复利 4-subagent 流水线 |
| `garrytan/gstack: office-hours` | 产品/技术双模式前置思考 |
| `garrytan/gstack: plan-ceo-review` | CEO 级 4 模式计划审核 + Prime Directives |
| `obra/superpowers` | 跨 harness 插件结构、skill 组织、router + references 模式 |
| `affaan-m/everything-claude-code` | 跨 harness 配置映射、AGENTS.md 通用基线 |
| `addyosmani/agent-skills` | Hyrum / Beyoncé / Chesterton 等工程原则 + Common Rationalizations |
| `dy9759/everything-claude-code` inspiration | 跨 harness 实施指南 |

---

## 架构升级历史

| 版本 | 关键变化 | 分数 |
|------|---------|:---:|
| v0 (`bb10408`, 重构前) | 单体 SKILL.md 902 行 | 72.0 |
| v1 (`f01002b`, thin-router) | SKILL.md 瘦到 81 行 + 3 新 references + CLAUDE.md.template | **78.6** |
| v2 (`def4a9e`, Layer 0) | 加入 `/co:score` 自动打分机制 | **80.0** |
| v3 (`f899c1c`, README 重写) | README 全量同步 thin-router 架构 + Layer 0 trigger 扩展到 README | **81.2** |
| v4 (`a8090ac`, §5.2 auto-seed) | 全局 CLAUDE.md §5.2 自动播种（手动调用检测）| **82.4** |
| v5 (`c2b8283`, §5.2 版本化) | §5.2 版本感知 + surgical replacement + 时间戳备份 | **83.2** |

查看实时分数：`cat .skill-scores.jsonl`。

---

## 相关链接

- GitHub: <https://github.com/dy9759/claude-codex-orchestration>
- 主分支: `main`（2026-04 从 master 迁移）
- Issues: <https://github.com/dy9759/claude-codex-orchestration/issues>（当前 12/12 全部关闭）
- Claude Code memory docs: <https://code.claude.com/docs/en/memory.md>

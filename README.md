# claude-codex-orchestration

> Claude Code 作为 Tech Lead（总控），Codex 作为 Parallel Implementer（并行实现者），双 Agent 协同编码 skill。自包含运行（无强制外部插件依赖），可选集成 caveman / compound-engineering / superpowers 进一步增强。跨 harness 可用（Claude Code / Cursor / Codex / OpenCode）。

---

## 核心思路

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
            ├─ 2–3 个视觉/交互方向备选
            ├─ CSS 架构 / a11y / 响应式审查
            ├─ 多文件 UI 一致性扫描
            └─ "不丑但不够好"第二意见
            * via mcp__gemini-cli__*，不是 API key
            * CC 永远负责实现和浏览器验证；Gemini 只咨询不执行
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
| 7.5. UI 样式规范 | shadcn/ui + `radix-nova` 默认；支持从任意网页提取设计 tokens 映射到 shadcn 覆盖层 |
| 7.6. 下一步决策流 | 每个任务后先跑测试；阻塞性失败立即修，非阻塞建 gh issue 继续；计划完成后统一处理未决 issue |
| 7.7. Gemini 前端专项咨询 | 大型 UI 改版 / 方案发散 / CSS 架构审查 / a11y 审查时调用 Gemini（via gemini-cli MCP）；CC 始终实现并浏览器验证；Gemini 不可用 → CC 不阻塞继续 |
| 7.8. 决策集中协议 | 所有用户决策前置到 Plan 确认 + 末端一次性汇总；执行中只有硬阻塞（安全/数据丢失/越界）才打断；中途决策静默队列 + 安全默认 |
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

**会话启动自动引导（零配置）：**
1. 扫描已安装插件，缺失项一次性提示安装链接
2. 检查项目 `AGENTS.md` / `CLAUDE.md`，自动迁移或创建，使 4 种 harness 指向同一份指令源
3. 详见下面 **Section 0. Session Start**

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
Session Start
          ↓
          [可选插件检测] → [AGENTS.md 自动引导]
          ↓
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

## 0. Session Start（自动执行，一次性）

### 可选插件检测

会话启动时读 `~/.claude/plugins/installed_plugins.json`，检测 `caveman`、`compound-engineering`、`superpowers`。缺失项一次性打印安装链接，sentinel 文件 `~/.claude/.orch-plugin-hints-shown` 防止重复打扰。**永不阻断** — 所有可选插件都有内联 fallback。

重新触发：`rm ~/.claude/.orch-plugin-hints-shown`

### AGENTS.md 自动引导

**AGENTS.md 是跨 harness 的唯一真相来源**（Claude Code、Cursor、Codex、OpenCode 都读它）。会话启动时自动检查项目根：

| AGENTS.md | CLAUDE.md | 动作 |
|-----------|-----------|------|
| ✅ | ✅（是 `@AGENTS.md` 指针） | OK，静默 |
| ✅ | ✅（有其他内容） | WARN，建议合并，不自动操作 |
| ✅ | ❌ | 创建 `CLAUDE.md` 内容为 `@AGENTS.md` |
| ❌ | ✅ | 迁移 CLAUDE.md → AGENTS.md（备份 `CLAUDE.md.bak`），CLAUDE.md 改为 `@AGENTS.md` |
| ❌ | ❌ | 从模板创建 AGENTS.md + CLAUDE.md 指针 |

**官方文档支持：** Claude Code 识别 CLAUDE.md 中的 `@filename` 语法为 import 指令，会话启动时自动展开 AGENTS.md 内容（[code.claude.com/docs/en/memory.md](https://code.claude.com/docs/en/memory.md)）。

### **⚠️ AGENTS.md 写入重定向规则（强制）**

> **所有 agent 指令/规则/角色/项目约定——一律写入 `AGENTS.md`，永不 `CLAUDE.md`。**
>
> CLAUDE.md 永远只有一行 `@AGENTS.md`。唯一例外：修改那行指针本身。
>
> **原因：** 写入 CLAUDE.md 会造成 CC-only 规则，Cursor/Codex/OpenCode 看不到，破坏跨 harness parity。

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

**按边界清晰度分工，不按前后端分。** Codex 不是前端专家，此表是"边界清晰模块好并行"的启发式，不是能力断言。

| Claude Code 负责 | Codex 负责 |
|-----------------|-----------|
| 架构设计、跨模块决策、仓库探索 | 边界清晰的后端模块 / 脚本 |
| **前端工作**（UI 组件、页面、交互、样式、设计系统）| 独立可验证（有测试或明确验收标准） |
| 迁移、CI/CD、发布管道 | 范围已知的隔离 bug 修复 |
| 集成他人输出 | 并行候选实现（比较后挑选） |
| 接口最终决策 | 当前 diff review（只读） |

**为什么前端 → CC？** Claude (Sonnet 4.6+) 在组件设计、状态管理、CSS/设计系统一致性、UX 边界情况上判断力强。Codex 在接口稳定、测试集明确的后端模块/脚本上更出色。**按各自最擅长的反推分工，不按领域刻板印象。**

**实用启发式：** 任务能用 `Scope: [paths]` + `Off-limits: [paths]` + 可验证 done-state 描述，**且**属于后端/脚本/隔离类 → 派给 Codex。前端和跨模块工作默认留给 CC，除非有明确理由要并行。

**校准：** 这是 v0 默认值。实际跑 5+ 次真实会话后，用 `.eval-scores.jsonl` 的 weak-point 数据通过 `/co:review` + `/co:promote` 调整。

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
| **UI 样式** | shadcn/ui + `radix-nova` 为默认；网页设计提取能力（见 §7.5） |
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

## 7.5. UI 样式规范层（前端工作统一标准）

**硬默认：** shadcn/ui + `"style": "radix-nova"` + `baseColor: neutral` + `iconLibrary: lucide`

每个新前端项目的 `components.json` 起点：
```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "radix-nova",
  "baseColor": "neutral",
  "iconLibrary": "lucide",
  "aliases": { "components": "@/components", "ui": "@/components/ui", ... }
}
```

**次级风格库（灵感源，非默认）：**
| 来源 | 场景 |
|------|------|
| [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) | 需要品牌参考库 |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 需要"good taste"默认值 |
| [bergside/typeui](https://github.com/bergside/typeui) | 排版密集型界面 |
| [bergside/awesome-design-skills](https://github.com/bergside/awesome-design-skills) | 设计技能参考 |
| [dy9759/brandmd0419](https://github.com/dy9759/brandmd0419) | 用户个人品牌 |
| [dy9759/dembrandt0419](https://github.com/dy9759/dembrandt0419) | 用户个人主题 |

**网页样式提取能力**（参考 [bergside/design-md-chrome](https://github.com/bergside/design-md-chrome)）：

用户说"做成像 [URL] 那样"时自动触发：
```
1. WebFetch 页面
2. 提取设计 tokens（颜色、字体、间距、圆角、阴影、动效）
3. 生成 markdown 设计规范
4. 映射到 shadcn 覆盖层：src/global.css CSS 变量 + tailwind.config 颜色扩展
5. 询问用户确认后应用
```

**前端 Hard Red Lines：**
- 不得在 shadcn 之外引入第二个 UI 库（MUI/Chakra/AntD）
- 不得在 lucide 之外引入第二个图标库
- 组件里禁止硬编码 hex 颜色（必须走 CSS 变量）
- 禁止绕过 `@/components/ui` 内联 primitive 样式
- 禁止未经用户确认改 `radix-nova` 主题变量
- 禁止使用 Tailwind 任意值（`p-[13px]`）当 scale 有合法 token

详见 `references/ui-style-standard.md`（234 行完整规范）。

## 7.6. 下一步决策流层（任务间切换的强制优先级）

**每个任务完成后，按以下优先级决定下一步，不允许跳步省时间。**

### Priority 1 — 先跑测试（任何情况下）

```
运行：tests + lint + type check
├─ 全通过  → Priority 3（下一任务）
└─ 有失败 → Priority 2（分诊）
```

例外：无。纯文档改动也跑 linter。这是 Shift Left 原则的具体化。

### Priority 2 — 失败分诊

**阻塞性失败（先修）：**
- 刚实现的功能的测试
- 改动触及代码路径上原本绿色的测试
- 修改文件里的 build/type/lint 错
- 影响关键路径的回归

→ **立即修，不继续下一任务**。修到绿再往下。

**非阻塞失败（建 issue，继续）：**
- 碰巧断的无关模块测试
- 已知的 flaky 测试
- 与当前任务无关的预存失败
- 修改文件里的 warning（非 error）

→ **建 GitHub issue，继续开发：**
```bash
gh issue create \
  --title "[bug] <一句话失败描述>" \
  --label "todo,non-blocking" \
  --body "Reproduction: ... Expected: ... Actual: ... Affected: ... Context: discovered during <当前任务>"
```

**无法判断是否阻塞？** → Codex Co-Decision：让 Codex 分诊并给置信度。低置信度才问用户。

### Priority 3 — 从 Execution Plan 取下一任务

宣告："Next: [task]. Verify: [command]."

### Priority 4 — Plan 全部完成 → Issue 统一处理循环

计划完成，**不立即 push**。先拉取未决 issue：
```bash
gh issue list --state open --label todo --json number,title,labels --limit 20
```

向用户展示列表，问："Plan 完成，有 N 个未决 todo（H/M/L 各几个）。现在处理，还是推迟到下次？"

**现在处理：**
1. 按 label 排：high > medium > low
2. 每个 issue：`gh issue view <N>` → mini plan → fix → `git commit -m "fix ... closes #N"` → 回 Priority 1 跑测试
3. 全部处理完 → 走 Integration Phase

**推迟：**
- 直接 Integration Phase + push
- Issue 留给下次会话

**两条路径都强制：** push 前触发 §5.3 code review prompt（"是否需要触发一次全量代码审核？"）

## 7.7. Gemini 前端专项咨询层

**关系：** CC 主控 → Gemini 专项咨询 → CC 兜底。Gemini 给建议，CC 实现+验证。

**事实优先级：** 浏览器真实运行 > 本地代码上下文 > Gemini 建议。

### 何时调用 Gemini

| 调用 Gemini | 不调用 Gemini |
|------------|--------------|
| 大型 UI 改版 / 新页面 / 新模块 | 小样式修复 / 文案调整 / 明确 bugfix |
| 需要 2–3 个视觉/交互方向 | 快速试错运行时问题 |
| 组件结构 / 信息架构不确定 | 浏览器调试（console / network / DOM） |
| 多文件 UI/CSS 一致性审查 | 紧急阻塞任务 |
| a11y / 响应式 / 语义 HTML 审查 | CC < 2 分钟能完成的改动 |
| "不丑但不够好"第二意见 | — |

### 调用方式

通过 `mcp__gemini-cli__*` MCP 工具（**不走 API key**）。Prompt 用自然语言（不是 XML，Gemini 是协作者不是 Codex 那种操作员）：

```
ask gemini to propose 3 UI variants for [component], prioritize [criterion]
ask gemini to audit CSS architecture for responsive inconsistencies in src/pages/
ask gemini to review the current diff for frontend issues (naming, a11y, perf)
```

要求 Gemini 返回结构化输出：`recommendation / alternatives / risks / implementation notes`。

### Gemini vs Codex Co-Decision 路由

| 问题性质 | 路由到 |
|---------|-------|
| 代码架构、bug 分类、风险分诊 | Codex Co-Decision |
| 前端设计方向、UI 美学、a11y | Gemini 咨询 |
| 两者都适用 | 挑更接近失败模式的那个（代码 → Codex，视觉 → Gemini），永不同时问 |

### 失败 fallback

Gemini MCP 不可用（超时/限流/出错）→ CC 继续执行，**绝不阻塞**。在 `.error-log.jsonl` 记 `category: gemini-unavailable`，后续由自我纠错循环识别模式。

### Hook 配置（一次性）

所有 Gemini 调用由 CC 侧 hook 记录。在 `~/.claude/settings.json` 加：
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "mcp__gemini-cli__.*",
      "hooks": [{"type": "command", "command": "~/.claude/hooks/after-gemini.sh", "async": true, "timeout": 120}]
    }]
  }
}
```

详见 `references/gemini-integration.md`（260 行完整规范）。

## 7.8. 决策集中协议层（前置 + 末端，拒绝中途打断）

**原则：** 所有用户决策集中到两个时刻 —— **Plan 确认前（pre-flight）** 和 **Plan 完成后（end-of-plan）**。执行过程中只有"硬阻塞"才中断用户，其他决策静默队列、应用安全默认、末端一次性汇总。

### 决策时机分类

| 类别 | 时机 | 举例 |
|------|------|------|
| **Pre-flight**（Plan 确认时批量问） | 执行**前** | Plan 批准、`/co:plan-review` 模式、预判的高风险操作、UI 主题变更、计划删除 |
| **Queued**（日志 + 安全默认 + 末端问） | 执行**中**（非阻塞） | Codex review 发现、Gemini vs 浏览器冲突、Chesterton's Fence 非关键判断、网页样式提取应用 |
| **Blocking**（立即打断，稀有） | 任何时候 | Dispatch Security Gate BLOCKED 模式、无备份的破坏操作、跨 scope 写入、数据丢失风险 |
| **End-of-plan**（单次汇总 prompt） | Priority 1–3 全完成后 | 未决 `todo` issue + 队列决策 + milestone 候选菜单 |

### Pre-flight 批量问（Plan 确认时）

CC 扫描 Plan 里每个任务，识别**预判决策点**，在 Plan 旁边一次性列出。用户一行回答全部：

```
Plan ready. 执行前 4 个决策：

[1] Task T3 将跨 auth/ 模块批量重命名 12 个文件。批准？(y/n)
[2] Task T5 将改 radix-nova primary 色为品牌色。批准？(y/n)
[3] Task T7 计划删除 legacy-auth.ts（用途不明，Chesterton's Fence）。
    → 保留 / 删除 / 先调研再问 (k/d/i)
[4] Task T9 需要 2–3 个 dashboard UI 方案。咨询 Gemini？(y/n)

回复示例: 1y 2n 3k 4y
```

CC 存到 `.decisions-approved`，执行期不再问。

### 中途队列（不打断）

执行期遇到未预批的决策：

```
if 是阻塞（安全阻断/数据丢失/越界）:
    立即打断，一行 prompt
else:
    写入 .decisions-pending，应用安全默认，日志 "[Decision queued]"
    继续执行
```

**各场景安全默认：**

| 场景 | 安全默认 |
|------|---------|
| Codex review 发现（任何严重度） | 仅呈现，不自动修 |
| Gemini 建议与浏览器运行矛盾 | 跟随浏览器，记 Gemini 异议 |
| Chesterton's Fence（用途不明代码）| 保留代码，记录谜团 |
| UI 网页样式提取应用 | 写预览分支，不触 main |
| 非阻塞测试失败 | `gh issue create --label "todo,non-blocking"` |

### 强制阻塞例外（仍立即中断）

**不可队列：**
1. Dispatch Security Gate BLOCKED 模式被尝试（DB 迁移、env、CI、密钥、强删、git 历史改写）
2. 无备份的破坏操作
3. 跨 scope 写入（Codex 动了 `Off-limits:` 文件）
4. Codex 报告 CRITICAL 级别且颠覆任务前提
5. Plan 真的无法继续（不是仅仅"尴尬"）

格式：`"BLOCKING: <什么>. <A> 还是 <B>?"`

### 末端一次性汇总（Plan 完成后）

合并三股数据流为**单次 prompt**：

```
### Plan 完成，测试全绿。Push 前统一 review：

A. 执行中队列决策（3 条）：
   A1. Task T5 — Codex review 3 条 medium 发现. 现在修 / 建 issue / 忽略?
   A2. Task T7 — Gemini 建议调整 dashboard 卡片顺序；浏览器两种都 OK. 应用 / 跳过?
   A3. Task T9 — 网页提取建议改 2 个色 token. 应用 / 跳过?

B. 现有未决 issue（2 条）：
   B1. #61 — real-meeting retest (priority: high)
   B2. #73 — [bug] Safari CSS 动画闪烁 (priority: low, non-blocking)

C. 下一个 milestone 候选（4 条，来自 Phase 0 路线图）：
   C1. F — meeting REST handler wire
   C2. T — real cloud-sync target (MyMemo Hub)
   C3. U — frontend memory list + filter UI
   C4. V — MCP tool e2e

D. 立刻 push？（push 前强制 §5.3 全量代码审核提示）

回复格式: "A1=fix A2=apply A3=skip B=B1-now C=C2 D=y" 或自由答
```

一轮回完。CC 原子处理所有决策 → 跑 Priority 1 → §5.3 提示 → push。

### 状态文件

| 文件 | 生命周期 |
|------|---------|
| `.decisions-approved` | Plan 确认时写入，Plan 完成时清理 |
| `.decisions-pending` | 执行中 append，End-of-plan 消费后清理 |

两个都 `.gitignore`d。

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
### Integration
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

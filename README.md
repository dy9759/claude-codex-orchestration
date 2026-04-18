# claude-codex-orchestration

> Claude Code 作为总控，Codex 作为并行实现者，双 Agent 协同编码 skill。内置 Caveman token 压缩，保证输出质量的同时大幅降低 token 消耗。

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

## 安装

skill 放在 `~/.claude/skills/`，Claude Code 全局自动发现，无需 per-project 配置。

```bash
# 克隆或手动复制到全局 skills 目录
cp -r claude-codex-orchestration ~/.claude/skills/
```

**依赖：**
- Claude Code（已安装 `codex@openai-codex` plugin）
- `superpowers@claude-plugins-official` plugin（worktree、parallel agent 支持）
- 可选：`caveman` plugin（强化 token 压缩）

---

## 使用方式

在任意项目中，对 Claude Code 说：

```
使用 claude-codex-orchestration skill，帮我实现 <你的需求>
```

或者直接：

```
/claude-codex-orchestration <需求描述>
```

Claude Code 会自动：
1. 探索仓库，理解影响范围
2. 输出执行计划（含 CC / Codex 分工、worktree、subagent 决策）
3. 等你确认后并行执行
4. 集成双方输出，输出验证结论

---

## 执行流程

```
Phase 0   理解任务
          ↓
          输出执行计划（Caveman 格式，等用户确认）
          ↓
Phase 1   并行执行
          ├─ CC 处理主线任务
          └─ Codex 处理独立模块（task spec <200 词）
          ↓
Phase 2   集成
          └─ 差异审查 → 回归检查 → 测试 → 最终结论
```

---

## Token 控制（Caveman 集成）

所有 Agent 内部通信（执行计划、状态更新、Codex 任务说明、集成报告）默认使用 **Caveman `full`** 模式，削减约 75% 输出 token，技术信息完整保留。

| 级别 | 描述 | 适用场景 |
|------|------|---------|
| `lite` | 去掉废话和模糊表达，保留完整句子 | 需要可读性高的计划输出 |
| `full` | 省略冠词、碎句 OK、短同义词替换（默认） | 日常编排通信 |
| `ultra` | 缩写（DB/fn/impl）、箭头表示因果（X → Y） | token 极度紧张时 |

切换级别：`/caveman lite` / `/caveman full` / `/caveman ultra`

**永远不压缩：**
- 代码块（始终正常书写）
- 安全警告、不可逆操作确认
- 用户需要清晰理解的最终交付物

**输入 token 优化：** 长会话开始前建议运行：
```
caveman:compress ~/.claude/CLAUDE.md
```
可减少约 46% 的每次会话输入 token。

---

## 默认分工

| Claude Code 负责 | Codex 负责 |
|-----------------|-----------|
| 仓库探索与架构设计 | 前端页面、UI、交互细节 |
| 后端逻辑、API、数据流 | 截图/设计稿驱动的修复 |
| 脚本、迁移、CI/CD | 独立 feature 模块实现 |
| 高风险/跨模块改动 | 并行方案试解 |
| 最终集成与发布前检查 | 当前 diff review |

---

## Codex 任务说明模板

每次给 Codex 的任务说明必须是 Caveman 格式，<200 词：

```
Goal: [一句话目标]
Scope: [可以改的文件/目录]
Off-limits: [不能动的文件]
Subagents: yes/no
Worktree: yes/no → branch: [名称]
Deliver: 改动摘要、修改文件、测试结果、风险点、待确认问题
Tone: caveman full
```

---

## Worktree 使用规则

**触发条件（满足任一即建 worktree）：**
- CC 与 Codex 并行实现不同模块
- 同时测试 2+ 个竞争方案
- 隔离高风险改动

**规则：**
- 每个 worktree 只有一个主写入者
- 命名：`feature/<agent>-<描述>`（如 `feature/codex-ui-redesign`）
- 合并前：diff 审查 → cherry-pick 或手动集成

---

## Quality Gates（集成前检查）

来自全局 CLAUDE.md 的工程规范，在多 Agent 场景下显式执行：

| 检查项 | 规则 |
|--------|------|
| **最小范围** | Codex 输出超出任务说明的部分一律标记，不直接合并 |
| **文件边界** | Codex 只能删除它自己造成的孤儿代码，不得动预存死代码 |
| **文件大小** | Codex 新建文件 <500 行，超出则要求拆分后再集成 |
| **验收标准** | 计划中每个子任务必须有 `verify:` 步骤，通过才算完成 |
| **Push 前审核** | 每次 push 前询问是否触发全量代码审核并创建 GitHub Issues |

## 集成阶段输出格式

```
## Integration

Modified: [文件列表]
Overlaps: [none / 冲突列表]
Regressions: [none / 描述]
Tests: [通过/失败摘要]
Size violations: [none / >500行的新文件]
Verdict: ready / needs-fix / codex-rejected
```

---

## 自我纠错与进化（三层机制）

参考 `alirezarezvani/claude-skills` 中的 `self-eval` 和 `self-improving-agent` 设计。

---

### Layer 1 — 会话自评 `/co:eval`

每次会话结束后运行。**双轴评分**，不允许直接选分数：

**轴 A — 编排复杂度**（任务本身难度）：`Low / Medium / High`

**轴 B — 执行质量**（结果好坏）：`Poor / Adequate / Strong`

**固定矩阵出分**（不可覆盖）：

|                        | Poor | Adequate | Strong |
|------------------------|:----:|:--------:|:------:|
| **Low Ambition**       |  1   |    2     |   2    |
| **Medium Ambition**    |  2   |    3     |   4    |
| **High Ambition**      |  2   |    4     |   5    |

**强制魔鬼辩护**：评分前必须分别论证"为什么应该更低"和"为什么应该更高"，再解决分歧，才能最终确认分数。防止 AI 默认给 4 分的评分通胀。

**防通胀检测**：读取 `.eval-scores.jsonl`，如果最近 5 次有 4 次相同分数 → 警告，强制重新评估。

评分持久化到：`.eval-scores.jsonl`

---

### Layer 2 — 错误自动捕获

Codex 返回失败、任务说明导致歧义、集成被拒时，立即记录到 `.error-log.jsonl`：

| 错误类型 | 触发条件 |
|---------|---------|
| `dispatch` | Codex 任务说明太模糊，Codex 跑偏或要求澄清 |
| `conflict` | 文件 ownership 冲突，两个 Agent 改了同一文件 |
| `integration` | Codex 输出被拒，超出范围/超 500 行/有无关改动 |
| `scope-creep` | Codex 改了不在声明范围内的文件 |
| `token` | Caveman 级别未有效降低 token 消耗 |

---

### Layer 3 — 审查与晋升 `/co:review` / `/co:promote`

**`/co:review`**（每 5 次会话运行一次）：
- 读取 `.eval-scores.jsonl` + `.error-log.jsonl`
- 找出重复出现（2+ 次）的弱点或错误根因
- 对每个候选项打晋升评分：Durability + Impact + Scope（各 0-3 分）
- **总分 ≥ 6 → 晋升到 SKILL.md**；4-5 → 观察；≤ 3 → 忽略

**`/co:promote`**（将学到的规律写入 SKILL.md）：
- 从描述性 → 规范性：
  - ❌ "Codex 总是跑偏因为说明不够明确"
  - ✅ "任务说明超 200 词必须先压缩，否则 Codex 会漫游"
- 晋升后删除对应 error-log 条目，避免噪音积累

**棘轮规则**：只有下一次会话评分改善了对应弱点，才确认保留该 SKILL.md 改动。否则回滚。

---

### 数据文件

| 文件 | 用途 |
|------|------|
| `.eval-scores.jsonl` | 双轴评分历史，防通胀检测 |
| `.error-log.jsonl` | Codex 失败与协调错误日志 |
| `results.tsv` | 会话级汇总记录（兼容旧格式）|

---

## 与其他 skill 的关系

| Skill | 关系 |
|-------|------|
| `superpowers:using-git-worktrees` | worktree 创建与管理 |
| `superpowers:dispatching-parallel-agents` | 并行 subagent 分发 |
| `codex:codex-cli-runtime` | Codex 任务底层调用 |
| `caveman` | token 压缩模式（可选但推荐） |
| `darwin-skill` | 自我进化评分灵感来源 |
| `alirezarezvani/claude-skills: self-eval` | 双轴评分矩阵 + 魔鬼辩护机制 |
| `alirezarezvani/claude-skills: self-improving-agent` | 错误捕获 + 晋升生命周期设计 |

---

## 设计原则

1. **先计划，再执行** — 不输出计划不写代码
2. **所有权明确** — 每个文件只有一个写入者
3. **token 意识** — 编排通信永远 caveman，代码永远正常
4. **人在回路** — 计划确认、集成结论都等用户 review
5. **自我修正** — 每次会话后打分，弱项触发重写

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

## 集成阶段输出格式

```
## Integration

Modified: [文件列表]
Overlaps: [none / 冲突列表]
Regressions: [none / 描述]
Tests: [通过/失败摘要]
Verdict: ready / needs-fix / codex-rejected
```

---

## 自我进化（Darwin 机制）

每次会话结束后，skill 对自身打分（1-10）：

| 维度 | 衡量内容 |
|------|---------|
| 任务拆分质量 | CC/Codex 边界是否清晰？ |
| 冲突避免 | 有无文件 ownership 冲突？ |
| 计划清晰度 | 计划是否消除了歧义？ |
| Codex 分发质量 | 任务说明是否足够紧凑？ |
| 集成顺畅度 | 需要多少返工？ |
| Token 效率 | Caveman 级别是否有效？ |

任何维度 ≤ 6 分 → 识别问题段落 → 重写。
**棘轮规则：** 只保留能提升最低维度分数的改动，否则回滚。

评分记录在：`~/.claude/skills/claude-codex-orchestration/results.tsv`

---

## 与其他 skill 的关系

| Skill | 关系 |
|-------|------|
| `superpowers:using-git-worktrees` | worktree 创建与管理 |
| `superpowers:dispatching-parallel-agents` | 并行 subagent 分发 |
| `codex:codex-cli-runtime` | Codex 任务底层调用 |
| `caveman` | token 压缩模式（可选但推荐） |
| `darwin-skill` | 自我进化评分机制来源 |

---

## 设计原则

1. **先计划，再执行** — 不输出计划不写代码
2. **所有权明确** — 每个文件只有一个写入者
3. **token 意识** — 编排通信永远 caveman，代码永远正常
4. **人在回路** — 计划确认、集成结论都等用户 review
5. **自我修正** — 每次会话后打分，弱项触发重写

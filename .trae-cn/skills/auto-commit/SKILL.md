---
name: "auto-commit"
description: "After completing every user task, summarizes what was done and commits all local changes to git. Invoke automatically after finishing any user instruction/task."
trigger: "/auto-commit"
---

# auto-commit

每次完成用户的指令后，对本次执行进行总结，并将所有变更 commit 到本地 git 仓库。

## 使用方式

- `/auto-commit` — 手动触发总结 + 提交
- 完成用户的任务后，检查此 skill 是否存在，如果存在则自动执行

## 执行步骤

### Step 1 — 判断是否需要提交

```bash
# 检查是否在 git 仓库中
git rev-parse --is-inside-work-tree 2>/dev/null || { echo "Not a git repository, skipping."; exit 0; }

# 检查是否有变更
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "No changes to commit."
    exit 0
fi
```

如果有变更，继续执行 Step 2。

### Step 2 — 查看当前变更

```bash
git status --short
git diff --stat
```

快速浏览变更文件列表，不需要逐行阅读 diff。

### Step 3 — 生成总结

根据本次对话中完成的所有操作，生成一段简洁的总结内容（中文），包括：

1. **主要任务** — 用户发出的原始指令是什么
2. **执行内容** — 完成了哪些具体操作（文件变更、新增功能、修复等）
3. **关键变更** — 列出修改/新增的主要文件及其变化

总结格式示例：

```
### 主要任务
创建自动提交 skill，在每次任务完成后自动总结并 commit

### 执行内容
- 创建 .trae-cn/skills/auto-commit/SKILL.md
- 定义 auto-commit skill 的触发条件和执行步骤
- 配置 git 自动提交流程

### 关键变更
- .trae-cn/skills/auto-commit/SKILL.md (新增): auto-commit skill 定义文件
```

### Step 4 — 执行提交

```bash
git add -A
git commit -m "<用户原始指令>" -m "<Step 3 生成的总结>"
```

- 标题（`-m`）：用户的原始指令
- 正文（第二个 `-m`）：Step 3 生成的总结

### Step 5 — 输出结果

```bash
git log -1 --oneline
```

告知用户提交成功，显示 commit hash 和标题。
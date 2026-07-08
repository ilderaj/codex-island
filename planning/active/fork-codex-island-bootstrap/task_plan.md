# 任务计划：fork-codex-island-bootstrap

## 任务目标

将上游仓库 `ericjypark/codex-island` fork 到用户 GitHub 账号远端；在 fork 远端创建 `dev` 分支；把仓库同步到当前 workspace；本地建立并对齐 `main` 与 `dev` 分支，分别追踪远端 `origin/main` 与 `origin/dev`，为后续自定义改动做准备。

## 当前轮次分类

- 任务级别：tracked task
- 当前轮次：tracked
- 是否使用 superpowers：否

## 阶段

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| 1. 初始化任务状态 | complete | 已建立 planning 三件套并记录验证口径 |
| 2. 远端 fork | complete | 已 fork 到 `ilderaj/codex-island` |
| 3. 本地同步与分支建立 | complete | 已在当前 workspace 初始化 git、连接 `origin/upstream`、建立本地 `main` / `dev` |
| 4. 验证与收尾 | complete | 已验证远端与本地 tracking 关系 |

## Mode-Aware Verification Contract

- Proof Target：用户 fork 仓库已存在；远端存在 `main` 与 `dev`；本地存在 `main` 与 `dev`；本地分支 tracking 指向正确远端分支。
- Primary Proof：`gh repo view`、`git branch -vv`、`git remote -v`、`git ls-remote --heads origin` 的实际结果。
- Backstop Proof：`git status --short --branch` 与 `git rev-parse --abbrev-ref HEAD` 交叉确认当前 checkout 状态。
- Escalation Trigger：fork 失败、远端分支创建失败、当前目录非空导致 clone 风险、或本地 tracking 与目标不一致。
- Evidence Sink：`planning/active/fork-codex-island-bootstrap/progress.md` 与 `findings.md`
- Reconcile Rule：每完成一个关键阶段即更新阶段状态，并把验证结果写回 planning 文件。
- Unacceptable Substitute：仅凭口头假设 fork 成功；仅看到 GitHub 页面存在仓库而未核对分支和 tracking。

## 约束与注意事项

- 尽量保持最小变更，只做 fork、远端分支与本地分支初始化。
- 若当前目录出现意外文件，先停下并重新评估覆盖风险。

## 错误与处理

| 问题 | 处理 |
| --- | --- |
| `gh repo fork <repo>` 在带仓库参数时不支持 `--remote=false` | 改为使用 `gh repo fork ericjypark/codex-island --clone=false`，随后手动初始化本地 remote |

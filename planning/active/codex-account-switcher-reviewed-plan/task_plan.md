# 任务计划：codex-account-switcher-reviewed-plan

## 任务目标

基于用户提供的 prompt 和当前 `Codex Island` 仓库真实结构，先使用 `goal2plan` 工作流产出一个经过只读 review 的实现计划；在用户明确要求后，按该计划实现最小、本地优先的 Codex/ChatGPT 账号切换能力，并同步更新当前项目 `.pen` 设计文件。

## 当前状态

Status: complete
Archive Eligible: no
Close Reason: implemented reviewed plan with tests, Pencil design update, docs, and smoke verification

## 当前轮次分类

- 任务级别：tracked task
- 当前轮次：tracked execution
- 是否使用 superpowers：使用 `executing-plans` + TDD；不重新打开 Goal2Plan

## 阶段

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| 1. 初始化与上下文恢复 | complete | 已读取 `goal2plan`、planning 规则、用户 prompt、现有 active task，并建立本任务三件套 |
| 2. intake sufficiency audit | complete | 已确认足以写 implementation plan；缺口属于后续实现验证，不阻塞 planning |
| 3. 当前仓库结构盘点 | complete | 已只读检查 usage/auth/settings/localization/preferences/build/test/design 相关文件 |
| 4. 起草 companion plan | complete | 已保存 plan 草稿到 `docs/superpowers/plans/2026-07-07-codex-account-switcher.md` |
| 5. read-only reviewer gate | complete | Round 1 verdict: approved with required revisions；Round 2 focused re-check verdict: approved |
| 6. 修订与同步 | complete | 已修订计划、更新 review status，并同步最终状态；本轮停止在 reviewed plan |
| 7. 执行阶段恢复与 baseline | complete | 已恢复 context、确认 `dev` 分支并通过 baseline `scripts/run-tests.sh` |
| 8. Models / parser / tests | complete | 已先写失败测试，再实现 auth model、JWT parsing、account key、registry DTO |
| 9. Registry / switching / usage integration | complete | 已实现 import、switch、refresh all、fetcher context 与 UsageStore active writeback |
| 10. Pencil-gated Settings UI | complete | 已用 Pencil MCP 更新 `.pen` Providers 账号块并通过 layout 验证；已实现 SwiftUI account block 和 localization |
| 11. Docs / verification / reconcile | complete | 已更新 README，运行 tests/build/smoke，记录证据并收尾 |

## Mode-Aware Verification Contract

- Proof Target：最小账号切换功能已按 reviewed plan 实现，保留本地优先边界，并通过 Pencil MCP 更新当前项目 `.pen` Settings UI 设计。
- Primary Proof：BDD/acceptance + operational proof，包括 parser/switch temp-dir 测试、usage fetch context 测试、`scripts/run-tests.sh`、`scripts/verify.sh`、Pencil layout validation。
- Backstop Proof：代码 diff review、manual Settings smoke checklist、README/privacy 文档核对。
- Escalation Trigger：auth file safety 无法证明、Pencil 更新失败、测试/verify 连续失败、或实现需要越过 MVP 禁区时暂停并记录 blocker。
- Evidence Sink：`planning/active/codex-account-switcher-reviewed-plan/findings.md`、`progress.md`、`.pen` validation output、test/build output。
- Reconcile Rule：每完成一个执行阶段，同步测试结果、变更文件、风险和下一步；完成时记录最终验证证据。
- Unacceptable Substitute：只做 UI 不做 file-safety 测试；只改代码不更新 `.pen`；只跑 build 不验证账号切换安全；隐式刷新所有账号。

## 约束与注意事项

- 此前 planning 轮次不得修改产品代码；当前用户已明确要求执行 reviewed plan。
- 涉及 UI 的执行阶段必须先通过 Pencil MCP 修改 `docs/design/Codex_Island_Design.pen`，不得用 shell 直接读取或编辑 `.pen` 文件。
- 中文用于对话、计划与 review 结果；代码相关文件名、类型名、UI string key、commit/PR 文案保持英文。

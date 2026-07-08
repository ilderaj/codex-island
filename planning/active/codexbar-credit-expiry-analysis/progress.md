# 进度记录：codexbar-credit-expiry-analysis

## 2026-07-05 21:28:05 UTC+8

- 已按仓库规则将本任务归类为 tracked task。
- 已读取并采用技能：`using-superpowers`、`planning-with-files`。
- 已恢复当前仓库的 `planning/active/` 现状，并确认本任务使用独立 task id。
- 已确认本轮为只读分析，不做产品代码修改。
- 下一步：定位 CodexBar 0.39.0 中与 credit expiry 展示相关的 release、commit、代码路径，并同步盘点当前仓库的接入点。

## 2026-07-05 21:29:16 UTC+8

- 已定位外部 release：`CodexBar 0.39.0` / tag `v0.39.0`。
- 已确认该功能不是孤立 UI 文案，而是 “credit expiry inventory + timeline summary” 形式的展示增强。
- 已在临时目录检出 `CodexBar` 源码，并初步锁定 credit 相关实现集中在 `CreditsModels.swift`、`UsageFetcher.swift`、`CLIRenderer.swift`。
- 已同步盘点当前仓库：现有代码只有 usage 百分比与 provider 设置结构，尚未看到 credit balance / expiry 领域模型。
- 下一步：深入读外部类型定义和 UI 消费路径，确认其机制，然后映射到当前仓库的缺口与可行方案。

## 2026-07-05 21:32:04 UTC+8

- 已确认 `CodexBar` 的机制分层为：
  - 额外 OAuth 请求抓 reset-credit 原始数组
  - `available inventory` 领域清洗与排序
  - 统一 `presentation` 转换为菜单 / 设置 / 通知可复用的摘要
  - 3 天内到期 credits 的去重通知
- 已定位外部主引入 commit `a1da184` 与后续压缩摘要 commit `c5cf41c`。
- 已确认当前仓库的主要缺口不在“文案”而在：
  - 没有 credit inventory 领域模型
  - 没有额外 reset-credit fetch 流程
  - 没有 provider detail 级 UI 容器承载 timeline 摘要
- 下一步：基于这些差异给出当前项目中的可行性分级和建议落点。

## 2026-07-06 14:28:12 UTC+8

- 已将用户提供的本地探针方案与 `CodexBar` 做逐层对比。
- 已确认两者在“调用什么数据”上相近，在“如何包裹成稳定产品能力”上差异较大。
- 已形成当前项目的吸收方向：优先吸收精炼的数据分层与摘要展示，不急于吸收完整的凭据管理、通知和重型设置页。

## 2026-07-07 21:57:03 UTC+8

- 已按用户要求使用 `goal2plan` 产出 reviewed implementation plan，并停止在计划审阅点。
- Companion plan: `docs/superpowers/plans/2026-07-07-codex-reset-credits-impl.md`
- 计划范围：
  - 新增 `CodexResetCredits` 模型 / inventory / presentation。
  - 后台通过 active `CodexAuthContext` best-effort 读取 reset-credit detail endpoint。
  - `UsageStore` 先发布正常 Codex usage，再用独立短超时任务补挂 reset credits，避免拖慢现有 UI。
  - 当时计划为 `SettingsView` Codex provider 区新增 compact `Reset credits` summary row；该前端落点已在 2026-07-08 执行轮次被用户确认的 expanded usage 设计取代。
  - 覆盖 `scripts/run-tests.sh` 和 `./scripts/verify.sh` 验证。
- Read-only reviewer round 1 verdict: changes requested；已修复 undefined token、active account context 说明、以及 reset fetch 阻塞 usage 的设计问题。
- Read-only reviewer round 2 verdict: approved；无阻断 findings。
- 本轮未执行产品代码实现。

## 2026-07-07 23:51:11 UTC+8

- 已按用户要求只更新 Pencil 设计文件：`docs/design/Codex_Island_Design.pen`。
- 设计落点：`Island States` 中现有 `Expanded Usage`，不新增 reset credits 独立 state。
- 视觉处理：在 Codex 两个 usage ring 下方、footer hairline 上方增加一条低权重 `Reset credits` 摘要行，示例态为 `2 available`、`3h`、`∞ no expiry`。
- 验证结果：Pencil `snapshot_layout` 返回 `No layout problems.`；`Expanded Usage` 截图确认未破坏现有主构图。
- 本轮仍未执行产品代码实现。

## 2026-07-08 00:06:31 UTC+8

- 已按用户 review 通过的 `.pen` 设计更新并执行 implementation plan。
- Plan 更新：
  - 前端 surface 从 Settings provider row 调整为 `UsageView` / expanded usage / Codex `ChartsBlock` 内 secondary row。
  - 明确不新增 island state，不进入 collapsed / compact / peek。
- 实现内容：
  - 新增 `Sources/Usage/CodexResetCredits.swift`，包含 response DTO、domain model、available inventory、compact presentation。
  - `AppUsage` 新增 `codexResetCredits: CodexResetCreditsSnapshot?`，默认 `nil`。
  - `UsageFetcher` 新增 `fetchCodexResetCredits(context:timeout:)`，使用 active `CodexAuthContext.accessToken` 和可选 `ChatGPT-Account-ID`，失败返回 `nil`。
  - `UsageStore` 先发布正常 Codex usage，再用独立可取消 task best-effort 补挂 reset credits；demo mode 提供 `2 available · 3h · No expiry` 数据。
  - `UsageView` 在 Codex expanded usage block 下方增加 `ResetCreditsSummaryRow`，无 presentation 时隐藏。
  - `Tests/ResolveUsageTests.swift` 和 `scripts/run-tests.sh` 覆盖 reset credits inventory / presentation / decoding。
- Verification:
  - 红灯验证：`./scripts/run-tests.sh` 先因 `CodexResetCredit` / `CodexResetCreditsSnapshot` / `CodexResetCreditsResponse` 不存在而失败。
  - `./scripts/run-tests.sh`: PASS。
  - `./scripts/verify.sh`: PASS，输出包含 `✓ built ./build/CodexIsland.app (0.1.13)` 和 `✓ launched cleanly`。
  - `CODEXISLAND_DEMO=1 ./build/CodexIsland.app/Contents/MacOS/CodexIsland` demo launch: PASS (`demo launch clean`)。
- Live endpoint check 未强制执行；没有打印、记录或持久化任何 token。
- 交互式 app 视觉 review 未自动完成；截图只确认了已 review 通过的 Pencil 设计仍在前台可见。

## 2026-07-08 00:19:53 UTC+8

- 已按用户要求使用 `finishing-a-development-branch` 和 `autonomous-release-closure` 执行收尾评估。
- Verification:
  - `./scripts/run-tests.sh`: PASS。
  - `./scripts/verify.sh`: PASS，输出包含 `✓ built ./build/CodexIsland.app (0.1.13)` 和 `✓ launched cleanly`。
- Environment assessment:
  - 当前为普通 repo checkout：`GIT_DIR == GIT_COMMON`。
  - 当前分支：`dev`。
  - upstream：`origin/dev`。
  - `origin/HEAD`: `origin/main`。
  - 当前 `dev` 与 `origin/dev` / `origin/main` 指向同一提交 `5629861`；当前功能尚未形成独立 commit。
  - `gh pr status` 未返回当前分支 PR 证据。
- Closure result:
  - 状态：`blocked-with-evidence`。
  - 原因：工作树包含本任务 reset credits 改动，也包含本轮前已有 account-switcher / README / Settings / planning / design 等未提交改动；没有单一可证明安全的 feature branch、PR 或 promotion chain。
  - 按 closure skill，当前不能擅自 merge、push、discard 或 cleanup。
- 下一步需要用户选择：
  - 拆分并创建 reset-credits-only branch/commit。
  - 创建包含当前 dirty worktree 的 combined branch/PR。
  - 保留当前 workspace，不做集成动作。

## 2026-07-08 10:24:35 UTC+8

- 用户选择收尾选项 2：创建包含当前 dirty worktree 的 combined branch/PR。
- 已创建分支：`codex/combined-reset-credits-account-switcher`。
- Staging scope:
  - 包含代码、资源、本地化、测试、脚本、docs/design、docs/superpowers/plans、planning/active。
  - 明确排除本地运行态 `.harness/`。
- `git diff --check`: PASS。

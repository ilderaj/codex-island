# 发现记录：codexbar-credit-expiry-analysis

## 2026-07-05 21:28:05 UTC+8

- 当前 workspace：`/Users/jared/Personal Projects/Codex Island`
- 当前仓库已经存在一个独立 active task：`planning/active/fork-codex-island-bootstrap/`，本次分析单独使用 `planning/active/codexbar-credit-expiry-analysis/`，避免混淆。
- 当前仓库目录结构显示这是一个 Swift/macOS 菜单栏应用项目，关键目录包括：`Sources/Model`、`Sources/Usage`、`Sources/Views`、`Sources/Window`、`Sources/Update`。
- 当前 Git 状态显示未跟踪目录为 `.harness/` 与 `planning/`；本次分析不会改动产品代码。

## 2026-07-05 21:29:16 UTC+8

- GitHub 最新 release 已定位为 `steipete/CodexBar` 的 [`v0.39.0`](https://github.com/steipete/CodexBar/releases/tag/v0.39.0)，发布时间为 2026-07-04 20:01:15Z。
- 该 release 对应的新增点不只是“显示更多 expiry 字段”，还明确包含一条 changed 项：将 reset-credit expiry inventory 压缩为“single scannable timeline”，说明其核心是先形成 credit inventory，再在不同 UI 面复用同一摘要展示。
- 在临时检出的 `CodexBar` 源码中，credit expiry 相关的核心类型集中在：
  - `Sources/CodexBarCore/CreditsModels.swift`
  - `Sources/CodexBarCore/UsageFetcher.swift`
  - `Sources/CodexBarCLI/CLIRenderer.swift`
- 当前仓库本地搜索结果显示，还没有 `credit` / `balance` / `expiry` 这类 quota-balance 领域模型；现有结构主要围绕：
  - `Sources/Usage/UsageFetcher.swift`：拉取 Codex / Claude usage 百分比
  - `Sources/Usage/UsageStore.swift`：刷新与聚合 usage
  - `Sources/Views/SettingsView.swift`：provider 设置展示
  - `Sources/Views/PanelHeader.swift`、`Views/NotchPeekPill.swift`：面板与 glance UI

## 2026-07-05 21:31:02 UTC+8

- `CodexBar` 的实现不是“UI 直接展示原始 credits 数组”，而是先在 `CreditsModels.swift` 中定义：
  - `CodexRateLimitResetCreditsSnapshot`：持久化快照
  - `CodexRateLimitResetCreditInventory`：按 `status == available`、`expiresAt > now || nil` 过滤后形成的可用库存
  - 排序规则：有 expiry 的排前面，并按最早到期优先；无 expiry 的 credit 保留在后面
- `CodexResetCreditsPresentation.make(...)` 负责把库存转换成展示模型：
  - 主文案：`N available`
  - 明细项：`Expires <time>` 或 `No expiry`
  - 紧凑摘要：最多显示前 4 项 `compactExpiryText`，多余项折叠为 `+N`
  - 同一展示模型同时服务 menu 卡片、provider settings inline row、notification 文案
- `CodexBar` 的“nearing expiry”有明确机制，不是只靠 UI 强调：
  - `CodexResetCreditExpiryNotifier` 会筛出 `availableInventory(at: now)` 中 `expiresAt - now <= 3 days` 的 credits
  - 用 `credit.id + expiresAt` 做 SHA256 fingerprint，写入 `UserDefaults` 去重，避免跨账户刷新和重复弹通知
- `CodexBar` 的接入顺序是先数据后展示：
  - `UsageSnapshot` 新增 `codexResetCredits`
  - `UsageStore+CodexResetCredits.swift` 在主 usage 刷新成功后，以 best-effort 方式补挂 reset credits 快照，并在成功后触发 nearing-expiry notifier

## 2026-07-05 21:32:04 UTC+8

- 外部实现的来源 commit 已定位：
  - [`a1da184`](https://github.com/steipete/CodexBar/commit/a1da184c6397b32725d5010d442c2b5f8e1eba11) `Show read-only Codex reset credit inventory (#1690)`：首次引入读取、库存、settings/menu 展示、通知
  - [`c5cf41c`](https://github.com/steipete/CodexBar/commit/c5cf41c94411bd783aaf0ebf16320eb65eaf63f6) `refactor: compact reset credit expiries (#1902)`：把逐条 expiry 收敛成 timeline 摘要，并补 `No expiry`
- 关键数据源差异：
  - `CodexBar` 读取 `~/.codex/auth.json` 中更完整的 OAuth 凭据，包括 `access_token`、`refresh_token`、`account_id`
  - reset-credit 请求不是当前项目使用的 `/backend-api/wham/usage`，而是单独的 `fetchRateLimitResetCredits(...)`
  - 请求会带 `Authorization`、`OpenAI-Beta: codex-1`、`originator: Codex Desktop`、`ChatGPT-Account-ID`
- 当前仓库的 Codex 数据面明显更薄：
  - `Sources/Usage/UsageFetcher.swift` 只读取 `~/.codex/auth.json` 的 `tokens.access_token`
  - `AppUsage` 只承载 `fiveHour`、`weekly`、`plan`
  - `UsageStore` 只刷新 usage 百分比，没有扩展字段或补充请求链
  - `SettingsView` 目前 provider 行只显示 `synced + 5h/7d 百分比`，没有 provider detail 页或可承载 timeline 的 inline metrics 区

## 2026-07-06 14:28:12 UTC+8

- 用户提供的本地查询方式与 `CodexBar` 在“接口意图”上高度一致：
  - 都从 `~/.codex/auth.json` 读取 `tokens.access_token`
  - 都调用 usage 接口拿 `available_count`
  - 都调用 reset-credit detail 接口拿每个 credit 的 `status` / `title` / `granted_at` / `expires_at`
- 但两者在“产品化包裹层”上有明确差异：
  - 用户方案只依赖 `access_token`，不读 `refresh_token`、`account_id`
  - 用户方案是一次性探针脚本，直接输出最小所需字段，不维护持久 snapshot / inventory / notification 状态
  - 用户方案把时间转换放在脚本层；`CodexBar` 则把时间保留为 `Date`，交给展示层按不同 reset style 渲染
- 接口/请求头也有差异：
  - 用户方案：`Authorization` + `Accept` + 浏览器型 `User-Agent`
  - `CodexBar`：`Authorization` + `Accept` + 自定义 `User-Agent: CodexBar`
  - reset-credit detail 请求额外加 `OpenAI-Beta: codex-1`、`originator: Codex Desktop`，且在有 `account_id` 时带 `ChatGPT-Account-ID`
- 路径层面，`CodexBar` 的 fetcher 支持两套 base-url 归一化：
  - usage：`/backend-api/wham/usage` 或 `/api/codex/usage`
  - reset credits：`/backend-api/wham/rate-limit-reset-credits`
  - 用户提供的路径写法是 `https://chatgpt.com/backend-api/codex/usage` 与 `https://chatgpt.com/backend-api/codex/rate-limit-reset-credits`
- 对“精炼接入”的启发：
  - 值得吸收的是“snapshot -> inventory -> presentation” 三层分离，而不是整套 OAuth 凭据管理、通知去重、provider detail UI
  - 当前项目最小接入完全可以先沿用“只读 access_token + best-effort fetch”思路，不必一开始引入 refresh/account 逻辑

## 2026-07-07 21:57:03 UTC+8

- Reviewed implementation plan 已落地为 `docs/superpowers/plans/2026-07-07-codex-reset-credits-impl.md`。
- 计划修订时发现当前工作树已经包含 Codex account 相关源码：
  - `Sources/Usage/CodexAuthModels.swift`
  - `Sources/Usage/CodexAuthParser.swift`
  - `Sources/Usage/CodexAccountStore.swift`
  - `Sources/Views/Settings/CodexAccountsBlock.swift`
- 因此 reset credits 计划不再假设“没有 active account context”，而是复用 active `CodexAuthContext.accessToken` 和可选 `chatgptAccountId`。
- 审阅后的关键设计决定：
  - reset credits 不在 `fetchCodex(context:)` 内同步等待，避免拖慢现有 usage 刷新。
  - `UsageStore` 在 normal Codex usage 发布后，用独立短超时 task 补挂 reset credits。
  - 第一版不做账号切换、refresh token、通知、详情页或 registry 持久化 reset credits。
  - 当时计划为 Settings UI 新增一条 compact summary row；该 UI 落点已在用户 review `.pen` 后被 expanded usage Codex block 取代。

## 2026-07-07 23:51:11 UTC+8

- Island states 设计结论：reset credits 有效期不需要新增独立 state，放入现有 `Expanded Usage` 更合理。
- 原因：
  - reset credits 是 Codex usage 的补充读数，不是主状态入口。
  - collapsed / compact / peek 层级应继续保持轻量，避免把低频信息抬成主信息层。
  - expanded usage 已经承载 provider-level usage 细节，是展示 expiry summary 的自然位置。
- Pencil 变更：
  - 在 `docs/design/Codex_Island_Design.pen` 的 `Island States` / `Expanded Usage` / `Usage Panel` 内新增 `Usage Reset Credits` 行。
  - 该行位于 Codex usage rings 下方、footer hairline 上方。
  - 文案和层级保持 secondary：`Reset credits`、`2 available`、`3h`、`∞ no expiry`。
- 后续实现启发：SwiftUI 接入时优先作为 expanded usage 内部的 secondary summary row；无 reset credits 或 fetch failed 时应隐藏该行，而不是改变 island state。

## 2026-07-08 00:06:31 UTC+8

- 执行时确认当前 SwiftUI 前端落点不是 `SettingsView`，而是 `UsageView` 中的 `ChartsBlock`：
  - `ExpandedView` 只组合 `PanelHeader` / `PagedContent` / `PanelFooter`。
  - usage 页面主体由 `UsageView` 根据 provider visibility 渲染 Claude / Codex `ChartsBlock`。
  - 因此 reset credits row 应挂在 Codex `ChartsBlock` 里，而不是 Settings Providers tab。
- 最终实现策略：
  - `UsageFetcher.fetchCodex(context:)` 仍只负责原 usage endpoint。
  - `UsageFetcher.fetchCodexResetCredits(context:timeout:)` 独立请求 detail endpoint，失败时返回 `nil`。
  - `UsageStore.refresh()` 读取一次 active `CodexAuthContext`，usage 发布后再启动可取消 reset fetch；若 active account key 已变化则丢弃旧结果。
  - `UsageView` 只在 `provider == .codex` 且 presentation 存在时显示 reset row。
- 需要后续注意：
  - 当前工作树在本轮前已有 account-switcher / localization / README 等未提交改动，后续提交或 PR 需要拆分范围。
  - 本轮未执行 live endpoint check；真实账号下若 endpoint drift 或 401/403，UI 会保持隐藏 row，不影响现有 usage。

## 2026-07-08 00:19:53 UTC+8

- 收尾评估发现当前不是可直接 finish 的 isolated feature branch：
  - `dev` 是当前分支，且 upstream 为 `origin/dev`。
  - `dev` / `origin/dev` / `origin/main` 当前都指向 `5629861`。
  - reset credits 实现仍是未提交工作树改动。
- 工作树边界不干净：
  - 与 reset credits 直接相关：`Sources/Usage/CodexResetCredits.swift`、`AppUsage.swift`、`UsageFetcher.swift`、`UsageStore.swift`、`UsageView.swift`、`Tests/ResolveUsageTests.swift`、`scripts/run-tests.sh`、localization、reset credits implementation plan、当前 task planning。
  - 与其他任务相关或进入本轮前已存在：`Sources/Usage/CodexAccountStore.swift`、`CodexAuthModels.swift`、`CodexAuthParser.swift`、`Sources/Views/Settings/CodexAccountsBlock.swift`、`Tests/CodexAccountTests.swift`、`SettingsView.swift`、README、account switcher plan、design `.pen` 和其他 active task planning。
- 因为 reset credits 依赖 active `CodexAuthContext` 类型，而这些类型来自 account-switcher 未提交文件，后续如果要拆 reset-credits-only PR，需要先决定：
  - 把 account-switcher 作为前置/同 PR 纳入；
  - 或先落地 account-switcher，再基于其 commit 创建 reset credits branch；
  - 或重写 reset credits，使其暂时不依赖 account-switcher context。

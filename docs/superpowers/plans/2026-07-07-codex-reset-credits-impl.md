# Codex Reset Credits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 CodexIsland 中以小而克制的方式展示当前 Codex 登录 profile 的 reset credits：可用数量、最近到期 timeline、以及 non-expiring credits。

**Architecture:** 第一版只接 active `~/.codex/auth.json`，沿用当前 `UsageFetcher -> AppUsage -> UsageStore -> UsageView` 路径，不引入账号切换、token refresh、系统通知或独立详情页。实现分为 `raw response -> inventory -> presentation` 三层：后台只做 best-effort 读取，模型层过滤和排序，前端只在 expanded usage 的 Codex block 里展示一条 compact secondary summary。

**Tech Stack:** Swift 5 / Foundation / SwiftUI / bare `swiftc` build, no SwiftPM, no XCTest.

**Active task path:** `planning/active/codexbar-credit-expiry-analysis/`

**Review status:** approved after read-only reviewer round 2

## Global Constraints

- Conversation and plan prose use Chinese; code, comments, UI strings, commit messages, and docs copy use English.
- 第一版只读 active `CodexAuthContext.accessToken`，不读取或刷新 `refresh_token`。
- 第一版只面向当前 active Codex profile，不做 multi-account reset inventory。
- 不打印、不记录、不持久化 access token 或完整 auth JSON。
- reset credits 获取失败不能让现有 Codex usage 百分比失败。
- UI 保持 CodexIsland 现有密度和安静风格，不新增 settings tab、不新增弹窗、不新增系统通知。
- 当前项目没有 SwiftPM/XCTest；测试通过 `scripts/run-tests.sh` 编译执行。
- 新增 Swift 文件放在 `Sources/` 下即可被 `build.sh` 的 `Sources/**/*.swift` 收进 app build。

---

## Intake Sufficiency Audit

已知足够：

- Root objective：基于用户本地探针和 CodexBar 0.39.0 的机制，计划一个 reset credits MVP。
- Scope boundary：执行 reviewed implementation plan；不扩大到账号切换、token refresh、通知或详情页。
- Backend source：active `CodexAuthContext` 的 `accessToken` 和可选 `chatgptAccountId`，请求 ChatGPT backend usage 和 reset-credit detail endpoint。
- Frontend surface：用户已 review 通过 Pencil 设计，reset credits 放在 `Island States` / `Expanded Usage` 内 Codex 两个 usage ring 下方、footer hairline 上方，作为 secondary summary row；不新增 island state。
- Validation：新增纯 Swift 解析 / inventory / presentation tests，跑 `scripts/run-tests.sh` 与 `./scripts/verify.sh`。

刻意不纳入第一版：

- `refresh_token` 刷新。
- 账号切换、非 active account reset inventory、以及任何 auth snapshot 写入。
- 临期通知、fingerprint 去重、菜单子页、独立 provider detail view。
- 把 reset credits 带进 notch peek pill、collapsed/compact state、独立 state、或任何高权重 hero 区。

## Mode-Aware Verification Contract

- Proof Target：当前 active Codex profile 的 reset credits 能被 best-effort 拉取、解析、过滤、排序，并在 expanded usage 的 Codex block 中以 compact secondary summary 展示，且不破坏现有 usage 刷新。
- Primary Proof：`scripts/run-tests.sh` 覆盖解析、inventory、presentation、以及 `AppUsage` 默认兼容；`./scripts/verify.sh` 覆盖 app build 和 1 秒 smoke launch。
- Backstop Proof：demo mode 人工检查 expanded usage 中 Codex block 下方显示 `Reset credits` summary，且无 credits 或请求失败时 UI 不出现噪声。
- Escalation Trigger：reset-credit endpoint 在 active token 下返回稳定 401/403、JSON shape 与探针不一致、或新增字段导致 existing usage tests 需要大范围重写。
- Evidence Sink：执行时把命令结果和 UI 验证结果写回 `planning/active/codexbar-credit-expiry-analysis/progress.md`。
- Reconcile Rule：如果 endpoint 或 UI surface 需要降级，更新本计划和 `findings.md` 后再继续；不要在实现中悄悄扩大到账号切换或 token refresh。
- Unacceptable Substitute：只显示 `available_count` 而不展示 expiry / `No expiry`；把 reset-credit fetch 失败当作 Codex usage fetch 失败；把 raw JSON 字符串直接拼到 UI。

## File Structure

- Create `Sources/Usage/CodexResetCredits.swift`
  负责 reset-credit response DTO、domain model、inventory filtering/sorting、compact presentation。
- Modify `Sources/Usage/AppUsage.swift`
  给 `AppUsage` 增加 `codexResetCredits: CodexResetCreditsSnapshot?`，默认 `nil`，保持 Claude 和现有调用兼容。
- Modify `Sources/Usage/UsageFetcher.swift`
  新增独立 `fetchCodexResetCredits(context:timeout:)`，只负责短超时 best-effort 读取，不阻塞 `fetchCodex(context:)` 的 usage 返回。
- Modify `Sources/Views/UsageView.swift`
  在 expanded usage 的 Codex `ChartsBlock` 内新增一条轻量 `Reset credits` summary row；无 presentation 时隐藏。
- Modify `Tests/ResolveUsageTests.swift`
  添加 reset credits domain tests，保持现有 custom test harness。
- Modify `scripts/run-tests.sh`
  把 `Sources/Usage/CodexResetCredits.swift` 加入测试编译输入。
- Modify `Resources/en.lproj/Localizable.strings` and `Resources/zh-Hans.lproj/Localizable.strings`
  补齐新增 UI strings。

## Endpoint Policy

第一版优先使用用户已验证路径：

```text
GET https://chatgpt.com/backend-api/codex/usage
GET https://chatgpt.com/backend-api/codex/rate-limit-reset-credits
```

请求头：

```http
Authorization: Bearer <tokens.access_token>
Accept: application/json
User-Agent: CodexIsland
OpenAI-Beta: codex-1
originator: Codex Desktop
ChatGPT-Account-ID: <CodexAuthContext.chatgptAccountId when present>
```

`OpenAI-Beta` 和 `originator` 只加在 reset-credit detail 请求上。当前源码已经有 active `CodexAuthContext.chatgptAccountId`，所以 reset-credit 请求在该字段存在时也发送 `ChatGPT-Account-ID`。这不是账号切换功能，只是复用 active profile 的上下文，降低多 workspace/profile 下取错 inventory 的风险。

`fetchCodex()` 当前使用 `https://chatgpt.com/backend-api/wham/usage`。执行时先验证是否继续保留现有 usage endpoint；如果只为了 `available_count` 而切 usage endpoint，会扩大风险。MVP 可以从 detail endpoint 得到实际 credits 数组，因此 usage endpoint 的 `available_count` 只作为可选一致性字段，不作为第一版必须依赖。

Reset-credit fetch 必须与 usage fetch 的用户体验解耦：usage 成功后应立即更新 `UsageStore.codex`，reset credits 通过独立短超时任务补挂。失败或超时只让 `codexResetCredits` 保持 `nil`，不能延迟或覆盖现有 usage 百分比。

## Task 1: Model And Presentation

**Files:**

- Create: `Sources/Usage/CodexResetCredits.swift`
- Modify: `Sources/Usage/AppUsage.swift`
- Test: `Tests/ResolveUsageTests.swift`
- Modify: `scripts/run-tests.sh`

**Interfaces:**

- Produces: `CodexResetCreditsSnapshot`, `CodexResetCredit`, `CodexResetCreditInventory`, `CodexResetCreditsPresentation`
- Produces: `AppUsage.codexResetCredits: CodexResetCreditsSnapshot?`
- Consumes later: `UsageStore` attaches snapshot after usage is published; `UsageView` reads `usage.codexResetCredits?.presentation(now:)`

- [x] **Step 1: Add failing model tests**

Add test helpers and assertions to `Tests/ResolveUsageTests.swift` after existing Codex account tests are invoked, or in a small static helper inside the same file:

```swift
static func runCodexResetCreditTests() {
    let now = ISO8601DateFormatter().date(from: "2026-07-07T06:00:00Z")!
    let expiringSoon = CodexResetCredit(
        status: "available",
        title: "Reset",
        grantedAt: ISO8601DateFormatter().date(from: "2026-07-06T06:00:00Z"),
        expiresAt: ISO8601DateFormatter().date(from: "2026-07-07T09:30:00Z")
    )
    let nonExpiring = CodexResetCredit(
        status: "available",
        title: "Reset",
        grantedAt: ISO8601DateFormatter().date(from: "2026-07-06T06:00:00Z"),
        expiresAt: nil
    )
    let redeemed = CodexResetCredit(status: "redeemed", title: "Used", grantedAt: nil, expiresAt: nil)
    let snapshot = CodexResetCreditsSnapshot(
        credits: [nonExpiring, redeemed, expiringSoon],
        availableCount: 2,
        updatedAt: now
    )

    let inventory = snapshot.availableInventory(now: now)
    expect(inventory.credits.count == 2, "Reset credits inventory keeps available credits only")
    expect(inventory.credits.first?.expiresAt == expiringSoon.expiresAt, "Reset credits inventory sorts expiring credits first")
    expect(inventory.credits.last?.expiresAt == nil, "Reset credits inventory keeps non-expiring credits last")
    expect(snapshot.presentation(now: now)?.summary == "2 available · 3h · No expiry", "Reset credits presentation is compact")
}
```

Call it from `main()`:

```swift
runCodexResetCreditTests()
```

- [x] **Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh`

Expected: compile failure because `CodexResetCredit` and related types do not exist.

- [x] **Step 3: Create model and presentation implementation**

Create `Sources/Usage/CodexResetCredits.swift`:

```swift
import Foundation

struct CodexResetCreditsSnapshot: Equatable {
    let credits: [CodexResetCredit]
    let availableCount: Int?
    let updatedAt: Date

    func availableInventory(now: Date = Date()) -> CodexResetCreditInventory {
        CodexResetCreditInventory(credits: credits, now: now)
    }

    func presentation(now: Date = Date()) -> CodexResetCreditsPresentation? {
        CodexResetCreditsPresentation(snapshot: self, now: now)
    }
}

struct CodexResetCredit: Equatable {
    let status: String
    let title: String?
    let grantedAt: Date?
    let expiresAt: Date?
}

struct CodexResetCreditInventory: Equatable {
    let credits: [CodexResetCredit]

    init(credits: [CodexResetCredit], now: Date) {
        self.credits = credits
            .filter { credit in
                credit.status == "available" && (credit.expiresAt.map { $0 > now } ?? true)
            }
            .sorted { lhs, rhs in
                switch (lhs.expiresAt, rhs.expiresAt) {
                case let (l?, r?):
                    if l != r { return l < r }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }
                return (lhs.title ?? "") < (rhs.title ?? "")
            }
    }
}

struct CodexResetCreditsPresentation: Equatable {
    let title = "Reset credits"
    let summary: String

    init?(snapshot: CodexResetCreditsSnapshot, now: Date = Date()) {
        let inventory = snapshot.availableInventory(now: now)
        guard !inventory.credits.isEmpty else { return nil }
        let countText = inventory.credits.count == 1 ? "1 available" : "\(inventory.credits.count) available"
        let expiryParts = inventory.credits.prefix(3).map { Self.expiryText(for: $0, now: now) }
        let hidden = inventory.credits.count - expiryParts.count
        let suffix = hidden > 0 ? ["+\(hidden)"] : []
        self.summary = ([countText] + expiryParts + suffix).joined(separator: " · ")
    }

    private static func expiryText(for credit: CodexResetCredit, now: Date) -> String {
        guard let expiresAt = credit.expiresAt else { return "No expiry" }
        let remaining = max(0, expiresAt.timeIntervalSince(now))
        if remaining >= 86_400 {
            return "\(Int(remaining / 86_400))d"
        }
        if remaining >= 3_600 {
            return "\(Int(remaining / 3_600))h"
        }
        return "\(max(1, Int(remaining / 60)))m"
    }
}
```

- [x] **Step 4: Add optional field to `AppUsage`**

Modify `Sources/Usage/AppUsage.swift`:

```swift
struct AppUsage {
    var fiveHour: WindowUsage
    var weekly: WindowUsage
    /// Provider-reported plan tier — Claude's `subscriptionType` (free/pro/max)
    /// or Codex's `plan_type` (free/plus/pro). nil when unknown.
    var plan: String?
    var codexResetCredits: CodexResetCreditsSnapshot?

    init(
        fiveHour: WindowUsage,
        weekly: WindowUsage,
        plan: String? = nil,
        codexResetCredits: CodexResetCreditsSnapshot? = nil
    ) {
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.plan = plan
        self.codexResetCredits = codexResetCredits
    }
}
```

- [x] **Step 5: Include new source in test runner**

Modify `scripts/run-tests.sh`:

```bash
  Sources/Usage/CodexResetCredits.swift \
```

Place it immediately after `Sources/Usage/AppUsage.swift`.

- [x] **Step 6: Run tests**

Run: `./scripts/run-tests.sh`

Expected: all existing tests plus reset credit tests pass.

## Task 2: Backend Fetch And Decode

**Files:**

- Modify: `Sources/Usage/CodexResetCredits.swift`
- Modify: `Sources/Usage/UsageFetcher.swift`
- Test: `Tests/ResolveUsageTests.swift`

**Interfaces:**

- Produces: `CodexResetCreditsResponse.decode(data:updatedAt:) throws -> CodexResetCreditsSnapshot`
- Produces: `UsageFetcher.fetchCodexResetCredits(context:timeout:) async -> CodexResetCreditsSnapshot?`
- Consumes: `UsageStore.refresh()` starts this fetch after publishing the normal Codex usage result

- [x] **Step 1: Add decoding test**

Add this test to `runCodexResetCreditTests()`:

```swift
let json = """
{
  "available_count": 2,
  "credits": [
    {
      "status": "available",
      "title": "Reset",
      "granted_at": "2026-07-06T06:00:00Z",
      "expires_at": "2026-07-07T09:30:00Z"
    },
    {
      "status": "available",
      "title": "Reset",
      "granted_at": "2026-07-06T06:00:00Z",
      "expires_at": null
    }
  ]
}
""".data(using: .utf8)!
let decoded = try! CodexResetCreditsResponse.decode(data: json, updatedAt: now)
expect(decoded.availableCount == 2, "Reset credits response decodes available_count")
expect(decoded.credits.count == 2, "Reset credits response decodes credits")
expect(decoded.credits.last?.expiresAt == nil, "Reset credits response decodes null expiry")
```

- [x] **Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh`

Expected: compile failure because `CodexResetCreditsResponse` does not exist.

- [x] **Step 3: Add response DTO and decoder**

Append to `Sources/Usage/CodexResetCredits.swift`:

```swift
struct CodexResetCreditsResponse: Decodable {
    let availableCount: Int?
    let credits: [Credit]

    private enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case credits
    }

    struct Credit: Decodable {
        let status: String
        let title: String?
        let grantedAt: Date?
        let expiresAt: Date?

        private enum CodingKeys: String, CodingKey {
            case status
            case title
            case grantedAt = "granted_at"
            case expiresAt = "expires_at"
        }

        var model: CodexResetCredit {
            CodexResetCredit(
                status: status,
                title: title,
                grantedAt: grantedAt,
                expiresAt: expiresAt
            )
        }
    }

    static func decode(data: Data, updatedAt: Date = Date()) throws -> CodexResetCreditsSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let seconds = ISO8601DateFormatter()
            seconds.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: raw) ?? seconds.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        let response = try decoder.decode(Self.self, from: data)
        return CodexResetCreditsSnapshot(
            credits: response.credits.map(\.model),
            availableCount: response.availableCount,
            updatedAt: updatedAt
        )
    }
}
```

- [x] **Step 4: Add best-effort fetcher**

In `Sources/Usage/UsageFetcher.swift`, add:

```swift
static func fetchCodexResetCredits(
    context: CodexAuthContext,
    timeout: TimeInterval = 3
) async -> CodexResetCreditsSnapshot? {
    guard let url = URL(string: "https://chatgpt.com/backend-api/codex/rate-limit-reset-credits") else {
        return nil
    }
    var req = URLRequest(url: url)
    req.timeoutInterval = timeout
    req.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("CodexIsland", forHTTPHeaderField: "User-Agent")
    req.setValue("codex-1", forHTTPHeaderField: "OpenAI-Beta")
    req.setValue("Codex Desktop", forHTTPHeaderField: "originator")
    if let accountID = context.chatgptAccountId {
        req.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
    }

    do {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try CodexResetCreditsResponse.decode(data: data)
    } catch {
        return nil
    }
}
```

- [x] **Step 5: Keep `fetchCodex(context:)` focused on usage**

Do not call `fetchCodexResetCredits(context:)` inside `fetchCodex(context:)`. The successful return should remain:

```swift
return AppUsage(
    fiveHour: parseCodexWindow(rl["primary_window"]),
    weekly: parseCodexWindow(rl["secondary_window"]),
    plan: obj["plan_type"] as? String
)
```

- [x] **Step 6: Run tests**

Run: `./scripts/run-tests.sh`

Expected: all tests pass. This does not perform a live network call because tests do not call `fetchCodex()` or `fetchCodexResetCredits(context:)`.

## Task 2.5: Store-Level Best-Effort Attachment

**Files:**

- Modify: `Sources/Usage/UsageStore.swift`

**Interfaces:**

- Consumes: `CodexAuthParser.readActiveContext()`
- Consumes: `UsageFetcher.fetchCodex(context:)`
- Consumes: `UsageFetcher.fetchCodexResetCredits(context:timeout:)`
- Produces: existing usage publishes first; reset credits patch `self.codex.codexResetCredits` only if still relevant

- [x] **Step 1: Add reset task state**

Add near other task properties:

```swift
private var codexResetCreditsTask: Task<Void, Never>?
```

- [x] **Step 2: Reuse one active context for usage and reset credits**

At the start of the non-demo `refresh()` path, before creating `refreshTask`, read:

```swift
let codexContext = try? CodexAuthParser.readActiveContext()
```

Add a tiny helper near `isErrorOnly(_:)`:

```swift
private static func fetchCodexForRefresh(context: CodexAuthContext?) async -> AppUsage {
    if let context {
        return await UsageFetcher.fetchCodex(context: context)
    }
    return await UsageFetcher.fetchCodex()
}
```

Inside `refreshTask`, replace:

```swift
async let codexResult = UsageFetcher.fetchCodex()
```

with:

```swift
async let codexResult = UsageStore.fetchCodexForRefresh(context: codexContext)
```

- [x] **Step 3: Cancel stale reset-credit fetches**

At refresh start, next to `refreshTask?.cancel()`, add:

```swift
codexResetCreditsTask?.cancel()
```

- [x] **Step 4: Publish usage before reset credits**

Immediately after the existing `if !UsageStore.isErrorOnly(c) ... self.codex = c` block and before `CodexAccountStore.shared.updateActiveUsage(c)`, add:

```swift
if !UsageStore.isErrorOnly(c), let codexContext {
    let expectedAccountKey = codexContext.accountKey
    codexResetCreditsTask = Task { [weak self] in
        let resetCredits = await UsageFetcher.fetchCodexResetCredits(context: codexContext)
        if Task.isCancelled { return }
        await MainActor.run {
            guard let self else { return }
            guard (try? CodexAuthParser.readActiveContext().accountKey) == expectedAccountKey else { return }
            var updated = self.codex
            updated.codexResetCredits = resetCredits
            self.codex = updated
        }
    }
}
```

This deliberately updates reset credits after the normal usage UI has already moved. If `resetCredits` is `nil`, the expanded usage reset row stays hidden.

- [x] **Step 5: Stop reset task on shutdown**

In `stopAutoRefresh()`, add:

```swift
codexResetCreditsTask?.cancel()
codexResetCreditsTask = nil
```

- [x] **Step 6: Run tests**

Run: `./scripts/run-tests.sh`

Expected: all tests pass.

## Task 3: Expanded Usage UI

**Files:**

- Modify: `Sources/Views/UsageView.swift`
- Modify: `Resources/en.lproj/Localizable.strings`
- Modify: `Resources/zh-Hans.lproj/Localizable.strings`

**Interfaces:**

- Consumes: `usage.codex.codexResetCredits?.presentation(now:)`
- Produces: one compact row under the Codex chart tiles in expanded usage when presentation exists

- [x] **Step 1: Add compact UI helper**

In `Sources/Views/UsageView.swift`, add a compact helper near `ChartsBlock`:

```swift
struct ResetCreditsSummaryRow: View {
    let presentation: CodexResetCreditsPresentation

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(IslandColor.codex)
                .frame(width: 5, height: 5)
            Text(L10n.tr(presentation.title))
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(presentation.summary)
                .font(Typography.chip)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                }
        )
        .accessibilityLabel("\(L10n.tr(presentation.title)), \(presentation.summary)")
    }
}
```

- [x] **Step 2: Insert the row below Codex chart tiles**

Modify `ChartsBlock` so only the Codex block renders:

```swift
if provider == .codex, let presentation = usage.codexResetCredits?.presentation() {
    ResetCreditsSummaryRow(presentation: presentation)
}
```

- [x] **Step 3: Add localization keys**

Add to `Resources/en.lproj/Localizable.strings`:

```text
"Reset credits" = "Reset credits";
```

Add to `Resources/zh-Hans.lproj/Localizable.strings`:

```text
"Reset credits" = "重置额度";
```

`available` / `No expiry` are part of `CodexResetCreditsPresentation.summary` in Task 1. Keep the summary English for first MVP consistency with the approved Pencil copy.

- [x] **Step 4: Build smoke verification**

Run: `./scripts/verify.sh`

Expected: app builds and smoke-launches for 1 second.

## Task 4: Demo Data And Manual UI Check

**Files:**

- Modify: `Sources/Usage/UsageStore.swift`
- Optional Modify: `Sources/Views/UsageView.swift` only if UI spacing needs a tiny adjustment after preview

**Interfaces:**

- Consumes: `AppEnvironment.isDemo`
- Produces: demo-mode reset credits so UI can be checked without live account data

- [x] **Step 1: Add demo reset credits**

Inside `UsageStore.refresh()` demo-mode `self.codex = AppUsage(...)`, pass:

```swift
codexResetCredits: CodexResetCreditsSnapshot(
    credits: [
        CodexResetCredit(
            status: "available",
            title: "Reset",
            grantedAt: now.addingTimeInterval(-86_400),
            expiresAt: now.addingTimeInterval(3 * 3_600 + 20 * 60)
        ),
        CodexResetCredit(
            status: "available",
            title: "Reset",
            grantedAt: now.addingTimeInterval(-86_400),
            expiresAt: nil
        )
    ],
    availableCount: 2,
    updatedAt: now
)
```

- [x] **Step 2: Run smoke build**

Run: `./scripts/verify.sh`

Expected: app builds and smoke-launches.

- [x] **Step 3: Manual UI check**

Run the app with demo mode:

```bash
CODEXISLAND_DEMO=1 ./build/CodexIsland.app/Contents/MacOS/CodexIsland
```

Open expanded usage and confirm:

```text
Codex ...
Reset credits
2 available · 3h · No expiry
```

The row should read as a secondary status line, not a new feature block.

Execution note: demo-mode binary launch was clean. Interactive visual review of the running app was not forced in this session; the generated screenshot only showed the already-approved Pencil design because Pencil was the foreground app.

## Task 5: Final Verification And Sync

**Files:**

- Modify: `planning/active/codexbar-credit-expiry-analysis/progress.md`
- Modify: `planning/active/codexbar-credit-expiry-analysis/findings.md` only if endpoint behavior differs from plan assumptions

**Interfaces:**

- Consumes: command results from Tasks 1-4
- Produces: durable execution evidence

- [x] **Step 1: Run unit-style tests**

Run: `./scripts/run-tests.sh`

Expected: all tests pass.

- [x] **Step 2: Run build and smoke launch**

Run: `./scripts/verify.sh`

Expected: app builds and smoke-launches for 1 second.

- [x] **Step 3: Optional live endpoint check**

Skipped in this execution; live credential check remains optional and should only be run when the developer wants to exercise their local active Codex credentials.

Expected:

- If reset credits are available: compact row appears.
- If reset credits are absent or endpoint fails: existing usage UI remains unchanged.

- [x] **Step 4: Record evidence**

Append to `planning/active/codexbar-credit-expiry-analysis/progress.md`:

```text
- Implemented Codex reset credits MVP.
- Verification:
  - `./scripts/run-tests.sh`: PASS
  - `./scripts/verify.sh`: PASS
  - Expanded usage UI check: demo launch PASS; interactive visual review skipped
```

## Reviewer Notes

Round 1 reviewer verdict: changes requested.

Round 1 required changes integrated:

- `UsageFetcher.fetchCodexResetCredits` now takes `CodexAuthContext` and uses `context.accessToken` instead of an undefined local `token`.
- Endpoint policy now reuses active `context.chatgptAccountId` when present, without introducing account switching or auth snapshot writes.
- Reset credits now attach at `UsageStore` level through a separate short-timeout task, so normal Codex usage can publish before reset inventory returns.

Round 2 reviewer verdict: approved.

Round 2 reviewer summary:

- No blocking findings.
- Round 1 required changes are covered: reset fetcher uses `CodexAuthContext`, account id is reused when present, and reset-credit fetching is a separate `UsageStore` task after normal usage publishes.
- Residual execution risks are limited to live endpoint drift, mixed English summary copy in the MVP, and reset credits not being persisted into account registry snapshots.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-07-codex-reset-credits-impl.md`.

Recommended execution mode: inline execution with `superpowers:executing-plans`.

Reason: the write set is small, highly coupled, and easier to keep coherent in one session than with multiple worker branches. Subagent-driven execution is unnecessary for this MVP unless the implementation later expands into account-aware reset inventories or notification behavior.

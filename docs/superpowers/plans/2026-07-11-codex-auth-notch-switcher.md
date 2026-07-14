# Codex Auth Notch Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Active task:** `planning/active/codex-auth-notch-switcher/`

**Goal:** Let Codex Island compare saved Codex account usage in the expanded notch, stage an account switch, and apply it through an explicit, exact-path ChatGPT relaunch with tested local rollback.

**Architecture:** Retain `CodexAccountStore` as the persistence owner, but make its write path injectable so a failed local switch can be tested. Add a small coordinator that combines the local switch with a narrow `ChatGPTHostController`; the coordinator owns user-visible apply states while the host controller owns only exact-path discover/terminate/reopen. Add a dedicated SwiftUI account rail inside the existing Usage page, without changing compact/peek into a control surface.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Foundation, bare `swiftc` test harness, Pencil design source.

## Global Constraints

- Preserve the checked-in `docs/design/Codex_Island_Design.pen` account-rail board; re-run `snapshot_layout(..., problemsOnly: true)` before final PR review.
- Never expose, log, localize, or render access tokens, raw auth JSON, email addresses, or full account IDs.
- `ChatGPT.app` is addressed only by a fresh, symlink-resolved absolute path whose app name, bundle metadata, executable metadata, and executable file are all validated immediately before local auth mutation and immediately before termination; do not use `killall`, `open -b`, `open -n`, bundle-ID-only lookup, or process-name matching.
- Only the explicit confirmation action may call the host controller. Tests must use fakes and may not terminate or launch the real ChatGPT application.
- Distinguish `local switch complete`, `termination refused`, `termination timed out`, `host terminated`, `launch failed`, `launch attempted`, and `host auth reload not yet verified` in UI state and copy. No state may claim the host accepted the new auth without fresh usage proof.
- Keep account browsing/selection in expanded Usage. Compact/peek may show only the active account label.
- Use English for source, tests, comments, localization keys, commits, and PR text.

## Proof Stack

- **Proof target:** A saved account can be inspected, staged, and switched only after confirmation; local auth is restored after a storage failure; host relaunch only targets the exact verified ChatGPT app path.
- **Primary proof:** New deterministic unit tests in `Tests/CodexAccountTests.swift` and `Tests/ChatGPTHostControllerTests.swift`, then `./scripts/run-tests.sh`.
- **Backstop proof:** `./scripts/verify.sh`, fresh Pencil `snapshot_layout` on the saved account board, and a manual app walkthrough that stops before the destructive confirmation unless the user explicitly presses it.
- **Escalation trigger:** The host identity changes between validation points, the host app cannot be freshly validated, the stored `.pen` lacks board `nsus8`, a test needs the real host process, or a fresh relaunch cannot be proven to reread `~/.codex/auth.json`.
- **Evidence sink:** `planning/active/codex-auth-notch-switcher/{findings,progress}.md`, focused test output, full verification output, and the PR.
- **Reconcile rule:** Source, tests, Pencil, design spec, README, and localized copy must express the same confirmation-and-exact-path contract.
- **Unacceptable substitute:** A green compile, a broad process kill, a bundle ID match, or an editor-only Pencil state.

## Interfaces

```swift
protocol CodexAccountDataWriting {
    func write(_ data: Data, to url: URL) throws
}

enum ChatGPTHostApplyState: Equatable {
    case idle
    case validatingTarget
    case switchingLocally
    case localSwitchComplete
    case terminatingHost
    case hostTerminated
    case launchAttempted
    case authReloadUnverified
    case localSwitchFailed(String)
    case terminationFailed(String)
    case launchFailed(String)
    case localRestoreFailed(String)
}

protocol ChatGPTHostRuntime {
    func runningApplicationURLs() async -> [URL]
    func requestTermination(applicationAt appURL: URL) async -> Bool
    func waitForTermination(applicationAt appURL: URL, timeout: TimeInterval) async -> Bool
    func launch(applicationAt appURL: URL) async throws
}

@MainActor
final class CodexAccountApplyCoordinator: ObservableObject {
    @Published private(set) var state: ChatGPTHostApplyState = .idle
    @Published private(set) var switchedAccountKey: String?

    func apply(accountKey: String) async
    func retryLaunch() async
    func restorePreviousAccount() async
}
```

### Task 1: Make the local account switch transaction testable and recoverable

**Files:**
- Create: `Sources/Usage/CodexAccountDataWriter.swift`
- Modify: `Sources/Usage/CodexAccountStore.swift:4-240`
- Modify: `Tests/CodexAccountTests.swift:3-191`
- Modify: `scripts/run-tests.sh:13-25`

**Interfaces:** Consumes `CodexAccountPaths`, `CodexAccountRegistry`, and `CodexAuthParser`. Produces `CodexAccountDataWriting`, a writer-injected account store, and deterministic storage-failure proof.

- [ ] **Step 1: Write failing multi-account and failure-recovery tests.**

```swift
final class FailingWriter: CodexAccountDataWriting {
    var failingPath: URL?

    func write(_ data: Data, to url: URL) throws {
        if url == failingPath { throw TestError.forcedWriteFailure }
        try LiveCodexAccountDataWriter().write(data, to: url)
    }
}

expect(activeAuthAfterFailure == activeAuthBeforeFailure,
       "switch restores active auth when registry write fails")
expect(store.registry.activeAccountKey == previousKey,
       "switch restores in-memory active account when registry write fails")
expect(try Data(contentsOf: paths.registryPath) == registryBytesBeforeFailure,
       "switch preserves on-disk registry when registry write fails")
expect(try Data(contentsOf: paths.snapshotPath(for: personalKey)) == personalSnapshotBeforeFailure,
       "switch preserves existing account snapshots when registry write fails")
expect(Set(client.requests.map(\.accountID)) == Set(["acct-workspace-1", "acct-workspace-2"]),
       "refresh all isolates both account contexts")
```

- [ ] **Step 2: Run RED.**

Run: `./scripts/run-tests.sh`

Expected: compile failure because the writer injection and second-account test setup do not exist.

- [ ] **Step 3: Implement the writer seam and complete rollback coverage.**

```swift
final class CodexAccountStore: ObservableObject {
    private let writer: CodexAccountDataWriting

    init(
        paths: CodexAccountPaths = CodexAccountPaths(),
        writer: CodexAccountDataWriting = LiveCodexAccountDataWriter()
    ) throws {
        self.paths = paths
        self.writer = writer
        self.registry = try Self.loadRegistry(paths: paths)
    }
}

private func writePrivate(_ data: Data, to url: URL) throws {
    try writer.write(data, to: url)
}
```

Define the writer contract as fail-before-replace: a failed `write` must leave its destination byte-for-byte unchanged. Load the selected snapshot before changing the registry. Capture previous registry bytes, active-auth bytes, and relevant snapshot bytes before every fallible switch operation. Put unknown-auth import, active-auth replacement, registry assignment, and registry save inside one `do` block. In `catch`, restore old auth when present, reset in-memory registry, and attempt to restore the on-disk registry preimage. Retain the original throw. If restoration cannot persist, set `lastError` to an explicit durable-recovery-required message containing no secrets; do not claim local recovery succeeded.

- [ ] **Step 4: Run GREEN.**

Run: `./scripts/run-tests.sh`

Expected: all existing cases and the new multi-account/recovery cases pass without writing to real `~/.codex`.

- [ ] **Step 5: Commit the storage slice.**

```bash
git add Sources/Usage/CodexAccountDataWriter.swift Sources/Usage/CodexAccountStore.swift Tests/CodexAccountTests.swift scripts/run-tests.sh
git commit -m "feat: harden codex account switching"
```

### Task 2: Add exact-path ChatGPT host lifecycle and apply coordination

**Files:**
- Create: `Sources/Usage/ChatGPTHostController.swift`
- Create: `Sources/Usage/CodexAccountApplyCoordinator.swift`
- Create: `Sources/Usage/ChatGPTHostPolicy.swift`
- Create: `Tests/ChatGPTHostControllerTests.swift`
- Modify: `scripts/run-tests.sh:13-25`

**Interfaces:** Consumes `CodexAccountStore.switchToAccount(_:)`, `switchPrevious()`, AppKit lifecycle APIs behind `ChatGPTHostRuntime`, and a fresh `ChatGPTHostPolicy` validation result. Produces fake-driven host lifecycle proof and an apply coordinator.

Modify `scripts/run-tests.sh` to add `-framework AppKit` and compile only `CodexAccountDataWriter.swift`, `CodexAccountStore.swift`, `ChatGPTHostPolicy.swift`, `ChatGPTHostController.swift`, `CodexAccountApplyCoordinator.swift`, their Foundation/AppKit dependencies, and both non-UI test files. Do not add `CodexAccountRail.swift`, `UsageView.swift`, or any other SwiftUI view to this harness; `./build.sh` is their compile proof.

- [ ] **Step 1: Write failing host-policy and coordinator tests.**

```swift
final class FakeHostRuntime: ChatGPTHostRuntime {
    var running: [URL] = []
    var terminationRequests: [URL] = []
    var launched: [URL] = []
    var acceptsTermination = true
    var terminatesBeforeTimeout = true
    var launchError: Error?

    func runningApplicationURLs() async -> [URL] { running }
    func requestTermination(applicationAt appURL: URL) async -> Bool {
        terminationRequests.append(appURL)
        return acceptsTermination
    }
    func waitForTermination(applicationAt appURL: URL, timeout: TimeInterval) async -> Bool {
        terminatesBeforeTimeout
    }
    func launch(applicationAt appURL: URL) async throws {
        if let launchError { throw launchError }
        launched.append(appURL)
    }
}

expect(fake.terminationRequests == [expectedAppURL], "host terminates exact ChatGPT path")
expect(fake.launched == [expectedAppURL], "host reopens exact ChatGPT path")
expect(coordinator.state == .launchFailed("forced host failure"),
       "coordinator reports launch failure without another lifecycle call")
```

- [ ] **Step 2: Run RED.**

Run: `./scripts/run-tests.sh`

Expected: compilation failure because the host controller, fake-driven tests, and coordinator are absent.

- [ ] **Step 3: Implement path validation, lifecycle, and coordinator.**

```swift
struct ChatGPTHostTarget: Equatable {
    let applicationURL: URL
    let executableURL: URL

    static let defaultApplicationURL = URL(fileURLWithPath: "/Applications/ChatGPT.app")

    static func validate(applicationURL: URL) throws -> ChatGPTHostTarget {
        let appURL = applicationURL.resolvingSymlinksInPath().standardizedFileURL
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/ChatGPT")
        guard appURL.lastPathComponent == "ChatGPT.app",
              Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "ChatGPT",
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ChatGPTHostError.identityMismatch(appURL.path)
        }
        return ChatGPTHostTarget(applicationURL: appURL, executableURL: executableURL)
    }
}
```

`ChatGPTHostPolicy` receives a candidate URL and returns a validated immutable target. `CodexAccountApplyCoordinator.apply(accountKey:)` validates once before any auth change, calls `store.switchToAccount`, validates the target a second time, and aborts to `.terminationFailed` with manual-relaunch copy if the two targets differ. `SystemChatGPTHostRuntime` filters `NSWorkspace.shared.runningApplications` by exact resolved `bundleURL`, requests termination only on that result, bounds its wait, and launches the same target URL. If no exact running instance exists, it launches the target without termination.

The coordinator transitions from `.validatingTarget` to `.switchingLocally`, `.localSwitchComplete`, `.terminatingHost`, `.hostTerminated`, `.launchAttempted`, and finally `.authReloadUnverified`. It maps refusal and timeout to `.terminationFailed`, maps launch failure to `.launchFailed`, and maps local storage errors to `.localSwitchFailed`. `restorePreviousAccount()` never performs host I/O; when the host was terminated it says the user must manually reopen ChatGPT after restoration. `retryLaunch()` is available only after `.launchFailed` and launches the already revalidated target without a second termination request.

- [ ] **Step 4: Run GREEN.**

Run: `./scripts/run-tests.sh`

Expected: policy tests cover symlink resolution, wrong app name, wrong executable metadata, exact-path running-app filtering, refusal, timeout, launch failure, retry-without-repeat-termination, and no real application is terminated or launched.

- [ ] **Step 5: Commit the host/controller slice.**

```bash
git add Sources/Usage/ChatGPTHostPolicy.swift Sources/Usage/ChatGPTHostController.swift Sources/Usage/CodexAccountApplyCoordinator.swift Tests/ChatGPTHostControllerTests.swift scripts/run-tests.sh
git commit -m "feat: coordinate ChatGPT account apply"
```

### Task 3: Build the expanded-notch account rail and confirmation flow

**Files:**
- Create: `Sources/Views/CodexAccountRail.swift`
- Modify: `Sources/Views/UsageView.swift:13-86`
- Modify: `Sources/Views/PanelHeader.swift:10-77`
- Modify: `Sources/Views/Settings/CodexAccountsBlock.swift:46-116`
- Modify: `Resources/en.lproj/Localizable.strings`
- Modify: `Resources/zh-Hans.lproj/Localizable.strings`

**Interfaces:** Consumes `CodexAccountStore.registry`, the shared `CodexAccountApplyCoordinator`, `CodexUsageSnapshot`, `Typography`, and `IslandColor`. Produces a summary trigger, account rail, staged selection, explicit confirmation, and a separate Settings confirmation bridge backed by the same coordinator.

- [ ] **Step 1: Add the rail state model and compile surface.**

```swift
enum CodexAccountRailRoute: Equatable {
    case summary
    case accounts
    case selected(String)
}

struct CodexAccountRail: View {
    @ObservedObject var store: CodexAccountStore
    @ObservedObject var coordinator: CodexAccountApplyCoordinator
    @Binding var route: CodexAccountRailRoute
    @State private var confirmsSwitch = false
}
```

Render account rows from `store.registry.accounts`. Each row shows label, plan, active marker, last-known 5h/week snapshot, refresh freshness, and a stale/error caption. An active-row tap remains non-destructive. A non-active-row tap changes only `route` to `.selected(accountKey)`.

- [ ] **Step 2: Run RED.**

Run: `./build.sh`

Expected: compile failure until `CodexAccountRail.swift` and its non-UI dependencies exist. `run-tests.sh` remains limited to non-UI sources; it must not compile SwiftUI views.

- [ ] **Step 3: Wire the expanded Usage surface.**

```swift
struct UsageView: View {
    @State private var accountRoute: CodexAccountRailRoute = .summary
    @ObservedObject private var accountApply = CodexAccountApplyCoordinator.shared

    var body: some View {
        if accountRoute == .summary {
            usageSummary
        } else {
            CodexAccountRail(
                store: .shared,
                coordinator: accountApply,
                route: $accountRoute
            )
        }
    }
}
```

Extract the current `HStack` into `usageSummary`. Give the Codex `ChartsBlock` an optional `onOpenAccounts` closure and render one compact active-account button below the reset-credit summary. This preserves the chart layout until the user explicitly opens accounts. The selected route exposes only one primary command, `Switch & relaunch ChatGPT`; its explicit confirmation callback is the only caller of `Task { await coordinator.apply(accountKey: key) }`.

Show coordinator states for local switch, termination failure, launch failure, and reload-unverified launch. Both `.terminationFailed` and `.launchFailed` offer `Restore previous local account`; after restoration, copy explains whether ChatGPT is still running or must be manually reopened. Only `.launchFailed` also offers `Retry launch`, which revalidates the same target and never repeats termination. Add the active account label next to the Codex plan chip in `PanelHeader`; leave `NotchPeekPill` free of controls.

Use `CodexAccountApplyCoordinator.shared` as app-level ownership. `UsageView` owns only the expanded-panel route. Settings uses an `NSAlert` confirmation bridge that names the selected local label, calls the same coordinator only after its primary button is chosen, and maps `@Published` state to its existing footer message. Keep Settings import and manual refresh actions unchanged.

Remove `accountMeta(_:)` from Settings rows and replace it with a local-only status line built from plan, freshness, and usage availability. Change `defaultLabel(for:)` so an empty label produces `Codex Account` plus a non-identifying short account-key suffix, never an email. Add tests proving default labels and rendered Settings helper output do not contain email or raw account ID material.

- [ ] **Step 4: Add localized copy.**

Add matching English and Simplified Chinese values for: `Accounts`, `Switch & relaunch ChatGPT`, `ChatGPT will quit and reopen to apply this account.`, `Restore previous local account`, `Local switch complete`, `ChatGPT relaunch attempted`, `ChatGPT relaunch failed`, `No usage snapshot`, and `Last refreshed %@`.

- [ ] **Step 5: Run focused GREEN and compile proof.**

Run: `./build.sh`

Expected: both architectures compile and `build/CodexIsland.app` exists.

Run: `./scripts/run-tests.sh`

Expected: every non-UI test harness case passes.

- [ ] **Step 6: Commit the UI slice.**

```bash
git add Sources/Views/CodexAccountRail.swift Sources/Views/UsageView.swift Sources/Views/PanelHeader.swift Sources/Views/Settings/CodexAccountsBlock.swift Resources/en.lproj/Localizable.strings Resources/zh-Hans.lproj/Localizable.strings scripts/run-tests.sh
git commit -m "feat: add notch codex account rail"
```

### Task 4: Reconcile design, documentation, and release proof

**Files:**
- Modify: `docs/design/Codex_Island_Design.pen`
- Modify: `docs/design/CodexIsland_UI_Base.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `planning/active/codex-auth-notch-switcher/{task_plan,findings,progress}.md`

**Interfaces:** Consumes completed source, saved Pencil board, test output, and the host-path runtime observation. Produces accurate user documentation and PR-ready evidence.

- [ ] **Step 1: Reconcile saved Pencil with source.**

Run structural proof through Pencil MCP:

```text
snapshot_layout(
  filePath: "docs/design/Codex_Island_Design.pen",
  parentId: "nsus8",
  maxDepth: 6,
  problemsOnly: true
)
```

Expected: `No layout problems`. Inspect the saved Pencil Desktop canvas at a readable zoom and retain a current Desktop screenshot that visibly includes board `nsus8`. Export a non-blank PNG if the export pipeline has recovered. If PNG export remains blank, record that exact limitation and retain the Desktop visual proof.

- [ ] **Step 2: Reconcile documentation.**

Document local snapshots, expanded Usage account browsing, staged selection, confirmed ChatGPT relaunch, absolute-path targeting, local restoration, and the fact that host auth reload is unverified until runtime evidence proves it. Do not promise background or unattended restart behavior.

- [ ] **Step 3: Run full verification.**

Run: `./scripts/run-tests.sh`

Expected: exit 0 with every test passing.

Run: `./scripts/verify.sh`

Expected: exit 0; universal app builds and launches cleanly. This command does not prove an outer release signature.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 4: Keep the destructive runtime boundary user-controlled.**

Open the built CodexIsland app, enter the expanded Usage account rail, compare saved-account snapshots, select a non-active account, and dismiss confirmation. This proves browsing/cancellation do not touch active auth. Perform `Switch & relaunch ChatGPT` only when the user explicitly presses the UI control; record whether ChatGPT launches from the revalidated path and whether fresh usage proves auth reload. Missing reload proof blocks release closure.

- [ ] **Step 5: Commit reconciliation.**

```bash
git add docs/design/Codex_Island_Design.pen docs/design/CodexIsland_UI_Base.md README.md README.zh-CN.md planning/active/codex-auth-notch-switcher
git commit -m "docs: reconcile codex account switching"
```

## Plan Self-Review

- **Spec coverage:** Tasks 1-3 cover multi-account usage, staged selection, confirmation, local recovery, two-time host identity validation, exact-path lifecycle, Settings bridging, and privacy-safe display. Task 4 covers Pencil, documentation, full verification, and the user-controlled runtime boundary.
- **Placeholder scan:** Every required safety outcome has a named implementation or proof step; no generic error-handling instruction is used.
- **Type consistency:** `CodexAccountDataWriting` is injected into `CodexAccountStore`; `ChatGPTHostRuntime` is consumed by `ChatGPTHostPolicy` and the controller; `CodexAccountApplyCoordinator.shared` is the only bridge from confirmed UI action to store and host lifecycle.

## Execution Handoff

First commit the approved `.pen`, companion plan, and active trio from the root checkout as `docs: finalize codex account switcher plan`; its resulting SHA is the immutable worktree base. Create a native isolated worktree from that SHA, not from the dirty root checkout. Execute Tasks 1-3 in order, preserve the root's archive/harness/export changes, and use one fresh reviewer after each substantial implementation slice. Do not push, create a PR, merge, publish, or terminate ChatGPT without the corresponding user gate.

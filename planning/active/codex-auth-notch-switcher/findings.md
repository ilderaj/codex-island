# Findings: Codex Auth Notch Switcher

## Requirements
- Confirm whether the app already supports multiple Codex/ChatGPT accounts.
- Add an account-aware usage view and selection path that fits the notch product.
- Apply a selected account to the current merged ChatGPT/Codex host using a safe relaunch strategy informed by Copool, without assuming Copool's standalone-Codex target still applies.
- Produce and review a Pencil design, write and independently review an implementation plan, execute it in an isolated worktree, then verify and route the PR/release closure.

## Findings Record: 2026-07-11 21:37:03 UTC+8
- Current checkout is `dev` at `5598581`; planning archive moves and `.harness` runtime state are already dirty and are excluded from product implementation scope.
- `planning/active/` was empty before this task; this directory is the sole durable state for the new task.
- Initial source scan shows `CodexAccountStore`, `CodexAuthModels`, `CodexAuthParser`, `CodexAccountsBlock`, and `CodexAccountTests` already exist. The specific behavior and gaps require source-level confirmation.
- `docs/design/Codex_Island_Design.pen` is the established Pencil source of truth for SwiftUI-changing work in this repository.

## Findings Record: 2026-07-11 21:37:03 UTC+8
- Pencil CLI version is `0.2.8`, matching the latest published package version, but its CLI authentication is absent. The active Pencil MCP editor is nevertheless bound to the repository's existing `.pen` file and exposes the three expected top-level boards: `Component Shelf` (`bi8Au`), `Island States` (`utevI`), and `Settings Window` (`X2JGAu`).
- Therefore this task can use the active Pencil editor for a structured design update and validation without attempting a CLI login or using any external credential.

## Findings Record: 2026-07-11 21:41:02 UTC+8
- Visible worker `019f5167-0154-7021-a2b3-1e0816118f96` verified its initial trio binding and completed a read-only account audit. The app already persists multiple records and snapshots under `~/.codex/accounts/<key>.auth.json` while keeping the active auth at `~/.codex/auth.json` (`Sources/Usage/CodexAuthModels.swift:82`, `:125`). `CodexAccountStore.importCurrentAuth()` parses, atomically saves a snapshot, upserts the registry, and persists it (`Sources/Usage/CodexAccountStore.swift:23`). Existing tests prove same-email/different-account-ID separation (`Tests/CodexAccountTests.swift:68`).
- Per-account usage is implemented in source: `refreshAllUsage` iterates saved contexts and persists snapshots (`Sources/Usage/CodexAccountStore.swift:108`, `:123`) while `UsageFetcher` passes bearer token and `ChatGPT-Account-Id` (`Sources/Usage/UsageFetcher.swift:16`). Settings renders each account's 5h/week snapshot (`Sources/Views/Settings/CodexAccountsBlock.swift:238`). The current tests only cover one saved snapshot, not multi-account isolation, partial failure, or concurrent refresh.
- Local account switching is implemented: Settings invokes `switchToAccount` then refreshes app usage (`Sources/Views/Settings/CodexAccountsBlock.swift:46`), store logic snapshots registry/auth and atomically replaces the active file (`Sources/Usage/CodexAccountStore.swift:56`), and `Switch Previous` exists (`Sources/Views/Settings/CodexAccountsBlock.swift:93`). Recovery is best-effort and lacks fault-injection evidence for cross-file consistency.
- Product gap: no account picker, label, or non-active-account usage exists in compact/peek/expanded notch surfaces; they consume only active `UsageStore.codex` (`Sources/Views/IslandRootView.swift:95`, `Sources/Views/UsageView.swift:13`, `Sources/Views/PanelHeader.swift:10`). The account controls are Settings-only (`Sources/Views/SettingsView.swift:492`).
- Product gap: switching has no host apply/relaunch implementation. It only shows a restart advisory (`Sources/Views/Settings/CodexAccountsBlock.swift:51`); the only source restart action restarts CodexIsland for language changes (`Sources/Views/SettingsView.swift:481`).
- Fresh baseline proof: `./scripts/run-tests.sh` exited 0 with all existing tests passing, including parser, import, local switch, active/previous keys, per-snapshot request context, and usage-writeback tests.

## Findings Record: 2026-07-11 21:42:06 UTC+8
- Visible worker `019f5167-03fa-7591-8a90-85fa9e898681` verified its initial trio binding and completed a read-only host audit. The actual running host is `/Applications/ChatGPT.app`, bundle ID `com.openai.codex`, executable `/Applications/ChatGPT.app/Contents/MacOS/ChatGPT`, version `26.707.41301`; it has a `Resources/codex` child process.
- `/Applications/Codex.app` has the same bundle ID and an older version (`26.707.31428`); it has no primary app process, only old launchd-adopted helper processes. Therefore bundle ID, display name, `open -b`, `killall`, PID/name matching, and `open -n` are all unsafe/unreliable apply strategies.
- The repository only advises restart after local switch. Its only `/usr/bin/open` pattern relaunches CodexIsland itself through `Bundle.main.bundleURL` (`Sources/Model/AppLanguageStore.swift:84`). No host-relaunch implementation exists.
- No local Copool checkout or reference was found. Copool's old standalone-Codex strategy cannot be treated as source truth for this merged host.
- Safe ranked options: (1) default to local switch plus precise manual instruction to quit/reopen `/Applications/ChatGPT.app`; (2) only if the product requires one-click apply, perform a fresh absolute-path match, graceful terminate, and absolute-path reopen after an explicit confirmation; (3) never use broad process/bundle targeting.
- Remaining proof gap: current local inspection cannot prove that a relaunched ChatGPT host rereads `~/.codex/auth.json` or lacks a separate credentials cache. This must remain a runtime verification gate, not an assumption.

## Technical Decisions
| Decision | Rationale |
|---|---|
| Separate read-only discovery from all credential/process actions | Authentication and restart behavior carry data-loss and interruption risk. |
| Do not treat `killall`, old Codex bundle IDs, or build success as restart proof | The user reports a merged ChatGPT/Codex host, so old standalone assumptions are unsafe. |
| Put account selection in expanded notch content and retain Settings for management | The existing design base defines compact/peek as passive glance states; notch control density must remain low. |

## Issues Encountered
| Issue | Resolution |
|---|---|
| Existing planning archival changes are uncommitted | Preserve them untouched; implementation will use a separate worktree after plan approval. |
| Restart interaction contract is unselected after three requests | Keep the task blocked; do not infer whether clicking an account authorizes ChatGPT termination. |

## Findings Record: 2026-07-11 21:43:56 UTC+8
- User selected restart Contract A: account selection must lead to an explicit “Switch & relaunch ChatGPT” confirmation. Only after that confirmation may the app mutate local active auth and execute a precise ChatGPT host relaunch attempt.
- The recommended full product design (account rail in expanded notch, passive compact/peek indicator, and explicit confirmation sheet) has not received approval after three requests. No Pencil or product-source modification is authorized yet.

## Findings Record: 2026-07-11 22:05:05 UTC+8
- User approved the recommended account-rail product design. Pencil work is authorized for the three planned states only: account rail, selected account, and “Switch & relaunch ChatGPT” confirmation.

## Findings Record: 2026-07-11 22:07:58 UTC+8
- First Pencil implementation attempt created `Codex Account Switching` (`r0o77`) with flex-driven nested layout. `snapshot_layout(..., problemsOnly: true)` reported clipping throughout the new board, and `get_screenshot(r0o77)` rendered blank. This is rejected design proof, not an acceptable visual artifact.
- Recovery decision: replace only the new board with a fixed-dimension, explicitly positioned canvas and re-run both structural and screenshot verification. Existing `.pen` boards remain untouched.

## Findings Record: 2026-07-11 22:10:44 UTC+8
- The recovered Pencil board has the three approved account states and `snapshot_layout(..., problemsOnly: true)` returns `No layout problems`.
- Both `get_screenshot` and `export_nodes` produce fully white output, so visual rendering proof failed. The exported file is `docs/design/exports/nsus8.png` and is intentionally not treated as acceptance evidence.
- Source-truth guard: the disk file `docs/design/Codex_Island_Design.pen` retains the exact `HEAD` hash `e20e1c9ee71ec16f9a60cfcdc30764c5131a218d4ffd64013a83ebce709184d5` and `git diff` is empty, although the active Pencil MCP canvas reports the new `Codex Account Switching` board. The board must be saved/adopted into the tracked file before implementation can claim Pencil alignment.

## Destructive Operations Log
| Command | Target | Checkpoint | Rollback |
|---|---|---|---|
| None | N/A | N/A | N/A |

## Resources
- `Sources/Usage/CodexAccountStore.swift`
- `Sources/Usage/CodexAuthModels.swift`
- `Sources/Usage/CodexAuthParser.swift`
- `Sources/Views/Settings/CodexAccountsBlock.swift`
- `Tests/CodexAccountTests.swift`
- `docs/design/Codex_Island_Design.pen`

## Visual/Browser Findings
- No visual inspection completed yet.

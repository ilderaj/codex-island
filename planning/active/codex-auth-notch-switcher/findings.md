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

## Findings Record: 2026-07-11 22:20:06 UTC+8
- Pencil Desktop displayed `Codex_Island_Design.pen — Edited`; a standard save cleared the edited marker. The disk hash is now `47873ae9a3cb76f53bb74e296bbc9a3866cff8666c9b4b1d64f303fc1d7ef866`, differs from `HEAD`, and Git reports 957 changed `.pen` lines.
- Pencil Desktop visual inspection shows the new `Codex Account Switching` board beside the base boards; it contains the account rail, staged account, and confirmation states. Fresh MCP structural proof returns `No layout problems`.
- Pencil MCP screenshot/export remains all-white, but the Desktop canvas is a usable visual backstop. The saved source plus structural proof is sufficient to proceed; PNG export remains a release reconciliation item.
- Companion implementation plan exists at `docs/superpowers/plans/2026-07-11-codex-auth-notch-switcher.md`. Placeholder scan and `git diff --check` passed before independent review.

## Findings Record: 2026-07-11 22:26:38 UTC+8
- Read-only reviewer `019f518d-7624-7593-95d9-f6fa7491e21a` verified all planning/plan hashes before review. It found critical gaps in time-of-use host identity validation and in the over-broad `.applied` lifecycle state, plus important test-harness, rollback, Settings-bridge, privacy, Pencil-reproducibility, and verify-script gaps.
- Chief integrated all actionable findings: symlink-resolved path plus app/executable metadata validation before local switch and termination; granular lifecycle outcomes with user-controlled launch retry/restoration; injected runtime policy seams; preimage/postimage recovery tests; AppKit-only non-UI test harness scope; shared coordinator plus Settings alert bridge; non-identity labels/row display; board `nsus8`; immutable worktree base commit; and corrected `verify.sh` claim.
- Plan placeholder scan and whitespace check remain clean after revision. A second read-only review is required before execution because these are material safety changes.

## Findings Record: 2026-07-11 22:26:38 UTC+8
- Final read-only reviewer `019f5193-6af4-76d3-99ed-dcc7441d7c94` verified revised hashes and found no critical defect. It identified two important omissions: `terminationFailed` also needs a user-controlled local restoration path, and Task 2 must commit `ChatGPTHostPolicy.swift`.
- Chief reconciled both omissions. The final plan preserves the release-blocking runtime proof: launch attempt never claims auth reload, and user confirmation remains the only path to host interruption.

## Findings Record: 2026-07-11 22:32:31 UTC+8
- Visible implementation worker `019f5196-c321-7c62-8d49-7f25f82cb02a` stopped at preflight before tests or edits because its native worktree contained a changed `.harness/runtime-hooks/codex.jsonl`.
- This file is a harness runtime hook artifact and lies outside Task 1 allowed source paths. Chief authorized a narrowly documented exception only for that exact path; all product/test/planning/design/script dirt remains a hard stop. The stale worker will not be resumed; Task 1 will use a replacement visible worker.

## Findings Record: 2026-07-11 22:42:00 UTC+8
- Reused visible worker `019f5196-c321-7c62-8d49-7f25f82cb02a` under the exact-path harness exception. It completed companion-plan Task 1 in an isolated worktree and amended its final slice to `6bb3e99` (`feat: harden codex account switching`). Chief independently verified the authorized four-file scope, `git diff --check`, `git show --check`, and a fresh `./scripts/run-tests.sh` run with all tests passing.
- The completed slice adds an injectable fail-before-replace account-data writer, per-account refresh-context coverage, and byte-level rollback evidence for active auth, disk/memory registry, registered snapshots, and the newly created unknown-current-auth snapshot.
- A narrow read-only review found two P2 gaps before integration: registry write failures were falsely reported as durable recovery, and the unknown-current-auth rollback mutation was untested. The worker added RED/GREEN coverage and a preimage-aware restore check; the final tests prove both failure paths preserve the original state and use the non-durable error state when the writer contract preserves destination bytes.
- Chief cherry-picked the reviewed slice into `dev` as `cb04ecc`. No real `~/.codex` file, host process, UI, external service, push, PR, merge, or release action was performed.

## Findings Record: 2026-07-11 22:57:00 UTC+8
- Visible worktree worker `019f51a5-1620-75a2-840c-f43029b36cfe` completed companion-plan Task 2 at `1e47096` (`feat: coordinate ChatGPT account apply`). Chief independently confirmed the five-file scope, `git diff --check`, `git show --check`, and a fresh full `./scripts/run-tests.sh` run. The reviewed slice was cherry-picked into `dev` as `0780104`.
- `ChatGPTHostTarget` resolves symlinks and requires `ChatGPT.app`, `CFBundleExecutable == ChatGPT`, and an executable `Contents/MacOS/ChatGPT`. The AppKit runtime filters running applications by exact resolved bundle URL and uses only that concrete target for termination, bounded wait, and launch; it contains no bundle-ID, process-name, `killall`, `open -b`, or `open -n` path.
- `CodexAccountApplyCoordinator` validates the target before local switching and again before termination. Refusal, timeout, target drift, and launch failure end in non-success states; retry revalidates/launches without another termination; local restoration performs no host I/O; the only post-launch state is `authReloadUnverified`.
- The host proof is intentionally fake-driven and does not assert that a real relaunched ChatGPT process has reloaded `~/.codex/auth.json`. That runtime question remains a release-blocking manual verification gate.
- A timeboxed narrow read-only reviewer did not return before its close request stalled. Its absent output was not used for acceptance; Chief's independent code/test/diff checks were the integration gate. No process, auth, or external operation was performed.

## Findings Record: 2026-07-11 23:00:00 UTC+8
- Task 3's plan prose requires `CodexAccountApplyCoordinator.shared` and a non-identifying `CodexAccountStore.defaultLabel(for:)` with tests, but its initial files table omits the coordinator/store/test files. Chief treats these as mandatory interface/privacy-contract completion and adds only those exact files to the Task 3 worker's declared write set.

## Findings Record: 2026-07-11 23:24:00 UTC+8
- Visible worker `019f51a5-1620-75a2-840c-f43029b36cfe` completed Task 3 in two reviewed commits: rail implementation `5e6375b`, then correction `179d2c3`. Chief integrated them as `3e9142c` and `cda2d15` after independent scope checks, full non-UI harness runs, build output checks, and source inspection.
- The expanded Usage route now stages a saved account and calls `apply(accountKey:)` only from affirmative confirmation callbacks in the rail and Settings bridge. Compact/peek remain free of account controls. The coordinator is shared app-wide; Settings preserves import and refresh operations.
- The first narrow Task 3 review arrived after the initial integration and found a P1 raw-ID label bypass plus two P2 truthfulness/recovery issues. The follow-up rejects labels containing any raw identity substring, adds its regression test, suppresses pre-switch completion copy, and exposes local restore only after that apply invocation has actually switched local auth.
- No real authentication file or ChatGPT process was operated. Fresh host auth reload remains unverified and continues to block release closure until a user-controlled runtime confirmation supplies evidence.

## Findings Record: 2026-07-11 23:32:00 UTC+8
- Task 4 reconciliation confirms the saved Pencil document has four boards and retains `Codex Account Switching` (`nsus8`). Fresh `snapshot_layout` with `problemsOnly: true` reports `No layout problems`.
- Chief's first clean-root build gate exposed two `UsageView` compiler defects that had been masked by a stale `build/CodexIsland.app`: the new optional account callback was not supplied to both Claude calls, and the multi-statement opaque `usageSummary` needed an explicit return. Both were corrected directly in `Sources/Views/UsageView.swift`.
- Fresh verification after `rm -rf build` passed: `./build.sh` exits 0 and creates a new universal app, `./scripts/run-tests.sh` passes all account/host regression cases, and `./scripts/verify.sh` rebuilds then smoke-launches CodexIsland cleanly. `git diff --check` passes.
- Documentation now describes saved snapshots, expanded Usage browsing/staging, explicit confirmed relaunch, local restoration, exact target validation, and the unverified-auth-reload limitation. No claim is made that a real ChatGPT relaunch has adopted the selected auth.
- Release remains blocked only by the user-controlled runtime proof and the explicit PR/push/merge/release gates. The runtime proof must stop before the confirmation unless the user personally presses it.

## Findings Record: 2026-07-11 23:36:00 UTC+8
- Read-only delivery audit: local `dev` is 14 commits ahead of its tracking branch `origin/dev`; GitHub authentication for `ilderaj` has repository write scope; no open PR has head branch `dev`.
- `ilderaj/codex-island` is the writable fork and has default branch `main`; `ericjypark/codex-island` is the read-only upstream. The recommended PR is therefore fork-local `dev -> main` after the user grants the external-write gate.

## Findings Record: 2026-07-11 23:39:22 UTC+8
- Chief's completion audit found that the rail's pre-switch restore suppression was implemented but not directly exercised by the coordinator harness. Added a focused regression case using an empty sequenced target policy.
- The case proves initial target validation failure keeps the original active account, performs no termination or launch request, and leaves `didSwitchLocallyForCurrentApply` false. The rail's restore button is guarded by that same state in `Sources/Views/CodexAccountRail.swift`.
- Fresh `./scripts/run-tests.sh` exits 0 with all existing and new cases passing. No real auth file, ChatGPT process, network endpoint, push, PR, or release action was performed.
- Committed the focused test and this audit receipt separately: `cf1b744` contains the test plus first receipt; unrelated pre-existing `.harness`, planning archive, and design export changes remain unstaged and untouched.

## Findings Record: 2026-07-12 16:04:54 UTC+8
- User-provided screenshots reproduced a first expanded-usage page occlusion with both one and two providers. The fixed `PanelHeader` and `PanelFooter` frame the middle `PagedContent` area, but page-zero `UsageView` alone had a historical `compactPageYOffset = -28` offset and was therefore drawn underneath the header and footer.
- Visible worker `019f554e-5d76-7dd1-bef1-92c340fa111c` returned bounded commit `619da65` (`fix(ui): keep usage page within panel chrome`), changing only `Sources/Views/PagedContent.swift` to remove that offset from `UsageView`. Cost retains its existing offset; overview is unchanged.
- Chief independently verified the exact one-line diff, `git show --check`, full `./scripts/run-tests.sh`, and a fresh `rm -rf build && ./build.sh` universal build. There is no repository SwiftUI screenshot harness, so a live single- and dual-provider expanded-panel inspection remains the visual backstop; no auth, host, or remote action occurred.

## Findings Record: 2026-07-12 16:08:48 UTC+8
- 用户已在真实运行的 App 中确认单 provider 与双 provider 展开页的首屏视觉效果；该 layout regression 的视觉 backstop 已通过。
- 此确认仅覆盖 Usage 展开布局，不代表用户执行或确认了 ChatGPT 的账号切换/重启路径；该独立 runtime gate 保持不变。

## Findings Record: 2026-07-12 16:08:48 UTC+8
- 按用户明确授权，Chief 已将 `dev` 从 `5598581` 推送至 `9ebbbbd`，并创建 fork-local [PR #4](https://github.com/ilderaj/codex-island/pull/4)（`ilderaj/codex-island:dev -> main`）。PR 描述包含完整本地验证、单双 provider 视觉确认，以及未执行真实 ChatGPT 重启 proof 的明确 caveat。
- 未执行 merge、release、publish、真实 auth 写入或 ChatGPT 进程操作。

## Findings Record: 2026-07-12 16:16:10 UTC+8
- PR #4 的独立只读 review 复核了 `origin/main...dev`、host fake harness 与当前 rail 状态，确认两项可操作问题：P1 为成功应用后 Rail 没有为新选择的账户重新提供显式切换入口；P2 为已终止 host 的 launch-failure 路径在本地恢复后没有消费 `restorationRequiresManualHostLaunch`，未提示用户手动重新打开 ChatGPT。
- 处置：进入隔离的 TDD follow-up，只限 coordinator/rail/host-harness/必要的本地化字符串。真实 ChatGPT auth reload 仍是明确保留的用户控制 runtime gate，不是这轮 review defect。

## Findings Record: 2026-07-12 16:25:39 UTC+8
- 隔离 worker 的 RED/GREEN follow-up 已由 Chief 集成为 `76ec9c0`。新状态契约让 `authReloadUnverified` 明确允许下一次同样经过确认的 apply；host 已终止且 launch-failure 后的本地恢复会显示“ChatGPT 已关闭。请手动重新打开它。”，且恢复本身没有 host I/O。
- Chief 独立运行完整 `./scripts/run-tests.sh` 与 fresh `rm -rf build && ./build.sh`，均通过。第二个只读 reviewer 对 `ebf7d92..76ec9c0` 复查后无可操作 P0/P1/P2；显式确认、切换前后精确目标校验与无 host-I/O restore 均未被削弱。
- 剩余 proof gap：无 SwiftUI 自动点击/截图 harness，且真实 ChatGPT 是否读取新 auth 仍未执行。前者有源代码、状态 harness 与用户已完成的 layout 视觉确认作为 backstop；后者仍是 release-blocking 的用户控制 runtime gate。

## Findings Record: 2026-07-12 16:25:39 UTC+8
- 本机只读检查确认 `/opt/homebrew/bin/codex login --help` 提供 `status` 子命令。Runtime proof 因此分为两个不重叠的 readback：用户在正常 ChatGPT profile 界面确认重开后的账户，以及新的 `codex login status` invocation 确认 CLI 读取切换后的本地 auth。
- Codex Island 不终止、枚举或猜测任意 CLI 进程；这是刻意的安全边界。完整用户控制的验收/回退步骤已写入 `task_plan.md`，在成功 evidence 出现前不执行 merge/release。

## Findings Record: 2026-07-12 16:28:42 UTC+8
- 同一 user-controlled runtime-proof gate 已连续三次阻止后续 release work。任务因此被如实置为 blocked，而非把 launch attempt、构建成功或 PR `CLEAN` 状态替代为真实 auth reload evidence。
- 恢复输入：用户报告 ChatGPT profile 与新的 `codex login status` 是否反映选定账户，或明确说明 runtime proof 未通过。随后 Chief 将记录结果、处理必要恢复，并请求独立的 merge/release 授权。

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

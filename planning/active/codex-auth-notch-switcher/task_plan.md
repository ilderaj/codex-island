# Task Plan: Codex Auth Notch Switcher

## Goal
Deliver a verified macOS Codex Island flow that can retain multiple local Codex/ChatGPT account snapshots, show per-account usage in the notch UI, switch the active account safely, and apply the selected authentication to the current ChatGPT/Codex host with an explicit, reversible relaunch strategy.

## Current State
Status: active
Archive Eligible: no
Close Reason:
Reconcile: final independent review reconciled; implementation plan frozen

## Routing Decision
- Selected Route: deep
- Route Reason: The request crosses local credential ownership, undocumented usage APIs, a Pencil-governed SwiftUI surface, and relaunch semantics for a host whose bundle arrangement has changed.
- Promotion Trigger: Already deep; a reviewed implementation plan and independent plan review are mandatory before source changes.
- Route Evidence Surface: This trio, `docs/design/Codex_Island_Design.pen`, source/tests, local host-bundle inspection, and GitHub PR state.

## Current Phase
Phase 5: Verification and Delivery

## Phases

### Phase 1: Discovery and Source Truth
- [x] Confirm the existing account registry, snapshot, active-auth replacement, and per-account usage behaviors from source and tests.
- [x] Inspect the installed ChatGPT/Codex host and obtain a read-only Copool reference for relaunch semantics.
- [x] Record evidence, limitations, and security boundaries in `findings.md`.
- **Status:** complete

### Phase 2: Product and UI Design
- [x] Present bounded implementation approaches and obtain the required design approval.
- [x] Persist the approved account-usage/switching board into `docs/design/Codex_Island_Design.pen`.
- [x] Re-run structural and desktop-canvas visual proof.
- [x] Review Pencil structure and record the design contract.
- **Status:** complete

### Phase 3: Reviewed Implementation Plan
- [x] Create `docs/superpowers/plans/2026-07-11-codex-auth-notch-switcher.md`.
- [x] Define exact interfaces, test-first steps, worktree strategy, and relaunch rollback behavior.
- [x] Obtain an independent read-only plan review and reconcile findings.
- [x] Obtain final re-review after the material safety revision.
- **Status:** complete

### Phase 4: Isolated Implementation
- [ ] Create a dedicated implementation worktree and branch after plan approval.
- [x] Implement Task 1: local transaction recovery and multi-account test coverage.
- [x] Implement Task 2: exact-path host lifecycle and coordinator.
- [x] Implement Task 3: expanded-notch account rail and confirmation flow.
- [x] Keep code, design, and tests synchronized.
- **Status:** complete

### Phase 5: Verification and Delivery
- [ ] Run targeted tests, full repository tests, build/launch verification, and manual host-path proof appropriate to the selected strategy.
- [ ] Commit, push, open a PR, complete review/reconciliation, and request the explicit merge/release gate.
- [ ] Perform post-merge adoption checks before closure.
- **Status:** in_progress

### Delivery Readiness
- Pre-audit delivery head: `dev` at `71bca9d`, ahead of `origin/dev` by 15 commits.
- Fork target: `ilderaj/codex-island`; default branch `main`; current `dev` tracks `origin/dev`.
- Recommended PR route after approval: push `dev` to `origin/dev`, then open `ilderaj/codex-island:dev` into `ilderaj/codex-island:main`.
- Upstream `ericjypark/codex-island` is read-only for the current GitHub identity and is not a write target.
- Remaining gates: user-controlled confirmed ChatGPT relaunch proof; explicit approval for push/PR; then a separate merge/release decision.

### Latest Verification Receipt
- A final coordinator regression test proves a failed initial target validation keeps the active local account unchanged, performs no host I/O, and leaves `didSwitchLocallyForCurrentApply` false so the rail cannot expose a local restore path.
- `./scripts/run-tests.sh` passed after this addition. The earlier fresh build and `./scripts/verify.sh` proof remains current because this receipt changes only the test harness.

## Verification Contract

### Mode: Implementation completion
- Proof Target: A user can distinguish account usage, activate a chosen local account snapshot, and the documented host-relaunch behavior applies that selection without corrupting the prior active auth file.
- Primary Proof: New focused Swift tests covering registry/switch/relaunch decision behavior, followed by `./scripts/run-tests.sh` and `./scripts/verify.sh` from the isolated worktree.
- Backstop Proof: Fresh inspection of the installed host bundle/process state plus a manual switch-and-relaunch walkthrough using non-secret metadata only.
- Escalation Trigger: Host bundle identity, launch path, or CLI persistence cannot be proven from local inspection; then implementation stops short of forcing process termination and records the ambiguity.
- Evidence Sink: `progress.md`, `findings.md`, test output, and the PR.
- Reconcile Rule: Design, Swift behavior, tests, and README must agree on one restart contract; mismatches block PR readiness.
- Unacceptable Substitute: A successful build alone, an arbitrary `killall`, or a claim based solely on the prior standalone Codex app behavior.

## Execution Contract

### Unit: discovery-auth-usage
- Kind: research
- Status: complete
- Scope:
  - Do: Read source/tests and report what existing multi-account functionality is proven.
  - Not do: Modify source, auth files, keychain, or network account state.
- Owner Mode: visible worker
- Proof Target: Exact source and test references for import, list, switch, and per-account usage behaviors.
- Evidence Sink: `findings.md` and `progress.md` after Chief review.
- Stop Condition: Return a bounded evidence report with gaps and no edits.

### Unit: discovery-host-relaunch
- Kind: research
- Status: complete
- Scope:
  - Do: Inspect installed app/bundle/process facts and the available Copool reference to identify safe relaunch options.
  - Not do: Quit, relaunch, kill, change auth, or modify source.
- Owner Mode: visible worker
- Proof Target: Bundle/process evidence plus a recommendation ranked by safety and applicability to the merged host.
- Evidence Sink: `findings.md` and `progress.md` after Chief review.
- Stop Condition: Return a bounded evidence report with limitations and no edits.

### Unit: implementation-storage-transaction
- Kind: implementation
- Status: complete
- Scope:
  - Do: Execute companion-plan Task 1 only, including its RED/GREEN tests and one commit.
  - Not do: Host lifecycle, SwiftUI account rail, Pencil, Settings workflow, external auth, process operations, push, PR, merge, or release.
- Owner Mode: visible worker
- Allowed Ops:
  - Files: `Sources/Usage/CodexAccountDataWriter.swift`, `Sources/Usage/CodexAccountStore.swift`, `Tests/CodexAccountTests.swift`, `scripts/run-tests.sh`
  - Commands: focused test harness, diff checks, and local commit
  - External effects: none
- Dependencies: immutable base `4b2794c` and companion-plan Task 1
- Verification Plan: RED compile proof, focused GREEN `./scripts/run-tests.sh`, `git diff --check`, review follow-up coverage, and Chief's independent harness run
- Return Artifacts: worker commit `6bb3e99`, integrated commit `cb04ecc`, changed-file list, RED/GREEN evidence, and residual risks
- Integration Target: reconciled by Chief into `dev`; receipt recorded in `findings.md` and `progress.md`
- Exit Criteria: complete; Task 1 proof passed without touching real `~/.codex` or host processes

### Unit: implementation-host-lifecycle
- Kind: implementation
- Status: complete
- Scope:
  - Do: Execute companion-plan Task 2 only: exact-path host policy/controller, apply coordinator, fake-driven tests, and bare-harness wiring.
  - Not do: SwiftUI, Settings integration, Pencil, localization, real auth mutation, real host/process operation, push, PR, merge, release, or archive.
- Owner Mode: visible worktree worker `019f51a5-1620-75a2-840c-f43029b36cfe`
- Allowed Ops:
  - Files: `Sources/Usage/ChatGPTHostPolicy.swift`, `Sources/Usage/ChatGPTHostController.swift`, `Sources/Usage/CodexAccountApplyCoordinator.swift`, `Tests/ChatGPTHostControllerTests.swift`, and `scripts/run-tests.sh`
  - Commands: focused non-UI harness, diff checks, and a local commit
  - External effects: none; all host lifecycle behavior is fake-driven
- Dependencies: `d60c76b` and companion-plan Task 2
- Verification Plan: RED proof, focused GREEN `./scripts/run-tests.sh`, exact-target fake cases, `git diff --check`, `git show --check`, and Chief's independent harness run
- Return Artifacts: worker commit `1e47096`, integrated commit `0780104`, changed-file list, baseline/RED/GREEN evidence, worktree status, and residual risks
- Integration Target: reconciled by Chief into `dev`; receipt recorded in `findings.md` and `progress.md`
- Exit Criteria: complete; coordinator and controller are proven fake-only, and no state claims fresh host auth reload

### Unit: implementation-account-rail
- Kind: implementation
- Status: complete
- Scope:
  - Do: Execute companion-plan Task 3 only: expanded Usage rail, staged selection, explicit confirmation, Settings bridge, privacy-safe account labels, localized copy, build proof, and non-UI regression coverage.
  - Not do: Real host/auth action, Pencil redesign, README/documentation reconciliation, push, PR, merge, release, or archive.
- Owner Mode: reused visible worktree worker `019f51a5-1620-75a2-840c-f43029b36cfe`
- Allowed Ops:
  - Files: `Sources/Views/CodexAccountRail.swift`, `Sources/Views/UsageView.swift`, `Sources/Views/PanelHeader.swift`, `Sources/Views/Settings/CodexAccountsBlock.swift`, `Resources/en.lproj/Localizable.strings`, `Resources/zh-Hans.lproj/Localizable.strings`, `Sources/Usage/CodexAccountApplyCoordinator.swift`, `Sources/Usage/CodexAccountStore.swift`, `Tests/CodexAccountTests.swift`, and `scripts/run-tests.sh` only when strictly needed.
  - Commands: `./build.sh`, non-UI test harness, diff checks, and a local commit.
  - External effects: none; confirmation action must not be activated during proof.
- Dependencies: `4e23d59` and companion-plan Task 3
- Reconcile Note: the companion plan's Task 3 prose requires `CodexAccountApplyCoordinator.shared` and privacy-safe `defaultLabel(for:)` coverage even though its initial file table omits their implementation/test files. These two files are explicitly included here as required plan-contract completion, not a scope expansion.
- Verification Plan: build RED/GREEN, non-UI harness GREEN, source inspection that only affirmative confirmation callbacks can call `apply(accountKey:)`, `git diff --check`, Chief review, and review-follow-up regression coverage.
- Return Artifacts: worker commits `5e6375b` and `179d2c3`; integrated commits `3e9142c` and `cda2d15`; changed-file list, RED/GREEN evidence, worktree status, and residual risks.
- Integration Target: reconciled by Chief into `dev`; receipt recorded in `findings.md` and `progress.md`.
- Exit Criteria: complete; browsing/staging/cancel are local UI state only, affirmative confirmation is the sole apply path, UI labels expose no email or raw account ID, and a pre-switch validation failure cannot offer local restore.

### Preflight Exception: native worktree runtime noise
- Allowed unrelated dirty path: `.harness/runtime-hooks/codex.jsonl` only, when it is generated during worker startup.
- Required observation: `git status --short` contains no source, test, planning, design, or script change outside this one runtime path.
- Effect: a replacement worker may proceed after recording this exception; any other dirty path remains a binding mismatch and immediate stop condition.

## Risk Assessment

| Risk | Trigger | Impact | Mitigation / rollback |
|---|---|---|---|
| Credential loss | Snapshot replacement is interrupted | Current CLI/host auth may be unusable | Atomic replacement with preserved prior auth and explicit restore path; tests before invoking runtime behavior |
| Wrong host target | ChatGPT/Codex bundle/process identity is guessed | User's active app could be terminated or left stale | Read local bundle/process truth; use no terminate action until exact target is proven |
| Usage privacy | Account labels or tokens leak into UI/logs | Sensitive account data exposure | Persist only existing non-secret metadata; redact all reports and avoid token logging |
| Design drift | Pencil frame and SwiftUI diverge | Notch interaction becomes unclear or clipped | Make `.pen` review a pre-implementation gate and keep an alignment map in the plan |

## Key Questions
1. Which portions of account import, switching, and usage are already present and tested today?
2. Which installed ChatGPT/Codex process should be relaunched, if any, after `~/.codex/auth.json` changes?
3. Can the notch remain readable while selecting among several accounts, or should selection live in the expanded panel with a compact active-account indicator?

## Decisions Made
| Decision | Rationale |
|---|---|
| Treat old implementation as evidence, not completion | The requested host architecture changed after the previous plan and must be revalidated live. |
| Keep all auth mutations local and reversible | Account switching controls credentials and must preserve the previously active file. |
| Use a bounded visible worker pair for discovery | Source audit and host/Copool inspection are independent and read-only. |
| Treat host relaunch as an explicit product contract, not an implementation detail | The merged host and legacy Codex app share a bundle ID, and no evidence yet proves cache/read timing. |
| Block rather than infer restart confirmation semantics | Switching credentials and terminating ChatGPT is a user-visible interruption with data-loss potential. |
| Use Contract A for host application | The user selected an explicit “Switch & relaunch ChatGPT” confirmation before credential mutation and host termination. |
| Block rather than edit Pencil without design approval | The deep-design gate requires approval of the full interaction direction before creative or implementation changes. |
| Use the approved account-rail interaction | The user approved the expanded-notch account rail, passive compact indicator, and explicit confirmation sheet. |
| Do not treat MCP canvas state as disk-backed design truth | The editor reports the new board, but the checked-out `.pen` hash remains identical to `HEAD`. |
| Use the saved Pencil Desktop board as the design source | Cmd+S persisted the board; Git now detects 957 changed lines and Desktop canvas proof is visible. |
| Treat the user's recovery instruction as design-spec approval | It reopened the task after the spec-review/persistence gates and current evidence proves persistence. |

## Companion Plan
- Path: `docs/superpowers/plans/2026-07-11-codex-auth-notch-switcher.md`
- Summary: Four TDD slices cover transaction recovery, exact-path host lifecycle, expanded-notch account rail, and release reconciliation.
- Sync-back status: both reviewer rounds reconciled; plan frozen pending immutable-base commit.

## Errors Encountered
| Error | Attempt | Resolution |
|---|---|---|
| None | 0 | Not applicable |
| Pencil account-switching board produced clipping and a blank screenshot | 1 | Record the failure; replace the new board with a fixed-dimension, explicitly positioned layout before accepting any design proof. |
| First Task 2 session-create call had an invalid argument shape | 1 | No thread/worktree was created; removed the extra top-level `projectId` and retried with the valid project target. |
| Task 3 worker reported a build artifact without a clean build exit | 1 | Chief removed `build/`, found two Swift compile errors in `UsageView`, corrected them, and accepted only the subsequent fresh build plus `verify.sh` smoke proof. |

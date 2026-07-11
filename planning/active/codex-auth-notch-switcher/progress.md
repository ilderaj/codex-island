# Progress: Codex Auth Notch Switcher

## Session: 2026-07-11 21:37:03 UTC+8

### Phase 1: Discovery and Source Truth
- **Status:** in_progress
- **Started:** 2026-07-11 21:37:03 UTC+8
- Actions taken:
  - Classified the request as deep tracked work and bound it to `planning/active/codex-auth-notch-switcher/`.
  - Restored prior repo context from memory, then rechecked the active planning set, branch, worktree, source inventory, and current dirty state from the live checkout.
  - Defined a verification contract that rejects build-only and standalone-Codex restart assumptions.
  - Assigned two read-only, visible-worker discovery slices: existing auth/usage behavior and merged-host/Copool relaunch semantics.
  - Verified the Pencil environment: CLI `0.2.8` is current but unauthenticated; the active MCP editor is bound to the established `.pen` source and will be used for the design gate.
  - Reconciled the first visible worker's read-only audit: multi-account local state, per-account background usage, local switch, and a prior-account return affordance exist; notch exposure, multi-account fault coverage, and host application/restart behavior remain unimplemented.
  - Ran fresh baseline `./scripts/run-tests.sh`; exit 0 and all existing test cases passed.
  - Reconciled the second visible worker's host audit: `/Applications/ChatGPT.app` is the current host, while the legacy Codex app shares its bundle ID. Broad bundle/name/PID restart paths are forbidden; Copool is unavailable locally and cannot be imported as evidence.
  - Completed Phase 1 and promoted the task to the design-approval gate.
  - Blocked Phase 2 after three consecutive continuations without a response to the required restart contract choice. No host process, credential, source, or external state was changed.
  - Resumed Phase 2 after the user selected Contract A: explicit confirmation before switch and ChatGPT relaunch.
  - Reblocked Phase 2 after three consecutive continuations without approval of the recommended account-rail design. No Pencil or product-source modification occurred.
  - Resumed Phase 2 after the user approved the account-rail product design; Pencil update and review are now authorized.
  - Created a first Pencil account-switching board, then rejected it after structural clipping and blank screenshot proof. The next attempt will replace only that new board using explicit stable geometry.
  - Rebuilt the board with fixed geometry. Structural layout now reports no problems, but both screenshot and PNG export remain fully white.
  - Verified that the Pencil MCP canvas has not persisted its changes into the tracked `.pen` file; promoted the task to design-spec review rather than claiming a completed Pencil artifact.
  - Restored task after the user confirmed the previous blockers were resolved. Verified Pencil Desktop's edited state, saved it, and confirmed the tracked `.pen` now differs from `HEAD`.
  - Inspected the saved board in Pencil Desktop and re-ran `snapshot_layout`; desktop canvas is visible and structural proof reports no layout problems. MCP screenshot/export remains white and is recorded as a release reconciliation gap.
  - Wrote and self-reviewed the companion implementation plan; placeholder scan and diff check are clean. Independent plan review is the next gate.
  - Received and reconciled the first independent plan review. Revised the companion plan for host identity time-of-use checks, lifecycle outcomes, runtime seams, durable rollback proof, Settings bridging, privacy display, test harness boundaries, Pencil proof, and immutable worktree base.
  - Completed final read-only re-review. Reconciled its two local omissions and froze the plan for immutable-base commit and isolated implementation.
  - Created immutable base commit `4b2794c` (`docs: finalize codex account switcher plan`) and dispatched the visible worktree worker for companion-plan Task 1 only.
  - Worker preflight stopped before edits because native worktree runtime hook output modified `.harness/runtime-hooks/codex.jsonl`. Recorded an exact-path exception and chose respawn rather than continuing a stopped context.
  - Reused the same visible worker after Chief documented the exact-path startup-noise exception. It completed Task 1, then amended its slice after a narrow independent review found two P2 rollback gaps.
  - Independently re-ran the final Task 1 harness and whitespace checks, then cherry-picked the corrected worker commit into `dev` as `cb04ecc`.
  - Committed Task 1's durable receipt as `d60c76b` and dispatched visible isolated Task 2 worker `019f51a5-1620-75a2-840c-f43029b36cfe` from that `dev` baseline.
  - Reconciled Task 2 after the worker's TDD slice. Independently reran its full harness and exact diff checks, then cherry-picked the committed exact-path host lifecycle slice into `dev` as `0780104`.
  - Reused the freshly completed Task 2 visible worktree for Task 3 after recording a narrow plan-table reconciliation: shared-coordinator ownership and privacy-safe default-label coverage require their exact source/test files.
- Files created/modified:
  - `planning/active/codex-auth-notch-switcher/task_plan.md` (created)
  - `planning/active/codex-auth-notch-switcher/findings.md` (created)
  - `planning/active/codex-auth-notch-switcher/progress.md` (created)

## Test Results
| Test | Input | Expected | Actual | Status |
|---|---|---|---|---|
| Source baseline inventory | `rg --files` + focused search | Locate existing auth/usage/UI/test surfaces | Located account store/models/parser/block/tests and Pencil file | pass |
| Task 1 worker baseline | `./scripts/run-tests.sh` in isolated worktree | Existing harness passes before edits | Exit 0 | pass |
| Task 1 RED | `./scripts/run-tests.sh` after new coverage | Fail because writer injection and review assertions are absent | Expected compile/test failures observed before implementation and review fix | pass |
| Task 1 final independent harness | `HARNESS_PROJECT_ROOT=<worker-root> ./scripts/run-tests.sh` | Account transaction and existing tests pass without real auth/process access | All tests passed | pass |
| Task 1 whitespace | `git diff --check 45d458d..6bb3e99` and `git show --check 6bb3e99` | No whitespace errors | Exit 0 | pass |
| Task 2 worker baseline | `./scripts/run-tests.sh` in isolated worktree | Existing Task 1 harness passes before host changes | Exit 0 | pass |
| Task 2 RED | dedicated host harness before Task 2 sources exist | Compile failure | Expected missing-source compile failure observed | pass |
| Task 2 final independent harness | `HARNESS_PROJECT_ROOT=<worker-root> ./scripts/run-tests.sh` | Existing + fake-driven host tests pass without a real host action | All tests passed, including policy, refusal, timeout, target drift, launch retry, and restoration cases | pass |
| Task 2 whitespace | `git diff --check d60c76b..1e47096` and `git show --check 1e47096` | No whitespace errors | Exit 0 | pass |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|---|---|---|---|
| N/A | None | 0 | Not applicable |
| 2026-07-11 22:32 UTC+8 | Worker preflight saw `.harness/runtime-hooks/codex.jsonl` dirty | 1 | Chief approved an exact-path startup-noise exception; any other dirty path remains a stop condition. |
| 2026-07-11 22:39 UTC+8 | Review found non-durable rollback misreporting and untested unknown-auth rollback | 1 | Reused worker for a bounded test-first amend; independently reran the harness before integration. |
| 2026-07-11 22:44 UTC+8 | First Task 2 session-create call had an invalid argument shape | 1 | No state was created; retried with the valid project-target schema. |
| 2026-07-11 22:57 UTC+8 | Narrow Task 2 reviewer did not return before close request stalled | 1 | Do not rely on absent review evidence; Chief performed independent code, diff, and full-harness verification before integration. |

## 5-Question Reboot Check
| Question | Answer |
|---|---|
| Where am I? | Phase 4: Isolated implementation; Task 1 and Task 2 are integrated on `dev`. |
| Where am I going? | Task 3 expanded-notch account rail and confirmation flow, then reconciliation, verification, PR, and release gate. |
| What's the goal? | Safely expose per-account Codex usage and account switching, including the correct merged-host apply/relaunch behavior. |
| What have I learned? | The account primitive is recoverable under the writer contract; host lifecycle can be policy- and fake-tested without broad targeting, but a real post-relaunch auth reload remains unproven. |
| What have I done? | Completed and integrated local transaction recovery plus fake-driven exact-path host coordination without touching real auth or host processes. |

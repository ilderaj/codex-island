# Codex Auth Notch Switcher Design

**Active task:** `planning/active/codex-auth-notch-switcher/`

## Goal

Extend Codex Island so a user can compare local Codex/ChatGPT account usage from the expanded notch, stage a switch to a saved account, and explicitly confirm a safe ChatGPT relaunch that applies the selected local auth snapshot.

## Confirmed Baseline

- The app already imports and persists multiple account snapshots in `~/.codex/accounts/` and keeps the active auth in `~/.codex/auth.json`.
- Per-account usage can already be fetched and stored, but is currently visible only in Settings.
- Current notch surfaces show only `UsageStore.codex` for the active account.
- `/Applications/ChatGPT.app` is the verified current host. The legacy `Codex.app` shares its bundle ID, so bundle-ID and process-name targeting are prohibited.

## Scope

### In scope

- Account label and active-state signal in compact/peek notch surfaces.
- Expanded-notch account rail with each saved account's last known 5h/week usage and freshness.
- Staged selection that does not mutate active auth.
- Explicit `Switch & relaunch ChatGPT` confirmation.
- Atomic local auth switch with restoration on failure.
- A narrow host controller that re-discovers the absolute ChatGPT path and gracefully terminates/reopens only that path after user confirmation.
- Tests for multi-account usage isolation, staged selection behavior, local switch failure recovery, and host-controller decision logic.

### Out of scope

- Cloud account management, keychain migration, auth token display, or remote account synchronization.
- Unattended or background host restarts.
- `killall`, `open -b`, `open -n`, bundle-ID-only launch, or generic process-name matching.
- Claiming that the relaunched host rereads auth until a manual runtime verification proves it.

## Interaction Design

### Compact and peek

Keep these passive. They continue to present the active Codex usage and add only an unobtrusive active-account label or initials. No account picker, destructive command, or multi-account comparison appears here.

### Expanded account rail

The Codex usage region gains an account rail entry point. It shows each locally saved account as a row with:

- account label and plan tag;
- last known 5h and weekly usage;
- active marker;
- stale/error state when no usable usage snapshot exists.

Tapping a non-active row enters a staged selection state. This is reversible and does not touch `~/.codex/auth.json`.

### Staged selection

The selected account is shown alongside its usage and a single explicit primary command: `Switch & relaunch ChatGPT`. The current active account stays visible as context. Returning to the rail cancels the staged selection without writes.

### Confirmation

The confirmation sheet names the selected account and states that Codex Island will preserve the previous local auth, activate the selected snapshot, then quit and reopen `/Applications/ChatGPT.app`. `Cancel` has no effect. The confirm command is the only path that may mutate auth or interrupt ChatGPT.

## Apply and Recovery Contract

1. Re-discover the exact `/Applications/ChatGPT.app` bundle path at confirmation time and validate its executable path.
2. Preserve the previous active auth and registry state before replacing the active auth snapshot.
3. Atomically activate the selected snapshot and verify the replacement.
4. Gracefully terminate the exact discovered ChatGPT application instance.
5. Reopen the same absolute application path.
6. If steps 1-3 fail, restore the preserved local state and do not terminate ChatGPT.
7. If step 4 or 5 fails after a successful local switch, report a specific apply error and expose restoration of the prior local auth; never fall back to a broad process kill.

The app must surface the distinction between `switched locally`, `relaunch attempted`, and `host re-read auth not yet verified`.

## Pencil Contract

The active Pencil MCP canvas contains a new top-level `Codex Account Switching` board with three representative states:

1. `Account rail` compares three accounts and marks the active one.
2. `Review the switch` shows a pending non-active account and the guarded primary command.
3. `Apply to ChatGPT` shows the explicit confirmation, recovery assurance, and cancel path.

The board uses the existing dark island language, restrained cobalt activation, and compact typography. It does not change the existing base boards. At the time of this specification, the MCP canvas state has not yet propagated to the checked-out `.pen` file, so the editor state must be saved/adopted into `docs/design/Codex_Island_Design.pen` before implementation starts.

## Visual Verification

- `snapshot_layout` for the new board reports `No layout problems`.
- Both Pencil `get_screenshot` and PNG export currently render fully white despite the structural layout. This is an environment rendering/export failure; it is recorded as a non-passing visual proof gap and must be rechecked before release.
- The checkout's `.pen` file hash still equals `HEAD`; the final implementation may not claim Pencil alignment until the saved file differs and its structure is re-verified from disk-backed editor state.

## Acceptance Criteria

- A user can identify the active account and inspect saved accounts' last-known usage in the expanded notch.
- Selecting an account has no side effect until the explicit confirmation command is used.
- The confirmation text identifies the account and ChatGPT interruption.
- Local auth replacement is atomic and has a tested restoration path.
- The host controller never uses broad bundle/name/PID targeting.
- Tests and user-facing copy distinguish local switch success from host relaunch success.
- The final implementation has fresh structural Pencil proof and a rerun of visual export/screenshot proof.

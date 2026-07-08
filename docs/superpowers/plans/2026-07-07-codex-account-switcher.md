# Codex Account Switcher Implementation Plan

Review status: approved after read-only reviewer round 2
Task id: `codex-account-switcher-reviewed-plan`
Authoritative task state: `planning/active/codex-account-switcher-reviewed-plan/`

## 1. 当前相关代码结构

`Sources/Usage/UsageFetcher.swift` 目前把 Codex 集成压在一个很小的路径里：读取 `~/.codex/auth.json` 的 `tokens.access_token`，调用 `https://chatgpt.com/backend-api/wham/usage`，把 `rate_limit.primary_window`、`secondary_window` 和 `plan_type` 转成 `AppUsage`。

`Sources/Usage/UsageStore.swift` 是 `@MainActor` singleton，维护当前 active 的 `codex` / `claude` usage、loading 状态、自动刷新 timer 和网络恢复刷新。它现在没有账号维度，main island 和 expanded usage 都消费这一个 active Codex usage。

`Sources/Usage/AppUsage.swift` 的 `WindowUsage` / `AppUsage` 是展示模型，非 `Codable`。账号 registry 应新增持久 DTO，不要强迫现有 UI 模型承担存储格式。

`Sources/Views/SettingsView.swift` 的 Providers tab 当前只有 Claude / Codex provider rows、Token counting 和 Cost section。最小 UI 落点应在 Codex row 下新增 compact `Codex Accounts` block，不引入完整账号管理窗口。

`Resources/en.lproj/Localizable.strings` 和 `Resources/zh-Hans.lproj/Localizable.strings` 是手工双语表。新增文案必须同时补齐。

`build.sh` 直接编译 `Sources/**/*.swift`，没有 SPM target 管理；新增 Swift 文件只要放进 `Sources/` 即可参与 build。`scripts/run-tests.sh` 现在只覆盖 Claude usage resolution，可扩展为账号 parser / key / switch safety 的纯 Swift runner。`scripts/verify.sh` 是 build + smoke launch。

当前项目唯一设计文件是 `docs/design/Codex_Island_Design.pen`。后续执行 UI 实现时，必须通过 Pencil MCP 更新这个 `.pen` 文件中的 Settings UI，不得用 shell 直接读取或编辑 `.pen`。

## 2. 最小架构

采用 Swift-native `codex-auth-lite` 路线：

- `~/.codex/auth.json` 仍然是官方 active Codex 状态。
- CodexIsland 只维护本地 registry 和 auth snapshots。
- “切换账号”就是把选中 snapshot 原子替换到 `~/.codex/auth.json`。
- main island 继续只展示 active Codex account usage。
- Settings > Providers 中提供账号导入、选择、切换、刷新和 compact 状态展示。
- 非 active 账号 usage refresh 只能由显式 `Refresh All` 触发，不做隐式后台轮询。

核心分层：

- `CodexAuthParser`：解析 auth JSON 与 id token JWT payload。
- `CodexAccountStore`：管理 registry、snapshot 文件、import、switch、refresh state。
- `CodexAccountRegistry` / `CodexAccountRecord`：Codable 本地持久模型。
- `UsageFetcher.fetchCodex(context:)`：复用当前 endpoint pattern，但允许传入任意账号 snapshot 的 token 和 account header。
- `CodexAccountsBlock`：Settings Providers tab 内的 compact UI。

## 3. Proposed New Swift Types / Files

新增 `Sources/Usage/CodexAuthModels.swift`：

- `CodexAuthFile: Codable`
- `CodexAuthTokens: Codable`
- `CodexAuthContext`
- `CodexIdentity`
- `CodexUsageSnapshot: Codable`
- `CodexAccountRegistry: Codable`
- `CodexAccountRecord: Codable`
- `CodexIdentityConfidence: String, Codable` with values like `strong`, `medium`, `low`

新增 `Sources/Usage/CodexAuthParser.swift`：

- JSON decode `~/.codex/auth.json`
- JWT payload base64url decode
- metadata-only claims extraction, no signature trust expansion
- account key derivation helper

新增 `Sources/Usage/CodexAccountStore.swift`：

- `@MainActor final class CodexAccountStore: ObservableObject`
- paths: `~/.codex/accounts/registry.json`, `~/.codex/accounts/<accountKey>.auth.json`, `~/.codex/auth.json`
- `importCurrentAuth(label:)`
- `switchToAccount(_:)`
- `switchPrevious()`
- `refreshActiveUsage()`
- `refreshAllUsage()`
- `loadRegistry()` / `saveRegistry()`

新增 `Sources/Views/Settings/CodexAccountsBlock.swift`：

- compact account picker
- Import Current Auth
- Switch Previous
- Refresh Active / Refresh All
- account rows with alias, email, short account/workspace id, plan, 5h/week usage, reset, last refreshed, active marker

新增 `Tests/CodexAccountTests.swift`：

- auth JSON fixture parsing
- JWT payload parsing
- account key derivation
- registry encode/decode compatibility
- switch flow file-copy behavior using temp dirs

可选新增 `Tests/Fixtures/codex-auth-sample.json` 或在 test runner 中内联 fixture，避免误放真实 tokens。

## 4. Proposed Changes To Existing Files

`Sources/Usage/UsageFetcher.swift`：

- 保留 `fetchCodex()` 作为 active-account convenience。
- 新增 `fetchCodex(context: CodexAuthContext) async -> AppUsage`。
- active `fetchCodex()` 改为读取 `CodexAuthParser.readActiveContext()`。
- request headers：
  - `Authorization: Bearer <access_token>`
  - 若有 `chatgptAccountId` 或 `tokens.account_id`，加 `ChatGPT-Account-Id: <id>`
- parse 逻辑保持小而集中。

`Sources/Usage/UsageStore.swift`：

- active refresh 仍设置 `self.codex`。
- 当 active Codex refresh 成功时，通知 `CodexAccountStore` 更新 active record 的 `lastUsage` / `lastUsageAt` / `plan`。
- 切换账号成功后调用 `UsageStore.shared.refresh()`。
- 不把 `UsageHistoryStore` 变成 account-aware；MVP 保持 active usage history。

`Sources/Views/SettingsView.swift`：

- 添加 `@ObservedObject private var codexAccounts = CodexAccountStore.shared`。
- 在 `providersSection` 的 Codex `SettingsRow` 后插入 `CodexAccountsBlock(store: codexAccounts, usage: usage.codex)`。
- 维持 Providers tab 密度，不新增 tab。

`Resources/*/Localizable.strings`：

- 新增账号块、按钮、错误、状态、权限提示、restart note 文案。

`README.md` / `README.zh-CN.md`：

- First run / Privacy / Settings 增补：CodexIsland 会把用户主动导入的 auth snapshots 存在 `~/.codex/accounts/`，不会上传，不提供 OAuth 登录。

`scripts/run-tests.sh`：

- 加入新增 account tests 编译输入。
- 保持无 XCTest / 无 SPM 的现状。

## 5. Data Model And JSON Schema Sketch

Registry path:

`~/.codex/accounts/registry.json`

Snapshot path:

`~/.codex/accounts/<accountKey>.auth.json`

Schema sketch:

```json
{
  "schemaVersion": 1,
  "activeAccountKey": "acct_abcd1234",
  "previousActiveAccountKey": "acct_efgh5678",
  "accounts": [
    {
      "accountKey": "acct_abcd1234",
      "chatgptUserId": "user_...",
      "chatgptAccountId": "account_...",
      "email": "name@example.com",
      "label": "Personal",
      "plan": "pro",
      "createdAt": "2026-07-07T08:00:00Z",
      "lastUsedAt": "2026-07-07T09:00:00Z",
      "lastUsageAt": "2026-07-07T09:01:00Z",
      "lastUsage": {
        "fiveHour": { "usedPercent": 0.42, "resetAt": "2026-07-07T12:00:00Z", "error": null },
        "weekly": { "usedPercent": 0.68, "resetAt": "2026-07-12T00:00:00Z", "error": null }
      },
      "lastError": null
    }
  ]
}
```

Storage notes:

- Registry is local cleartext metadata because the source auth snapshot is already local cleartext under `~/.codex/auth.json`.
- Snapshot files must preserve private permissions, preferably `0600`.
- Registry should be tolerant of missing optional fields for forward compatibility.

## 6. Account Key Derivation Strategy

Never use email alone.

Preferred input:

`chatgpt_user_id + chatgpt_account_id`

Derivation:

- Normalize to `"codex-island-v1:\(userId):\(accountId)"`.
- Use `CryptoKit.SHA256` and encode a short stable prefix, for example `acct_` + first 16 bytes base64url/hex.
- Store full parsed IDs in registry only for local display/debug; use short/redacted UI display by default.

Fallback order:

1. `chatgpt_user_id` / `user_id` / JWT `sub` plus `chatgpt_account_id` / `tokens.account_id`.
2. `principal_id` plus `tokens.account_id`.
3. Hash of stable non-secret metadata only, such as `auth_mode`, `tokens.account_id`, `tokens.principal_id`, JWT `sub`, and issuer/audience when present. Do not include access token, refresh token, id token raw string, `last_refresh`, or other rotating values.

If a newly imported auth derives an existing key, update that account snapshot and metadata instead of creating a duplicate.

Store `identityConfidence` on each account record:

- `strong`: user id and account/workspace id are both present.
- `medium`: principal/sub plus account id are present.
- `low`: only fallback stable metadata was available; UI should avoid overclaiming identity certainty.

## 7. Auth Parsing Strategy

Parse active auth from:

- `auth_mode`
- `last_refresh`
- `tokens.access_token`
- `tokens.id_token`
- `tokens.account_id`
- `tokens.principal_id` if present

JWT parsing:

- Split `id_token` by `.` and decode payload segment as base64url JSON.
- Do not verify signature or use the payload as authorization proof; this is only metadata extraction from a token already stored locally by Codex.
- Extract likely claims:
  - `email`
  - `chatgpt_user_id`
  - `user_id`
  - `sub`
  - `chatgpt_account_id`
  - `account_id`
  - `chatgpt_plan_type`
  - `plan_type`

Error handling:

- Missing access token: import disabled / show `No Codex auth found`.
- JWT parse failure: allow import with lower-confidence key if other stable fields exist; show email/plan as unknown.
- Unsupported schema: record `lastError`, keep existing registry intact.

## 8. Usage Refresh Strategy

Active account:

- `UsageStore.refresh()` remains the main path.
- It calls `UsageFetcher.fetchCodex()` using the currently active `~/.codex/auth.json`.
- On success or useful error, `CodexAccountStore` updates active record usage snapshot.
- Updating `CodexAccountStore` from an active usage refresh must be write-only with respect to refresh orchestration: it updates registry metadata but must not trigger another `UsageStore.refresh()` or `refreshAllUsage()`.

Stored non-active accounts:

- `Refresh All` loads each snapshot and calls `UsageFetcher.fetchCodex(context:)`.
- It must not replace `~/.codex/auth.json`.
- It must send `Authorization` and, when available, `ChatGPT-Account-Id`.
- It updates `lastUsage`, `lastUsageAt`, `plan`, `lastError`.
- It is explicit UI action only; no automatic all-account polling.
- One `Refresh All` click sends at most one usage request per account snapshot present in the registry at click time.
- Track per-account refresh status/error so one failing account does not make the whole block look failed.

Network behavior:

- Reuse current error string style for lightweight captions.
- Do not token-refresh Codex credentials inside CodexIsland.
- Treat 401 as expired auth / run Codex login.
- Treat account-context failures as per-account `lastError`.

## 9. Switch Flow And File Safety Strategy

Switch to stored account:

1. Load registry.
2. Locate target account and snapshot.
3. Read current `~/.codex/auth.json`.
4. If current auth differs from target, import or backup current auth first:
   - if it derives a known account, update that snapshot;
   - otherwise create a fallback “Previous account” record when possible.
5. Prepare the next registry state in memory and atomically save it to a temp registry file that can be promoted only after auth replacement succeeds.
6. Write selected snapshot to a temp auth file beside `~/.codex/auth.json`.
7. Set private permissions on temp auth file, preferably `0600`.
8. Atomically replace active auth path with the temp auth file.
9. Atomically promote the prepared registry update.
10. If registry promotion fails after active auth replacement, immediately attempt rollback to the previous active auth backup and restore the previous registry; if rollback also fails, surface a high-priority inconsistent-state error with both paths.
11. Trigger `UsageStore.shared.refresh()` exactly once after a successful switch.
12. Surface note: Codex CLI/App may need restart for the new account to take effect.

Safety details:

- Ensure `~/.codex/accounts/` exists with owner-only permissions where possible.
- Never delete unknown existing auth.
- Use temp directory tests to cover switch behavior.
- Tests must include the failure case where active auth replacement succeeds but registry promotion fails, verifying rollback or explicit inconsistent-state reporting.
- If any write fails, leave registry and active auth as unchanged as possible and show a clear error.

## 10. UI Changes

Settings > Providers:

- Keep existing Claude and Codex provider rows.
- Add compact `Codex Accounts` block immediately under Codex.
- Controls:
  - account picker/menu
  - `Import Current Auth`
  - `Switch Previous`
  - `Refresh Active`
  - `Refresh All`
- Rows show:
  - active marker
  - label / alias
  - email if available
  - short account/workspace id if available
  - plan chip
  - 5h / week percentage and reset text
  - last refreshed
  - last error

Main island:

- Continue showing only active Codex usage.
- Do not add multi-account display to compact/peek state in MVP.

Expanded usage panel:

- Defer multi-account list unless UI remains clearly within existing density.
- MVP can omit it entirely.

Pencil design requirement:

- Pencil sync is a Settings UI implementation gate, not a post-implementation polish step.
- Before writing the Swift Settings UI, open the active/current project `.pen` through Pencil MCP with schema loaded.
- Update `docs/design/Codex_Island_Design.pen`, specifically the Settings Window / Providers area and any reusable component shelf needed for account rows/buttons.
- Run Pencil layout validation such as `snapshot_layout(..., problemsOnly: true)` on touched frames.
- Record Pencil validation evidence in `planning/active/<task-id>/progress.md`.

## 11. Localization Changes

Add both English and Simplified Chinese keys for:

- `Codex Accounts`
- `Import Current Auth`
- `Switch Previous`
- `Refresh Active`
- `Refresh All`
- `Active`
- `Previous`
- `Last refreshed %@`
- `No Codex auth found`
- `Codex account switched`
- `Codex CLI/App may need restart`
- `Unknown email`
- `Unknown plan`
- `No stored accounts`
- file safety / permissions errors

Keep UI strings English in code, translated through `L10n.tr`.

## 12. Migration / Compatibility Notes

- Existing users with only `~/.codex/auth.json` see no behavior change until they click `Import Current Auth`.
- On first launch after feature, registry may be absent; treat as empty, not error.
- Do not auto-import silently on launch. A passive prompt or empty-state action is okay, but storage should be user-initiated.
- Registry `schemaVersion` starts at `1`; unknown future versions should fail read-only with a helpful error, not rewrite.
- Existing UserDefaults keys remain unchanged.

## 13. Error Handling

User-facing errors should be short:

- missing active auth
- invalid auth JSON
- missing access token
- cannot create accounts directory
- cannot write snapshot
- cannot replace active auth
- snapshot missing
- usage fetch 401 / expired auth
- account context rejected

Implementation should keep detailed technical errors in `lastError` but avoid logging tokens or full unique IDs.

## 14. Security / Privacy Considerations

- Do not print or log access tokens, refresh tokens, cookies, or full unique IDs.
- Do not upload registry or snapshots.
- Do not add a proxy, relay, local `/v1` server, or browser session import.
- Keep stored snapshots under `~/.codex/accounts/`, not app bundle or repo.
- Use private file permissions for snapshots and active auth replacement.
- Make `Refresh All` explicit because it sends one network request per stored account.
- README privacy section must say CodexIsland stores user-imported snapshots locally.

## 15. Testing Strategy

Primary tests:

- `CodexAuthParser` parses representative auth JSON.
- JWT base64url decode handles padding/no padding.
- Account key derivation is stable, deterministic, and does not use email alone.
- Registry decode tolerates missing optional fields.
- Import writes snapshot and registry in a temp `HOME`/path abstraction.
- Switch flow updates `activeAccountKey`, `previousActiveAccountKey`, writes active auth, and preserves previous snapshot.
- `UsageFetcher.fetchCodex(context:)` constructs headers correctly; keep HTTP seam injectable enough for unit tests or narrow request-construction tests.

Backstop verification:

- `./scripts/run-tests.sh`
- `./scripts/verify.sh`
- Manual Settings smoke:
  - no registry
  - import current auth
  - switch previous disabled/enabled
  - refresh active
  - refresh all explicit loading/error states
  - narrow Settings window / scrolled Providers tab does not push or overlap the footer
- Pencil layout validation for updated `.pen` Settings frame.

## 16. Suggested Implementation Phases

Phase 1: Models and parser

- Add Codable auth/account models.
- Add JWT payload extraction.
- Add account key derivation.
- Add parser tests.

Phase 2: Registry and file safety

- Add path abstraction for active auth, registry, snapshots.
- Implement import current auth.
- Implement atomic save and private permissions.
- Add temp-dir tests.

Phase 3: Usage fetch integration

- Refactor Codex fetcher to accept `CodexAuthContext`.
- Update active usage snapshot in registry after refresh.
- Implement explicit refresh all.
- Add request/header and registry update tests where practical.

Phase 4: Switching

- Implement switch to account and switch previous.
- Preserve/backup current auth.
- Trigger active usage refresh.
- Surface restart note.

Phase 5: Pencil-gated Settings UI and localization

- First use Pencil MCP on `docs/design/Codex_Island_Design.pen`.
- Update the Settings Window / Providers design for the compact account block.
- Run Pencil layout validation and record evidence.
- Then implement `CodexAccountsBlock`.
- Insert under Codex provider row.
- Add strings in `en` and `zh-Hans`.
- Keep main island unchanged.

Phase 6: Docs and final verification

- Update README privacy/settings.
- Run tests and smoke build.
- Record implementation evidence and any deferred items.

## 17. Risks / Open Questions

- ChatGPT private usage endpoints may drift; keep the fetcher isolated and error messages clear.
- `ChatGPT-Account-Id` may need exact value from `tokens.account_id` versus JWT claim. Prefer snapshot context with both parsed identity and raw token account id available.
- JWT claim names may vary across personal/team contexts; parser should be tolerant and fixture-driven.
- Atomic replacement across filesystems is safe only when temp file is created beside active auth.
- Multiple tools may read `~/.codex/auth.json` while switching; atomic replace avoids partial reads, but external apps may still need restart.
- Storing multiple auth snapshots increases local credential footprint; UI and README must make this explicit.
- Account-aware usage history is intentionally deferred; if users expect per-account trends later, it needs a separate data model migration.

## 18. Final Recommended MVP Cut

Ship:

- manual import current auth
- local registry + snapshots
- active account picker
- switch previous
- refresh active
- explicit refresh all
- compact Settings account rows
- active account only in main island
- local docs/privacy update
- parser/file-safety tests
- Pencil `.pen` Settings UI update

Defer:

- OAuth login flow
- automatic smart switching
- account-aware historical charts
- expanded panel multi-account table
- background all-account polling
- Codex config mutation
- app/editor restart automation
- proxy/relay/API-key pool behavior
- browser session import

## Review Checklist

- Exact files/surfaces named: yes
- MVP/deferred boundary explicit: yes
- Pencil `.pen` update required: yes
- No implementation in this planning round: yes
- Reviewer gate status: approved

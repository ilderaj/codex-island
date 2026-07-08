# 发现记录：codex-account-switcher-reviewed-plan

## 输入材料

- 用户要求：根据 pasted prompt 使用 `goal2plan` 产出 reviewed implementation plan，完成后停止，不直接执行计划。
- 用户追加约束：计划中必须约定使用 Pencil 在当前项目的 `.pen` 文件上更新 UI。
- pasted prompt 目标：分析当前 `Codex Island` 仓库，规划最小、本地优先的 Codex/ChatGPT 账号切换功能。

## 初始判断

- 当前工作是 tracked + deep-reasoning planning，因为它需要 intake audit、真实仓库盘点、companion plan、read-only reviewer gate 和 durable sync。
- 当前项目存在目标设计文件：`docs/design/Codex_Island_Design.pen`。
- 已有 active task `codex-island-ui-base-pen-replica` 与 `.pen` 设计基座相关，但目标不同；本轮使用独立 task id `codex-account-switcher-reviewed-plan`。

## Intake sufficiency audit

- Root objective：足够明确。目标是最小、本地优先 Codex/ChatGPT 账号切换，并且本轮只产出 reviewed implementation plan。
- Success criteria：足够明确。用户列出计划必须覆盖的 18 个部分，并明确 MVP / deferred 边界。
- Scope boundaries：足够明确。不得做 OAuth login、proxy、relay/account pool、cloudflared、remote deployment、editor restart、opencode sync、`~/.codex/config.toml` 修改、浏览器 session 导入或隐式多账号后台轮询。
- Impacted surfaces：足够明确。主要是 usage fetching、auth parsing、registry/snapshot store、Settings Providers UI、localization、README/privacy docs、tests/build。
- Validation method：足够明确。后续实现应覆盖单元/fixture 级 auth parsing + account key + atomic file write strategy，并运行 repo 现有 `scripts/run-tests.sh`、`scripts/verify.sh`。
- Review needs：足够明确。G2P 要求 1 个只读 reviewer gate；本轮必须停在 reviewed plan。
- Blocking external facts：无阻塞。ChatGPT/Codex 私有 endpoint 可能漂移，但实现计划可以要求沿用当前项目 endpoint pattern，并将 401/403/header/account context 作为验证风险。

## 当前仓库结构盘点

- `Sources/Usage/UsageFetcher.swift`：Codex 当前通过 `readCodexAccessToken()` 读取 `~/.codex/auth.json` 的 `tokens.access_token`，调用 `https://chatgpt.com/backend-api/wham/usage`，解析 `rate_limit.primary_window`、`secondary_window` 和 `plan_type` 为 `AppUsage`。
- `Sources/Usage/UsageStore.swift`：`@MainActor` singleton，维护单一 `codex: AppUsage` 和 `claude: AppUsage`，`refresh()` 并发拉取 active Codex 与 Claude；错误-only fetch 不覆盖已有好值；成功 refresh 写 `UsageHistoryStore`。
- `Sources/Usage/AppUsage.swift`：`WindowUsage` / `AppUsage` 是轻量非 Codable 展示模型，适合新增 Codable snapshot DTO，而不强迫现有 UI 模型变成持久模型。
- `Sources/Usage/UsageHistory.swift`：历史记录按 `AlertEngine.Provider` + window 存在 UserDefaults，当前没有 account 维度；MVP 不应强行改 history 维度，除非后续明确需要多账号历史。
- `Sources/Views/SettingsView.swift`：Providers tab 目前只有 Claude/Codex 两个 `SettingsRow` 和 Cost/Token sections；最小 UI 可以在 Codex row 下加入 compact `Codex Accounts` block。
- `Sources/Views/UsageView.swift` / `PanelHeader.swift` / `PanelFooter.swift`：main island / expanded usage 面向 active provider usage；MVP 应继续只展示 active Codex account，避免重塑 expanded panel。
- `Sources/Model/*Store.swift`：偏好 store 多为 `ObservableObject` singleton + UserDefaults；账号 registry 更适合文件系统 JSON store，避免把 auth metadata 放入 UserDefaults。
- `Resources/en.lproj/Localizable.strings` 与 `Resources/zh-Hans.lproj/Localizable.strings`：双语手工 key-value 表；新增 UI 文案必须两边同步。
- `build.sh`：裸 `swiftc` 编译所有 `Sources/**/*.swift`，无 SPM target 管理；新增 Swift 文件只要放在 `Sources/` 下即可进入 build。
- `scripts/run-tests.sh`：当前只编译 usage resolution 相关测试；后续测试若新增纯 Swift auth/account 逻辑，需要扩展该脚本或增加新 runner。
- `scripts/verify.sh`：build + smoke launch，是后续实现的 acceptance backstop。
- `docs/design/Codex_Island_Design.pen`：当前项目唯一 `.pen` 设计文件；后续 UI 实现阶段必须通过 Pencil MCP 更新，不能直接 shell 读取或编辑。

## 计划约束

- MVP 应新增 Swift-native account system，不引入 Node/Rust/Tauri/CLI 依赖。
- 切换 active Codex account 的实现核心是备份并原子替换 `~/.codex/auth.json`，权限尽量保持 `0600`。
- account key 不得只用 email；优先 `chatgpt_user_id + chatgpt_account_id`，不足时用 token/account claims 的稳定 fallback，并明确冲突处理。
- 对 stored non-active account 的 usage refresh 必须是显式动作，避免 surprise network calls。
- Plan 中必须把 Pencil UI 设计更新列入实现阶段和验收，而不是可选后续。

## Reviewer round 1

- Verdict：approved with required revisions。
- Required revision 1：Pencil 约束与阶段顺序矛盾；必须把 Pencil MCP 更新和 layout validation 改为 Settings UI 实现前置 gate，或同阶段先行步骤。
- Required revision 2：atomic switch 顺序需要更严谨；必须处理 active auth 已替换但 registry 保存失败的不一致状态，并补 temp-dir 测试。
- Required revision 3：`UsageStore` 与 `CodexAccountStore` 互相调用需避免循环刷新/重复写入。
- 已修订：
  - Phase 5 改为 `Pencil-gated Settings UI and localization`，先 Pencil MCP 更新 `.pen` 和 layout validation，再写 Swift UI。
  - switch flow 改为准备 registry、替换 auth、promote registry，并要求失败 rollback 或显式 inconsistent-state error。
  - active usage 写回 registry 明确不得触发 refresh。
  - 采纳 optional 建议：增加 `identityConfidence`、明确 `Refresh All` 一次点击每账号最多一次请求、增加窄窗口/滚动 footer 手工验收。

## Reviewer round 2 focused re-check

- Verdict：approved。
- 复核范围仅限 round 1 的三项 required revisions。
- 结论：
  - Pencil 已成为 Settings UI 前置 gate。
  - Atomic switch 已覆盖 registry promotion failure、rollback / inconsistent-state 报告与测试要求。
  - `UsageStore` 写回 `CodexAccountStore` 已明确不能触发循环刷新。

## 最终计划

- Companion plan：`docs/superpowers/plans/2026-07-07-codex-account-switcher.md`
- Review status：approved after read-only reviewer round 2
- 执行状态：未执行实现，按用户要求停止在 reviewed plan。

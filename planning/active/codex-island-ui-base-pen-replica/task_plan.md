# 任务计划：codex-island-ui-base-pen-replica

## 任务目标

基于当前 `Codex Island` 仓库中的真实 SwiftUI 实现，完整分析并复刻核心 UI 到 [Codex_Island_Design.pen](/Users/jared/Personal%20Projects/Codex%20Island/docs/design/Codex_Island_Design.pen)，将其沉淀为后续 UX / UI 扩展的 base；同时补齐设计 token、设计说明、验证与 reconcile 记录，确保设计资产与代码现状一致且可持续扩展。

## 当前状态

Status: active
Archive Eligible: no
Close Reason:

## 当前轮次分类

- 任务级别：tracked task
- 当前轮次：tracked
- 是否使用 superpowers：否

## 阶段

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| 1. 初始化与上下文恢复 | complete | 已恢复现有 planning / skill / Pencil schema，并为本任务建立独立 planning 三件套 |
| 2. 代码与现有设计盘点 | complete | 已盘点真实 UI 结构、状态、配色、排版、组件层次，并确认现有 `.pen` 基本为空白稿 |
| 3. 设计基座复刻 | complete | 已在 `.pen` 中完成 component shelf、island states、settings window 的结构化复刻 |
| 4. 设计资产沉淀 | complete | 已输出 design tokens、design doc、reconcile / verify 文档 |
| 5. verify / reconcile | complete | 已完成 Pencil layout 验证、仓库 smoke verify，并把结论同步回 planning |
| 6. 用户体验回核纠偏 | complete | 已根据用户指出的体验偏差回到代码与既有 spec，修正 Island States 中的结构性误画 |

## Mode-Aware Verification Contract

- Proof Target：`Codex_Island_Design.pen` 能作为当前项目 UI 的可靠设计基座，覆盖核心界面、设计 token、关键交互状态与后续扩展约束。
- Primary Proof：SwiftUI 源码结构与样式常量、`.pen` 结构快照 / 截图、导出的设计文档与 token 文件之间的交叉核对。
- Backstop Proof：`batch_get` / `snapshot_layout` / `get_variables` 的结构证据，以及必要的本地导出截图或 HTML。
- Escalation Trigger：如果代码中存在未澄清的关键 UI 状态、`.pen` 文件结构异常、或复刻后出现明显结构断裂 / 内容裁切，则暂停收尾，先修正设计资产再继续。
- Evidence Sink：`planning/active/codex-island-ui-base-pen-replica/findings.md`、`progress.md`、`docs/design/`
- Reconcile Rule：每完成一个主要界面或文档产物，都同步记录其覆盖范围、未覆盖项、验证结果与后续扩展约束。
- Unacceptable Substitute：只凭 README 或想象画 UI；只产出截图不产出可维护 `.pen` 结构；只生成 token 文档而不回核代码真实实现。

## 约束与注意事项

- `.pen` 文件只通过 Pencil MCP 工具访问与修改，不直接用 shell 读取内容。
- 以当前仓库代码为唯一 UI 真相来源；已有 `.pen` 只作为待校正资产，不预设其正确性。
- 文档说明用中文；代码、token key、文件名和设计中的界面文案保持英文优先，遵循仓库现状。

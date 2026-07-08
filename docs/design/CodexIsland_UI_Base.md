# CodexIsland UI Base

## Purpose

This design base reconstructs the current CodexIsland UI from the live SwiftUI implementation, not from screenshots or README-only descriptions. It exists to make future UX exploration start from the real product structure rather than from a blank canvas.

## Source of Truth

Primary implementation anchors:

- [App shell](/Users/jared/Personal%20Projects/Codex%20Island/Sources/App.swift)
- [Island runtime state model](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Model/IslandModel.swift)
- [Island root and transitions](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/IslandRootView.swift)
- [Expanded panel composition](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/ExpandedView.swift)
- [Panel header](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/PanelHeader.swift)
- [Paged middle band](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/PagedContent.swift)
- [Usage screen](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/UsageView.swift)
- [Cost screen](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/CostView.swift)
- [Overview screen](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/OverviewView.swift)
- [Panel footer](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/PanelFooter.swift)
- [Settings window](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Views/SettingsView.swift)
- [Theme colors](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Theme/Colors.swift)
- [Typography scale](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Theme/Typography.swift)
- [Motion tokens](/Users/jared/Personal%20Projects/Codex%20Island/Sources/Theme/Animations.swift)

## Design Board Coverage

The `.pen` file [Codex_Island_Design.pen](/Users/jared/Personal%20Projects/Codex%20Island/docs/design/Codex_Island_Design.pen) is organized into three boards:

1. `Component Shelf`
   Captures the reusable visual vocabulary: color tiers, type tiers, chips, toggle, segmented controls, settings row shape, and extension constraints.
2. `Island States`
   Covers the compact, peek, expanded usage, expanded cost, and expanded overview surfaces.
3. `Settings Window`
   Covers one full `General` tab shell plus reference panels for `Display` and `Providers`.

## Structural Conclusions

### 1. The island is a state ladder, not a single screen

CodexIsland behaves as a three-step interaction ladder:

- `compact`: passive presence only
- `peek`: hover-only glance copy
- `expanded`: the only place where full workflow complexity is allowed

Future UX expansion should preserve that ladder. New controls should not be pushed into `compact` or `peek`.

### 2. Expanded panel chrome is stable

The expanded panel has a durable frame:

- provider header on top
- swipeable content band in the middle
- footer utilities at the bottom

That means most future feature work should extend the middle band first instead of redefining the shell.

### 3. Usage, cost, and overview are content modes inside one shell

The design should treat these as sibling screens inside one host, not as different products:

- `Usage`: live quota interpretation
- `Cost`: spend / value / tokens / trend interpretation
- `Overview`: yearly activity history with optional per-day detail

### 4. Settings is a dark utility surface, not a dashboard

The Settings window intentionally avoids dashboard weight. It is:

- dense but readable
- low-contrast
- sectioned by typography and spacing, not by loud cards

This is important for future additions. New settings rows should keep the existing restraint.

## Extension Rules

- Reuse the existing chrome primitives before inventing new ones.
- Add workflow complexity to the expanded middle band before changing shell geometry.
- Prefer tab-local growth in Settings over cross-tab blending.
- Keep provider parity when a feature applies to both Claude and Codex.
- Maintain the notch-native silhouette language in all island states.

## Deliberate Simplification

`swf-simplify: Pencil uses Inter and IBM Plex Mono as safe stand-ins for SF Pro and SF Mono; ceiling: hierarchy, spacing, and component intent remain accurate while glyph metrics are approximate; upgrade trigger: Pencil gains reliable Apple system-font rendering or exported design assets drift from implementation screenshots.`

## Recommended Next Uses

- Explore new footer affordances without redefining header geometry.
- Prototype extra overview detail states inside the existing expanded shell.
- Add provider-specific detail surfaces inside Settings `Providers` before changing the runtime island states.
- Use the `Component Shelf` tokens and primitives as the starting point for any new card, pill, or segmented control.

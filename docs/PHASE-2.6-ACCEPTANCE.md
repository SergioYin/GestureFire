# Phase 2.6 Acceptance — Visual Polish

> Status: **Accepted** (2026-04-08)
> Spec: `docs/phases/PHASE-2.6.md`
> Plan: `docs/design/VISUAL_POLISH_PLAN.md`
> Retrospective: `REVIEW.md` Phase 2.6 section

## Scope

Phase 2.6 was a pure-visual phase: design system foundation, surface hierarchy on Settings tabs, visual weight on status indicators, onboarding visual lift, status panel readability, and a 4pt spacing grid. A hardening pass followed to address three user-reported issues (one of which turned out not to be a regression at all).

## Deliverables

### V1 — Design System
- `Sources/GestureFireApp/DesignSystem.swift` (new)
  - `Spacing` enum: 4pt grid (`xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`)
  - `SettingsCard`: rounded rect with `.background.secondary` fill
  - `StatusBadge`: icon + text in tinted capsule

### V2 — Settings Surface Hierarchy
- `.formStyle(.grouped)` on Feedback, Gestures, Advanced tabs (native card grouping, preserves keyboard nav and accessibility)
- Section headers: `.subheadline.weight(.medium)`
- Advanced: parameter values right-aligned in `.title3.monospacedDigit()`, slider `.tint(.accentColor)`
- Status tab: converted from `Form` to `ScrollView` — engine state hero card with tinted background, console-style recent events, `SettingsCard` wrappers for system checks and connection test

### V3 — Onboarding Visual Lift
- Step indicator: 32pt pills (from 24pt), `.callout.bold()` numbers, 48px connecting lines
- Permission/Confirm steps: 96pt background circles + 44pt icons
- Preset cards: `Color(.controlBackgroundColor)` unselected fill, accent-colored left border bar on selection
- Practice step: calibration grid inside card, accent-tinted current row

### V4 — Status Panel Readability
- `.title` icon, `.headline` title text
- 3pt accent-colored left border for visual identity
- Material: `.ultraThinMaterial` (reverted from `.thickMaterial` during beep investigation — see Known Limitations)

### V5 — Spacing Pass
- All hardcoded padding values replaced with `Spacing` constants across all view files

### Hardening Pass (post V1–V5)
- **Wizard stability**: `ScrollView` wrapper around step content; fixed-height action areas per step to prevent layout jumping when conditional sections appear/disappear; nav bar Back button uses `opacity(0)` + `disabled` instead of conditional removal; Practice step action area merged into a single stable `VStack(minHeight: 60)` with a reserved secondary-info line
- **Settings tab bar prominence**: Replaced native `TabView` with a custom top navigation bar — `SettingsTabButton` components inside a `.bar`-backed `HStack` with a `Divider`. Selected state: accent-colored foreground + `.semibold` + `opacity(0.12)` tinted background
- **Status panel hardening**: `SilentPanel` NSPanel subclass overriding `canBecomeKey`/`canBecomeMain` → `false`; panel ordered front exactly once at creation (alpha 0); show/hide cycle uses only `alphaValue` — no `orderFront`/`orderOut` calls after creation

## Automated Verification

| Check | Result |
|-------|--------|
| `swift build` | ✅ Clean build |
| `swift test` (153 tests, 30 suites) | ✅ All pass, zero regression |
| New tests added | 0 (pure visual, no behavior change) |

## Manual Verification

### Visual Hierarchy
- [x] Settings tab bar is clearly visible at the top of the window and reads as primary navigation
- [x] Current Settings tab is unmistakably distinct from other tabs
- [x] Engine state card in Status tab is readable at a glance
- [x] Onboarding preset cards are visibly distinct selected vs unselected (accent bar + tinted background)
- [x] Status panel gesture name is readable

### Wizard Stability
- [x] Permission step: state transitions (unknown → requested → granted) do not cause layout jumping
- [x] Preset step: mapping area appears without pushing content up/down jarringly
- [x] Practice step: start button → "Try: X" → completion badge transitions happen without the action area shifting
- [x] Nav bar Back/Next buttons do not cause the bottom bar to jump between steps

### Settings Navigation
- [x] Opening Settings immediately shows 5 tabs as primary navigation
- [x] Clicking between tabs is instant and visually clear
- [x] Selected tab state is obvious

### Regression
- [x] All Phase 2.5 acceptance criteria still pass
- [x] Sound feedback, status panel, launch-at-login, log viewer, onboarding flow all functional
- [x] 153 tests pass

## Known Limitations (Non-Blocking)

### 1. CGEvent "funk" beep on unhandled shortcuts — NOT a Phase 2.6 regression
**Symptom**: A macOS system sound plays when a gesture triggers a shortcut the foreground app does not handle.
**Root cause**: Standard macOS "funk" / invalid-key sound, produced by the **target app** when it receives an unhandled `CGEvent` key combination. This is OS-level behavior inherent to `CGEvent`-based shortcut simulation, not a GestureFire bug, and has nothing to do with the status panel or any Phase 2.6 visual change.
**Confirmation**: User reproduced with the status panel disabled — definitively ruling out panel-related causes.
**Resolution**: Carried over to Phase 4 — `FeedbackCorrelator` will detect unused mapped shortcuts and surface a warning so users can remap.
**What we did keep from the investigation**: The `SilentPanel` + single-orderFront + alpha-only show/hide cycle is retained as a genuine hardening of the panel's window interaction, even though it was not the actual cause of the beep.

### 2. Custom Settings tab bar loses `Cmd+1..5` keyboard cycling
**Symptom**: Native `TabView` supports `Cmd+1..5` for tab switching out of the box. The custom tab bar does not.
**Resolution**: Carried over to Phase 3 — add `.keyboardShortcut` modifiers to each `SettingsTabButton`.

### 3. Tab key / VoiceOver verification pending
**Symptom**: Status tab `ScrollView` conversion and custom Settings tab bar have not been manually verified against Tab-key focus traversal or VoiceOver.
**Resolution**: Carried over to Phase 3 — manual accessibility pass before adding new gesture UI that inherits these patterns.

### 4. LogViewerView alternating row tint not implemented
**Symptom**: V2 plan called for alternating row tint in the Logs tab. Not achievable inside SwiftUI `List` without custom row rendering.
**Resolution**: Carried over to Phase 3 — reconsider with custom row rendering outside `List`.

## Carry-Over Items

Every item has an explicit target phase. No `later` / `TBD` / unphased items.

| Item | Target Phase | Priority | Notes |
|------|-------------|----------|-------|
| Unused-shortcut detection / warning (root cause of the "beep" false alarm) | Phase 4 | P1 | `FeedbackCorrelator` natural home |
| Settings tab bar `Cmd+1..5` keyboard cycling | Phase 3 | P2 | Add `.keyboardShortcut` to each `SettingsTabButton` |
| Tab key / VoiceOver manual verification | Phase 3 | P1 | Status tab ScrollView + custom tab bar |
| ShortcutField pill restyle | Phase 3 | P2 | Changes interaction affordance, excluded from visual-only scope |
| Slider endpoint labels | Phase 3 | P2 | New visual elements |
| Onboarding step transition animation | Phase 3 | P3 | Behavior change |
| LogViewerView alternating row tint | Phase 3 | P3 | Requires custom row rendering outside `List` |
| Card hover effects | Phase 5 | P3 | New interaction pattern |
| Custom dark/light specialization | Phase 5 | P3 | Low priority polish |

## Decision: Proceed to Phase 3?

**Yes.** Phase 2.6 is complete and accepted. The visual foundation, wizard stability, and settings navigation are in a shippable state. Phase 3 (More Gestures) can proceed without waiting on any Phase 2.6 item — all pending items are either accessibility verification (can happen alongside Phase 3 kickoff) or visual polish that naturally fits alongside new gesture UI work.

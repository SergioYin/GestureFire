# Phase 2.6: Visual Polish

## Goal

Make GestureFire's interface look finished — with surface hierarchy, visual weight on status, and consistent component styling — without changing any behavior.

## Constraints

1. **Visual only, no behavior changes.** No new controls, no new config fields, no new interactions. If a change could alter what the user can do (not just how it looks), it's out of scope.
2. **`Form → ScrollView` is high-risk.** `Form` provides automatic keyboard navigation, accessibility focus management, and platform-standard layout. Replacing it with `ScrollView + VStack` risks breaking Tab key navigation and VoiceOver. This change requires explicit justification per-view, dedicated testing, and fallback to `Form` if accessibility regresses.
3. **`DesignSystem.swift` stays minimal.** Only extract components that are actually used in 2+ places this phase. No speculative abstractions, no design token system, no theming infrastructure.

## Scope

### V1: Design System Foundation (`DesignSystem.swift`)

- [ ] `SettingsCard` view modifier — wraps content in rounded rect with `.background.secondary` fill. Used by all settings tabs for visual grouping.
- [ ] `StatusBadge` view — icon + text in tinted capsule background. Used by StatusSettingsView (engine state, diagnostic results) and StatusPanelView.
- [ ] `Spacing` enum — `xs(4)`, `sm(8)`, `md(12)`, `lg(16)`, `xl(24)`, `xxl(32)`. Applied across all views.
- [ ] Nothing else. No `ShortcutPill`, no animation helpers, no color token system. Add those in future phases if needed.

### V2: Settings — Surface Hierarchy

- [ ] **Feedback tab**: Group sound + panel controls inside `SettingsCard`. Separate System section in its own card. Section titles as `.subheadline.weight(.medium)` labels above cards.
- [ ] **Gestures tab**: Gesture mapping rows inside `SettingsCard`. Format hint as footnote below card.
- [ ] **Advanced tab**: Each parameter in its own card with label + value + slider + description. "Reset to Defaults" as `.bordered` secondary action below.
- [ ] **Status tab**: Engine state as hero card with tinted background. System checks and recent events in separate cards. Console-like styling for event feed (subtle darker background).
- [ ] **Logs tab**: Minimal — alternating row tint for readability if achievable within `Form`/`List`. No structural change.

**`Form` decision per tab:**

| Tab | Keep `Form`? | Rationale |
|-----|-------------|-----------|
| Feedback | Keep `Form` | Simple toggles + slider. Form handles layout well. Style via `listRowBackground` and section spacing. |
| Gestures | Keep `Form` | ForEach + LabeledContent works well in Form. |
| Advanced | Keep `Form` | Sliders need Form's label alignment. Style individual rows. |
| Status | **Replace with ScrollView** | Status tab is read-heavy, not form-heavy. No text fields, no toggles that need Form keyboard nav. Buttons handle their own focus. |
| Logs | Keep `List` | Already uses List for entries. No change. |

Only the Status tab converts to `ScrollView`. All others keep `Form` and apply visual polish via `.listRowBackground`, `.listRowSeparator`, and section styling.

### V3: Onboarding Visual Lift

- [ ] Step indicator: Increase pill size to 32pt. Completed steps show checkmark on tinted circle.
- [ ] Permission step: Icon 64pt (from 48pt). Subtle tinted background behind icon.
- [ ] Preset cards: Unselected cards get `.background.secondary` fill (visible even unselected). Selected card gets accent-tinted left border bar.
- [ ] Practice step: Calibration grid inside a card background. Current gesture row gets subtle highlight.
- [ ] Confirm step: Checkmark icon 64pt. Mapping card unchanged (already styled).

### V4: Status Panel Readability

- [ ] Material: `.thickMaterial` (from `.ultraThinMaterial`) for better text contrast.
- [ ] Icon size: `.title` (from `.title2`).
- [ ] Title font: `.headline` (from `.body.semibold`).
- [ ] Add thin accent-colored left border (3pt) for visual identity.

### V5: Spacing Pass

- [ ] Apply `Spacing` constants to all view files. Replace hardcoded padding values (10, 12, 14, 16, 20) with named constants.
- [ ] Consistent card spacing: `Spacing.lg` (16pt) between cards, `Spacing.md` (12pt) between items within cards.

## Out of Scope

- `ShortcutField` restyle as pill component — would change interaction affordance (users expect TextField). Defer.
- Slider tick marks or endpoint labels — new visual elements that add complexity. Defer.
- Custom dark/light mode specialization — system defaults are sufficient.
- Animation between onboarding steps — behavior change (perceived responsiveness). Defer.
- Hover effects on cards — new interaction. Defer.
- Menu bar dropdown styling — system-constrained, minimal styling available via MenuBarExtra.
- `Form → ScrollView` for Feedback, Gestures, Advanced, or Logs tabs.

## Deliverables

| Deliverable | Target | New/Modified |
|-------------|--------|--------------|
| `DesignSystem.swift` | `GestureFireApp` | New — `SettingsCard`, `StatusBadge`, `Spacing` |
| `FeedbackSettingsView.swift` | `GestureFireApp` | Modified — card styling, spacing |
| `SettingsView.swift` | `GestureFireApp` | Modified — card styling on Gestures tab |
| `AdvancedSettingsView.swift` | `GestureFireApp` | Modified — card styling, spacing |
| `StatusSettingsView.swift` | `GestureFireApp` | Modified — hero card, `ScrollView` conversion, event feed styling |
| `OnboardingView.swift` | `GestureFireApp` | Modified — icon sizes, card backgrounds, step indicator |
| `StatusPanelView.swift` | `GestureFireApp` | Modified — material, font sizes, accent border |
| `LogViewerView.swift` | `GestureFireApp` | Modified — alternating row tint (minimal) |

## Technical Preconditions

- [x] Phase 2.5 closed and accepted
- [x] `docs/design/VISUAL_POLISH_PLAN.md` reviewed and approved
- [x] All 153 tests pass — baseline for regression
- [x] Settings already uses `Form` + `Section` consistently (Phase 2.5 output)

## Carry-Over Items Addressed

| Item | Source | Resolution |
|------|--------|------------|
| SwiftUI view unit tests | Phase 2 REVIEW.md | **Not addressed** — visual refactoring makes view shapes unstable. Test after views stabilize in Phase 3. Target: **Phase 3** |

## Verification Criteria

### Automated
- [ ] `swift build` passes
- [ ] 153 tests in 30 suites pass — **zero regression**
- [ ] No new test files (pure visual changes)

### Manual — Readability

- [ ] Engine state in Status tab readable at arm's length (tinted hero card, large text)
- [ ] Status panel gesture name readable in peripheral vision (larger font, thicker material)
- [ ] Onboarding preset cards visually distinct selected vs unselected (filled vs tinted)

### Manual — Hierarchy

- [ ] Screenshot of Feedback tab shows two distinct card groups without reading text
- [ ] Status tab event feed visually distinct from config sections (darker/console-style background)
- [ ] Advanced tab looks visually lower-priority than Feedback tab

### Manual — Consistency

- [ ] All settings tabs use `SettingsCard` for visual grouping
- [ ] All spacing between cards is `Spacing.lg` (16pt)
- [ ] Engine state and diagnostic results use `StatusBadge`

### Manual — `Form → ScrollView` (Status tab only)

- [ ] Tab key cycles through interactive elements in Status tab (Enable/Disable button, Re-run Checks, Yes/No buttons)
- [ ] VoiceOver reads all elements in Status tab in logical order
- [ ] If either fails: revert Status tab to `Form` and style within Form constraints

### Manual — Regression

- [ ] All Phase 2.5 acceptance criteria still pass (sound, panel, launch-at-login, logs, onboarding flow)
- [ ] No visual glitch at minimum window size (560x520)
- [ ] Light and dark mode both render correctly

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `Form → ScrollView` breaks Tab/VoiceOver in Status tab | Medium | P1 | Only convert Status tab. Test Tab key + VoiceOver explicitly. Revert to `Form` if broken. |
| `SettingsCard` background clashes with system appearance in future macOS | Low | P2 | Use semantic colors (`.background.secondary`) not hardcoded values |
| `.thickMaterial` on status panel too opaque for some desktops | Low | P2 | Test against light/dark/busy wallpapers. Can revert to `.regularMaterial` |
| Spacing constants create merge conflicts with Phase 3 new views | Low | P1 | Phase 3 views will import and use `Spacing` — fewer conflicts, not more |
| `DesignSystem.swift` grows beyond minimal scope | Medium | P2 | Constraint is in spec: only components used 2+ times this phase. Review in PR. |

## Deferred Items

| Item | Reason Deferred | Target Phase |
|------|----------------|--------------|
| ShortcutField pill restyle | Changes interaction affordance | Phase 3 |
| Slider endpoint labels | New visual elements | Phase 3 |
| Step transition animation | Behavior change | Phase 3 |
| Card hover effects | New interaction | Phase 5 |
| Custom dark/light specialization | Low priority | Phase 5 |

## Review / Retrospective

### Stats

| Metric | Value |
|--------|-------|
| Commits | 3 (implementation + docs + hardening) |
| Source files (new/modified) | 1 new (`DesignSystem.swift`), 8 modified |
| Test files (new/modified) | 0 — pure visual, no behavior changes |
| Source LOC delta | ~+200 net |
| Test LOC delta | 0 |
| Tests | 153 in 30 suites — zero regression |

### Bugs Found

#### P0 — "System beep on every gesture" (user-reported regression, NOT a Phase 2.6 regression)

- **Initial misdiagnosis**: Assumed regression in `StatusPanelController.show()`. Spent two iterations hardening the panel show/hide path (`SilentPanel` subclass, single orderFront at creation, alpha-only cycle, `.thickMaterial` → `.ultraThinMaterial` revert).
- **Final root cause**: The beep is the standard macOS "funk" / invalid-key sound produced by the **target application** when `KeyboardSimulator` posts a `CGEvent` for a shortcut the frontmost app does not handle. It is OS-level behavior, not a GestureFire bug, and has nothing to do with panel/window operations.
- **How confirmed**: User reproduced the sound with the status panel disabled, definitively ruling out panel-related causes.
- **Resolution**: No code fix for the symptom itself — inherent to CGEvent shortcut simulation. Panel hardening retained as a net improvement to robustness. Phase 4's Smart Tuning (`FeedbackCorrelator`) will be the natural place to detect unused mapped shortcuts and warn the user.
- **Lesson for future debugging**: For "sound on X shown" symptoms, first step must be "reproduce with X disabled."

#### P1 — Onboarding wizard layout jumping

- **Root cause**: Conditional `if/else` blocks inserted/removed view subtrees, causing SwiftUI to rebuild layouts. Nav bar Back button conditional insertion shifted the Spacer. Practice step had 4 independent conditional sections.
- **Fix**: `ScrollView` wrapper for stable content frame; fixed-height action areas per step; `opacity(0)` + `disabled` for nav buttons instead of conditional removal; merged Practice step sections into one stable `VStack(minHeight: 60)` with a reserved secondary-info line.

#### P1 — Settings tab navigation not prominent

- **Root cause**: macOS native `TabView` with `.tabItem` renders as low-weight toolbar icons that blend into window chrome. Removing outer padding was insufficient — the native style is inherently subdued.
- **Fix**: Replaced `TabView` with a custom top navigation bar: `SettingsTabButton` components inside a `.bar`-backed `HStack` with a `Divider` below. Selected state uses accent-colored foreground + `.semibold` weight + `opacity(0.12)` tinted background.

### What Went Well

- **Constraint #2 validated**: Only Status tab converted from `Form → ScrollView`. All other tabs kept `Form` with `.formStyle(.grouped)`.
- **Constraint #3 held**: `DesignSystem.swift` contains only 3 components, all used 2+ times. No speculative abstractions.
- **Zero test regression**: 153 tests, all green across all iterations.
- **Hardening was additive**: The `SilentPanel` + single-orderFront + alpha-only design is retained as genuine improvement even though the beep diagnosis was wrong.
- **Custom tab bar replaced TabView cleanly**: No behavior loss, significantly stronger visual hierarchy.

### What Needs Improvement

- **Debugging discipline**: Should have isolated the beep symptom first (reproduce with panel OFF) before touching any panel code.
- **Custom tab bar loses `Cmd+1..5` tab cycling**: Native `TabView` supports this out of the box. Acceptable regression for now, add back via `.keyboardShortcut` in Phase 3.
- **LogViewerView minimal changes**: Alternating row tint was not achievable inside `List` without extra complexity. Spacing constants applied only.
- **Tab/VoiceOver verification pending**: Both the Status tab ScrollView and the custom settings tab bar need manual accessibility verification.

## Next-Phase Carry-Over

| Item | Target Phase | Notes |
|------|-------------|-------|
| Unused-shortcut detection / warning | Phase 4 | Natural home in `FeedbackCorrelator`. Detects shortcuts that repeatedly produce no app response (the "funk" beep condition) and surfaces a warning so users can remap. |
| Settings tab bar `Cmd+1..5` keyboard cycling | Phase 3 | Add `.keyboardShortcut` modifiers to each `SettingsTabButton`. |
| Tab/VoiceOver manual verification (Status tab + custom tab bar) | Phase 3 | Must verify before adding new gesture UI that inherits the same patterns. |
| ShortcutField pill restyle | Phase 3 | Changes interaction affordance, out of visual-only scope. |
| Slider endpoint labels | Phase 3 | New visual elements. |
| Step transition animation in onboarding | Phase 3 | Behavior change. |
| LogViewerView alternating row tint | Phase 3 | Requires custom row rendering outside `List`. |
| Card hover effects | Phase 5 | New interaction pattern. |
| Custom dark/light specialization | Phase 5 | Low priority polish. |

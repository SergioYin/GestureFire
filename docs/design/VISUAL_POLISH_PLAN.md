# Visual Polish Plan

> Created: 2026-04-03
> Status: **Implemented as Phase 2.6 (2026-04-08)** — see `docs/phases/PHASE-2.6.md` for spec and retrospective
> Prerequisite: Phase 2.5 (structural polish) completed

## Completion Status (2026-04-08)

All sections of this plan were implemented in Phase 2.6, with the following notes:

| Plan Section | Status | Notes |
|--------------|--------|-------|
| 4.1 DesignSystem.swift | ✅ Done | `Spacing`, `SettingsCard`, `StatusBadge` — minimal, no speculative abstractions |
| 4.2 Feedback tab | ✅ Done | `.formStyle(.grouped)` used instead of ScrollView (safer, same visual result) |
| 4.3 Gestures tab | ⚠️ Partial | Grouped-form card styling done. ShortcutField pill restyle deferred to Phase 3 (changes interaction affordance). |
| 4.4 Advanced tab | ✅ Done | Value right-aligned in `.title3.monospacedDigit()`, accent-tinted slider |
| 4.5 Status tab | ✅ Done | Hero engine state card, console-style recent events, SettingsCard wrappers |
| 4.6 Onboarding | ✅ Done | Plus stability hardening pass for conditional layout jumping |
| 4.7 Status Panel | ⚠️ Modified | `.thickMaterial` reverted to `.ultraThinMaterial` after beep investigation. Other changes (accent border, `.title` icon, `.headline` title) kept. |
| 4.8 Log Viewer | ⚠️ Minimal | Only spacing constants applied. Alternating row tint not achievable in `List` without extra complexity. Deferred to Phase 3. |

**Additional changes not in original plan (hardening pass):**
- Settings: replaced native `TabView` with custom tab bar for stronger navigation prominence
- Onboarding: `ScrollView` wrapper + fixed-height action areas to prevent layout jumping
- Status panel: `SilentPanel` subclass + single-orderFront design for defensive hardening

## 1. Why the Interface Still Looks Rough

Phase 2.5 solved the information architecture problem — tabs are logical, jargon is gone, structure is clean. But every view still renders as **bare SwiftUI `Form` with default system styling**. The result is organized but visually flat, like a well-structured spreadsheet.

Specific problems:

### 1.1 Everything Looks the Same

Every settings tab is `Form { Section("Title") { controls } }`. macOS renders this as a grouped list with thin separator lines. There is zero visual distinction between:
- The Feedback tab (3 controls the user touches daily)
- The Advanced tab (4 sliders the user may never touch)
- The Status tab (live diagnostic data)

They all have the same background, the same row height, the same header weight. Nothing signals "this tab is important" vs "this tab is for power users."

### 1.2 No Visual Depth or Hierarchy

The interface is completely flat. No surface layering, no cards, no elevation. Every element sits on the same plane at the same Z-level. This makes it hard to distinguish:
- A group of related controls (e.g., sound toggle + volume slider)
- A standalone action (e.g., Reset to Defaults)
- A status display (e.g., engine state)

macOS apps like System Settings, Raycast, and CleanMyMac use surface cards (rounded rectangles with subtle fill) to create visual groups. GestureFire uses only Section headers, which are thin and easy to miss.

### 1.3 Status Indicators Are Text-Only

Engine state, diagnostic results, and pipeline events are all communicated via small text with a color dot. There's no visual weight to status. Compare:

**Current**: A small SF Symbol + "Running" in `.headline` + explanation in `.caption`
**Better**: A filled card with tinted background showing the state, making it readable at a glance from across the room

### 1.4 Onboarding Has No Visual Warmth

The wizard is structurally sound but visually cold. Preset cards are thin outlined rectangles with small text. The permission step is a centered column of text. The practice grid is a flat list. Nothing about it feels like "welcome to something new."

Specific issues:
- Step indicator pills are 24pt — too small to create a visual anchor at the top
- Preset cards use `Color.clear` background for unselected state — they disappear visually
- Practice calibration grid has no background or grouping — it floats in whitespace
- "Start GestureFire" button on the confirm step is `.borderedProminent` (good) but competes with the mapping summary for attention

### 1.5 Status Panel Lacks Presence

The floating HUD is `.ultraThinMaterial` with `cornerRadius(10)`. This is the macOS standard look, but for a panel that appears for 3 seconds to confirm a gesture, it needs to be instantly readable. Currently:
- The icon, title, and subtitle are the same visual weight
- No clear visual separation between "what happened" (gesture name) and "what was done" (shortcut sent)
- Material background can wash out against busy desktops

### 1.6 Controls Look Like Developer Tools

The shortcut field is a raw `TextField` with `.roundedBorder` style. It looks like a form input, not a shortcut recorder. Users familiar with System Preferences or apps like Raycast expect a styled shortcut recorder (rounded pill, keyboard-style appearance).

The parameter sliders in Advanced are unlabeled tracks with a number readout. They work but feel like debug controls, not user-facing settings.

### 1.7 Spacing and Rhythm Are Inconsistent

- SettingsView applies `.padding()` on the outer TabView — but this creates different amounts of whitespace depending on content height
- OnboardingView uses `spacing: 20` between all elements regardless of logical grouping
- Log viewer toolbar has `padding(.horizontal)` + `padding(.vertical, 8)` — slightly different from other views
- No shared spacing constants — each view picks its own numbers

---

## 2. Pages Ranked by Visual Need

| Priority | Page | Reason |
|----------|------|--------|
| 1 | **Onboarding** | First impression. The only chance to signal quality before the user decides to keep or uninstall. |
| 2 | **Settings (Feedback + Gestures)** | Most-visited tabs. Daily configuration surface. |
| 3 | **Status Panel** | Appears frequently during use. Must be instantly readable. |
| 4 | **Settings (Status)** | Diagnostic view, now embedded in settings. Should feel distinct from config tabs. |
| 5 | **Settings (Advanced + Logs)** | Power-user tabs. Functional appearance is acceptable. |
| 6 | **Menu Bar dropdown** | System-constrained — limited styling available via MenuBarExtra. Lowest priority. |

---

## 3. Visual Direction

### Target: Refined System Native

Not custom-themed. Not flat-white-minimalist. Not skeuomorphic. The target is **macOS System Settings quality** — clean, readable, with intentional surface hierarchy. Think the difference between a plain `List` and the styled grouped cards in System Settings → Wi-Fi.

Concrete principles:

**A. Surfaces, not separators.** Replace `Section` dividers with filled `RoundedRectangle` cards as visual containers. Each logical group gets its own surface. This is how System Settings, Raycast, and Bartender style their preferences.

**B. Status gets visual weight.** State indicators (engine running, diagnostic pass/fail) use tinted background fills, not just colored dots. A green-tinted card for "Running" is readable in peripheral vision. A green dot next to text is not.

**C. Consistent component vocabulary.** Define a small set of reusable styled components:
- `SettingsCard` — rounded rect with subtle fill, for grouping controls
- `StatusBadge` — icon + label with tinted background, for state display
- `ShortcutPill` — styled shortcut display/input, replacing raw TextField

**D. Intentional whitespace.** Define spacing constants and use them everywhere. Not "20pt because that felt right" but a 4pt grid system (8, 12, 16, 24, 32).

**E. Typography with weight.** Section titles get `.headline` weight. Status values get `.title3` or larger. Help text stays `.caption`. Currently everything is too close in size.

---

## 4. Specific Visual Changes

### 4.1 Shared Components (New File: `DesignSystem.swift`)

Define reusable components once:

**`SettingsCard`**: A `ViewModifier` that wraps content in a rounded rectangle with system grouped background fill. Replaces bare `Section` for visual grouping.

```
content
    .padding(16)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
```

**`StatusBadge`**: Icon + text with tinted background pill. Used for engine state, diagnostic results, pipeline events.

```
HStack {
    Image(systemName: "circle.fill")
    Text("Running")
}
.padding(.horizontal, 10)
.padding(.vertical, 4)
.background(Color.green.opacity(0.15), in: Capsule())
.foregroundStyle(.green)
```

**Spacing constants**:

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
```

### 4.2 Settings — Feedback Tab

**Before**: `Form > Section("Recognition Feedback") > Toggle + Slider + Toggle`

**After**: Replace `Form` with `ScrollView` + `VStack` of styled cards.

- **Feedback card**: Sound toggle, volume slider, panel toggle — inside a single `SettingsCard`. Sound and panel toggles visually paired as "two feedback channels."
- **System card**: Launch-at-login — separate card below.
- Each card has a small header in `.subheadline.weight(.medium)` above it, not inside.
- Volume slider gets tick marks or at minimum a "quiet 🔈 ... loud 🔊" label pair at the ends.

### 4.3 Settings — Gestures Tab

**Before**: `Form > Section > ForEach(gestures) > LabeledContent > ShortcutField`

**After**:
- Each gesture mapping becomes a card row: gesture name on the left, shortcut pill on the right.
- `ShortcutField` restyled as a rounded pill with monospaced text, keyboard-cap appearance (slight inset shadow or border). When empty, shows placeholder "Click to set" in muted text.
- Format hint moved below the card group as `.caption` footnote.

### 4.4 Settings — Advanced Tab

**Before**: `Form > Section > VStack(label + slider + description)`

**After**:
- Each parameter gets its own card with: label + current value (right-aligned, `.title3.monospacedDigit`) above the slider, description below.
- Slider track styled with `.tint(.accentColor)` for the filled portion.
- "Reset to Defaults" styled as a secondary action (`.bordered` style, not prominent), at the bottom.

### 4.5 Settings — Status Tab

**Before**: `Form > Section("Engine") + Section("System Checks") + Section("Recent Events") + Section("Connection Test")`

**After**:
- **Engine state hero**: Full-width card at top with large icon, state name in `.title3`, explanation below. Tinted background matching state color (green for running, orange for needs permission, etc.). Action button inline.
- **System checks**: Each check is a compact row inside a card. Pass/fail icons are 20pt, not 14pt.
- **Recent events**: Dark-themed (`.background(.black.opacity(0.03))`) card with monospaced timestamps, giving it a "console" feel distinct from config tabs.
- **Connection test**: Only shown after checks pass. Card with prominent "Yes / No" buttons.

### 4.6 Onboarding

**Step indicator**: Increase pill size to 32pt. Add a subtle connecting track (2pt line between pills). Current step pill gets a shadow or scale effect.

**Permission step**: Large icon (64pt instead of 48pt). Add a subtle gradient or tinted background behind the icon to create a focal point. Button is already `.borderedProminent` + `.controlSize(.large)` — good.

**Preset step**: Cards get a subtle fill even when unselected (`.background(.background.secondary)`). Selected card gets accent-colored left border bar (4pt) instead of just a border outline. Icons inside cards bump to `.title` size.

**Practice step**: Calibration grid gets a card background. Current gesture row gets a highlighted background (accent tint), not just primary-colored text. "Start Gesture Test" button gets top padding to separate it from the grid.

**Confirm step**: The mapping summary card is already styled. Add a subtle animation or larger checkmark icon (64pt) for the "Ready to Go" moment.

### 4.7 Status Panel

- Add a thin accent-colored left border (3pt) to the panel for brand consistency.
- Increase icon size from `.title2` to `.title` for instant readability.
- Make the title text `.headline` (from `.body.semibold`).
- Add subtle shadow to improve contrast against busy desktop backgrounds.
- Consider `.thickMaterial` instead of `.ultraThinMaterial` for better text readability.

### 4.8 Log Viewer

Minimal changes (lowest priority):
- Entry rows: Add subtle alternating row tint for readability (`.listRowBackground`).
- Timestamp column: Slightly wider, using `.caption.monospacedDigit()`.
- Empty state: Replace `ContentUnavailableView` with a more specific illustration or hint.

---

## 5. Pure Visual vs Behavioral Changes

### Pure Visual (no behavior change)

| Change | Files |
|--------|-------|
| Replace `Form/Section` with `ScrollView` + styled cards in all Settings tabs | All *SettingsView files |
| Add `DesignSystem.swift` with shared components and spacing | New file |
| Restyle `ShortcutField` as pill component | `SettingsView.swift` |
| Restyle engine state as hero card | `StatusSettingsView.swift` |
| Increase onboarding icon sizes, add card backgrounds | `OnboardingView.swift` |
| Status panel: thicker material, accent border, larger font | `StatusPanelView.swift` |
| Log viewer: alternating row tint | `LogViewerView.swift` |
| Spacing constants applied everywhere | All view files |

### Changes That Touch Layout But Not Behavior

| Change | Risk | Notes |
|--------|------|-------|
| `Form` → `ScrollView + VStack` in Settings | Medium | `Form` handles keyboard navigation and accessibility automatically. `ScrollView + VStack` doesn't. Must verify Tab key navigation still works. |
| Onboarding step indicator size increase | Low | May need `minWidth` adjustment |
| Status panel material change | Low | May affect readability in edge cases |

### NOT included (behavioral)

- No new controls or interactions
- No setting additions
- No config changes
- No new keyboard shortcuts
- No animation (except possibly a subtle card hover effect, which is still visual-only)

---

## 6. Phase Assignment

### Recommendation: Phase 2.6 (short, focused)

**Why not bundle into Phase 3:**
- Phase 3 adds new gesture recognizers and new settings sections. If we change the visual system at the same time, every new UI element has to hit two moving targets (new content + new style).
- Visual polish is easier to review in isolation — the diff is "same content, different appearance."
- If the visual direction is wrong, we can revert Phase 2.6 without losing Phase 3 features.

**Estimated scope:**
- 1 new file (`DesignSystem.swift`)
- 7 modified view files
- 0 test changes (pure visual, same data flow)
- 0 model/engine changes

**Dependencies:**
- Phase 2.5 complete (done)
- No feature work in progress

---

## 7. Acceptance Criteria

### How to Judge "Better, Not Just Different"

Visual improvement is subjective, but we can test for specific properties:

**Readability test:**
- [ ] Engine state is readable at arm's length from the Status tab (tinted card, not just text)
- [ ] Status panel gesture name is readable in peripheral vision (larger font, higher contrast)
- [ ] Onboarding preset cards are visually distinct when selected vs unselected (not just a faint border change)

**Hierarchy test:**
- [ ] A screenshot of the Feedback tab clearly shows two visual groups (Feedback, System) without reading text
- [ ] The Status tab looks visually distinct from config tabs (darker/console-like event feed)
- [ ] The Advanced tab looks visually less prominent than the Feedback tab (lower visual weight signals "power user")

**Consistency test:**
- [ ] All settings tabs use `SettingsCard` for grouping (not a mix of Form/Section/GroupBox/bare VStack)
- [ ] All spacing between cards uses `Spacing.lg` (16pt)
- [ ] All status indicators (engine, diagnostics, events) use `StatusBadge` component
- [ ] All shortcut displays use the same pill component style

**Regression test:**
- [ ] 153 tests pass (no behavioral changes)
- [ ] All functional acceptance criteria from Phase 2.5 still pass
- [ ] Tab key navigation works in Settings tabs (if using ScrollView instead of Form)
- [ ] VoiceOver can read all controls (no accessibility regression from custom components)

**Subjective test (user validation):**
- [ ] User confirms the Settings window looks more polished than before
- [ ] User confirms the onboarding wizard feels more welcoming
- [ ] User confirms the status panel is more readable

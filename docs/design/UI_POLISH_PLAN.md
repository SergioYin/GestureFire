# UI Polish Plan

> Created: 2026-04-03
> Status: Draft — awaiting review before implementation

## Current State

GestureFire's UI was built feature-first across 4 phases. Each view was created to make the feature work, not to create a unified visual experience. The result is functional but inconsistent — each screen feels like it was built by a different person at a different time.

**Source files reviewed**: `SettingsView.swift`, `GeneralSettingsView.swift`, `GestureMappingView.swift`, `SensitivityView.swift`, `LogViewerView.swift`, `DiagnosticView.swift`, `OnboardingView.swift`, `StatusPanelView.swift`, `MenuBarView.swift`.

---

## 1. Problem Inventory

### 1.1 Settings Window

**Structure problems:**
- 4 tabs (General, Gestures, Sensitivity, Logs) with no obvious hierarchy — it's unclear which tab a new user should visit first
- General tab mixes 3 unrelated concerns: sound feedback, status panel, launch-at-login. These are grouped by "when were they built" not "what do they control"
- Sensitivity tab exposes raw parameter names (`Hold Threshold`, `Movement Tolerance`, `Debounce Cooldown`) that mean nothing to non-technical users
- `directionAngleTolerance` is visible in Sensitivity but has no effect — misleading

**Visual problems:**
- Fixed-width label columns (`frame(width: 120)`, `frame(width: 180)`) create misaligned layouts across tabs
- No section descriptions or help text — each control is a bare label + widget
- Shortcut field uses raw text input (`cmd+left`) with no discoverability. Parse errors show red text but no message explaining what went wrong
- Volume slider shows raw percentage (`73%`) with no preview/test button
- "Reset to Defaults" button has no confirmation dialog

**Missing functionality that affects UX:**
- No search/filter across settings
- No visual feedback when a setting is saved
- No way to test a gesture shortcut from within Settings

### 1.2 Diagnostics Window

**Structure problems:**
- Opened from menu bar as a separate `Window` scene — feels disconnected from Settings
- `GroupBox` nesting creates visual clutter: Engine Status, Layer 1, Pipeline Activity, Layer 2, Controls — 5 sections that are really just "status" and "troubleshooting"
- "Layer 1" / "Layer 2" labels are internal engineering terms, not user concepts
- Pipeline Activity shows raw event types (`frameReceived`, `rejected`) with no grouping or summarization

**Visual problems:**
- Header is just `Text("Diagnostics")` with no icon or context
- Event list uses `opacity(0.7)` for older events — subtle and inconsistent with other views
- Troubleshooting tips are a wall of small text with `-` bullets, not visually scannable
- Executable path is shown as debug info — useful for developers but confusing for users
- `timeAgo()` shows "37s ago" format that's inconsistent with Log Viewer's `style: .time`

### 1.3 Onboarding Wizard

**Structure problems:**
- Step indicator uses small dots + tiny text — hard to see progress at a glance
- Permission step: "Grant Access" button label doesn't explain what happens next (system dialog? settings redirect?)
- Practice step: "Start Practice" → calibration grid appears → "Try: TipTap Up" — information appears sequentially instead of being visible upfront
- Practice step: `CalibrationRow` uses `frame(width: 120)` for gesture names — same fixed-width pattern as Settings, will break with longer gesture names in Phase 3
- Confirm step: summary only shows preset + mappings, not what was verified during Practice
- "Skip" button on Practice step has no explanation of consequences

**Visual problems:**
- Step content area has no consistent padding or max-width — some content is left-aligned, some centered
- `PresetCard` selected state uses `accentColor.opacity(0.15)` which is barely visible in light mode
- Calibration attempt indicators (checkmark/xmark circles) are small and dense
- No animation between steps — feels abrupt
- "Start GestureFire" button on Confirm step doesn't stand out enough as the primary action

### 1.4 Log Viewer

**Structure problems:**
- Toolbar layout (DatePicker + Picker + Refresh + Count) is cramped in narrow Settings window
- Entry list uses array index as identity — animations will glitch on filter changes
- No way to see event details (which app was frontmost, what shortcut was fired, recognition confidence)
- No export functionality (even though `.gesturesample` files exist)
- No visual differentiation between "shortcut fired" and "recognized but unmapped"

**Visual problems:**
- `DatePicker(.field)` style is compact but non-obvious — many users won't recognize it as a date picker
- `ContentUnavailableView` empty states are generic — "No Entries" doesn't suggest what to do
- Entry rows are flat and dense — all entries look the same regardless of type
- No grouping by time period (morning/afternoon) or by gesture type

### 1.5 Status Panel

**Structure problems:**
- Fixed size `280x60` — may clip with longer gesture names or localized strings
- Position hardcoded to top-right, 16px from edge — no user preference for placement
- 3-second dismiss delay is hardcoded — some users may want shorter/longer

**Visual problems:**
- `.ultraThinMaterial` background can be hard to read against busy desktop backgrounds
- No entrance/exit animation (intentional for sound suppression, but visually abrupt)
- Icon + title + subtitle in a single HStack — works for short text but will wrap poorly
- Color semantics (`green`, `blue`, `orange`) are defined per-event but don't match any system-wide color scheme

### 1.6 Menu Bar

**Structure problems:**
- Title string `"GestureFire (Running · 5)"` is long — takes excessive menu bar space on small screens
- Menu items are a flat list with Dividers: state → toggle → retry → event → gesture → count → divider → settings/diagnostics/wizard → divider → quit
- "Last pipeline event" and "Last gesture" and "Gestures: N" are 3 separate items showing overlapping info
- "Setup Wizard..." feels like a debug entry, not something a user would seek

**Visual problems:**
- No icons for menu items (Settings, Diagnostics, Setup Wizard)
- State display uses raw `displayLabel` without context (e.g., "Running" vs "Running — 5 gestures recognized")
- Retry buttons have different labels ("Retry" vs "Retry (after granting permission)") — inconsistent tone

---

## 2. Design Goals

### 2.1 Design Direction: Tool-first, Friendly Second

GestureFire is a **power-user utility** — it lives in the menu bar and remaps trackpad gestures. The target user chose to install it; they don't need hand-holding, but they do need **clarity**.

**Primary axis**: Clear > Clever > Pretty
- Information hierarchy should be immediately obvious
- Controls should be self-explanatory without tooltips
- Status should be glanceable, not interpretive

**Secondary axis**: Compact > Spacious
- Menu bar apps should respect screen real estate
- Settings should fit in a single window without scrolling (on most screens)
- Status panel should be minimal

**Non-goals for this round:**
- Custom themes or dark/light mode specialization
- Animation polish beyond basic transitions
- Accessibility audit (important but separate effort)
- Localization preparation

### 2.2 Priority Order

1. **Settings** — most frequently visited, most disorganized
2. **Menu Bar** — always visible, high information density
3. **Onboarding** — first impression, but only seen once/rarely
4. **Diagnostics** — merge into Settings rather than standalone window
5. **Status Panel** — minimal surface area, already acceptable
6. **Log Viewer** — functional, lowest priority

---

## 3. Specific Changes

### 3.1 Settings Restructure

**Tab reorganization:**

| Current | Proposed | Rationale |
|---------|----------|-----------|
| General | Feedback | Rename: "General" is vague. Group sound + panel as "Feedback" — they're both recognition response channels |
| Gestures | Gestures | Keep — clear and correct |
| Sensitivity | Advanced | Rename: "Sensitivity" is one concept; this tab has 5+ params. "Advanced" signals "you can ignore this" |
| Logs | Logs | Keep |
| _(Diagnostics is separate window)_ | Status | New tab: merge Diagnostics into Settings as a "Status" tab — eliminates a separate window |

**Feedback tab (was General):**
- Section 1: "Recognition Feedback" — sound toggle + volume + panel toggle (group as paired channels)
- Section 2: "System" — launch-at-login (standalone, not mixed with feedback)
- Add "Test Sound" button next to volume slider

**Gestures tab:**
- Add section header explaining the text input format (`"Modifier+Key, e.g. cmd+left"`)
- Show parse error as inline `.help()` text, not just red color
- Add shortcut conflict detection (warn if same shortcut on two gestures)

**Advanced tab (was Sensitivity):**
- Add one-line description per parameter: "How long a finger must be held before tap is recognized"
- Hide `directionAngleTolerance` until it's wired (Phase 3) — don't show non-functional controls
- Group parameters by recognizer when Phase 3 adds more
- Keep "Reset to Defaults" but add confirmation

**Status tab (merged Diagnostics):**
- Simplify to 2 sections: "Engine" (state + toggle) and "Recent Activity" (last 5 events)
- Remove "Layer 1 / Layer 2" terminology — replace with "System Checks" and "Connection Test"
- Move troubleshooting into expandable `DisclosureGroup`
- Remove raw executable path display (move to "About" or debug menu if needed)

### 3.2 Menu Bar Simplification

**Title**: Shorten to state-aware format:
- Running: `"GF · 5"` (count only, "GF" as abbreviation)
- Disabled: `"GF · Off"`
- Error: `"GF ⚠"`
- Or: use SF Symbol only (no text) with badge for count — needs feasibility check with `MenuBarExtra`

**Menu items**: Consolidate redundant info:

```
[Engine status line — icon + "Running · 5 gestures"]
─────────────
Enable / Disable          (single toggle)
─────────────
⚙ Settings...            ⌘,
🔧 Setup Wizard...
─────────────
Quit GestureFire          ⌘Q
```

Remove:
- "Last pipeline event" (diagnostic info, belongs in Status tab)
- "Last: TipTap Up" (redundant with status panel)
- "Gestures: 5" (merged into status line)
- Separate "Diagnostics..." entry (merged into Settings)

### 3.3 Onboarding Improvements

**Step indicator**: Replace dots with numbered pills or a progress bar with step names visible.

**Permission step**:
- Change "Grant Access" to "Open System Settings" (accurate description of what happens)
- Add brief instruction text: "You'll be asked to allow GestureFire in Accessibility settings"

**Practice step**:
- Show all gestures upfront as a grid even before "Start Practice"
- Make "Start Practice" more prominent — `controlSize(.large)` + `.buttonStyle(.borderedProminent)`
- "Skip" → "Skip Practice" with subtitle "You can practice later from the menu bar"

**Confirm step**:
- Add practice results summary (e.g., "3/4 gestures verified, 1 skipped")
- Make "Start GestureFire" button larger and more prominent

### 3.4 Visual Consistency Rules

**Color semantics** (apply everywhere):

| Color | Meaning | Used In |
|-------|---------|---------|
| `.green` | Success / active / verified | Engine running, gesture recognized, calibration pass |
| `.orange` | Warning / needs attention | Permission needed, approval required, sample save error |
| `.red` | Error / failure | Parse error, shortcut failed, engine failed |
| `.blue` | In progress / informational | Engine starting, practice active |
| `.secondary` | Inactive / disabled / hint | Disabled state, help text, timestamps |

These already roughly match `PipelineEvent.SemanticColor` — formalize and apply consistently.

**Layout rules:**
- Stop using fixed `frame(width:)` for labels — use `Grid` with automatic column sizing (macOS 13+) or `LabeledContent`
- Consistent section spacing: 16pt between sections, 8pt between items
- Consistent section style: `Form` with `Section("Title")` in all settings tabs

**Typography:**
- Section headers: `.headline`
- Control labels: `.body`
- Help text / descriptions: `.caption` + `.secondary`
- Monospaced values: `.monospacedDigit()` for numbers, `.monospaced()` for shortcuts

### 3.5 Copy Rewrites

| Location | Current | Proposed | Reason |
|----------|---------|----------|--------|
| Menu bar title | `GestureFire (Running · 5)` | `GF · 5` or symbol-only | Too long for menu bar |
| Sensitivity tab | `Hold Threshold` | `Hold Duration` | "Threshold" is engineering jargon |
| Sensitivity tab | `Movement Tolerance` | `Movement Sensitivity` | Matches user's mental model |
| Sensitivity tab | `Debounce Cooldown` | `Repeat Delay` | "Debounce" is engineering jargon |
| Sensitivity tab | `Tap Max Duration` | `Tap Speed` | Inverted framing — users think "faster/slower" not "max ms" |
| Onboarding | `"Grant Access"` | `"Open System Settings"` | Accurate about what the button does |
| Onboarding | `"Start Practice"` | `"Start Gesture Test"` | "Practice" implies improvement; this is verification |
| Diagnostics | `"Layer 1 — System Checks"` | `"System Checks"` | Remove jargon layer numbering |
| Diagnostics | `"Layer 2 — User Confirmation"` | `"Connection Test"` | User-facing name for the concept |
| Menu bar | `"Setup Wizard..."` | `"Reconfigure Gestures..."` | Users don't look for "wizards" |
| Menu bar | `"Diagnostics..."` | Remove (merge into Settings) | One less entry |
| Status panel | `"No shortcut mapped"` | `"Recognized (no shortcut)"` | Clearer about what happened |
| Status panel | `"Shortcut fired"` | `"Shortcut sent"` | "Fired" sounds aggressive |

### 3.6 Pages to Merge or Split

**Merge:**
- **Diagnostics window → Settings "Status" tab**: Diagnostics is a standalone Window scene that duplicates menu-bar-level info. Merging into Settings reduces window sprawl and puts status next to the controls that affect it.
- **Pipeline Activity section → Status tab "Recent Events"**: Currently in Diagnostics, conceptually part of status.

**No splits needed** — current tab structure is appropriate after the merge.

**Remove Window scene:**
- Delete `Window("Diagnostics", id: "diagnostics")` from `GestureFireApp.body`
- Remove "Diagnostics..." menu bar entry
- Move engine state + system checks + recent events into a new Settings "Status" tab

---

## 4. Phase Assignment

### Option A: Dedicated UI Polish Mini-Phase (2.5)

Insert a focused `Phase 2.5: UI Polish` between Phase 2 and Phase 3.

**Pros:**
- Clean scope boundary — no feature work mixed with visual work
- Can validate UI improvements before expanding gesture vocabulary
- Smaller blast radius if something goes wrong

**Cons:**
- Delays Phase 3 (more gestures)
- Some UI work will be invalidated by Phase 3 (new gesture types change Settings layout)

### Option B: Bundle into Phase 3

Fold UI polish into Phase 3 as a prerequisite track. Do UI cleanup first, then add gestures into the cleaned-up structure.

**Pros:**
- Only touch Settings UI once (polish + new gesture sections)
- Phase 3 gesture UI benefits from clean foundation
- No extra phase overhead

**Cons:**
- Phase 3 scope expands significantly
- Harder to review — mixing structural changes with feature additions

### Recommendation: Option A (Phase 2.5)

Reasons:
1. Phase 3 adds new recognizers and new Settings sections — UI changes made during Phase 3 will be harder to review because behavioral and visual changes are mixed
2. The Diagnostics → Settings merge changes window lifecycle code, which is tricky on macOS and should be validated independently
3. Estimated scope is ~2 sessions of focused work — short enough that the delay is negligible
4. Clean UI gives better testing surface for Phase 3 manual verification

---

## 5. Acceptance Criteria

### Structural

- [ ] Settings window has 5 tabs: Feedback, Gestures, Advanced, Logs, Status
- [ ] Diagnostics is no longer a separate window — merged into Status tab
- [ ] Menu bar dropdown has 5 items or fewer (excluding dividers)
- [ ] Menu bar title is under 10 characters in Running state
- [ ] No fixed-width `frame(width:)` for text labels in any view
- [ ] `directionAngleTolerance` hidden from Advanced tab until wired

### Visual

- [ ] Color semantics table (above) applied consistently — no view uses a color for a conflicting meaning
- [ ] All settings tabs use `Form` + `Section` consistently
- [ ] Typography follows the defined hierarchy (headline/body/caption)
- [ ] Status panel readable against light and dark desktop backgrounds

### Copy

- [ ] All copy rewrites from Section 3.5 applied
- [ ] No engineering jargon visible to users (threshold, debounce, layer, pipeline)
- [ ] Button labels describe what happens next, not internal operations

### Functional

- [ ] All existing 153 tests still pass (no behavioral changes)
- [ ] Settings → Status tab shows same information as old Diagnostics window
- [ ] "Reconfigure Gestures..." opens onboarding wizard (same behavior as old "Setup Wizard...")
- [ ] "Test Sound" button plays current sound at current volume
- [ ] Shortcut parse error shows inline help text

### Regression

- [ ] Sound feedback still works (on/off/volume)
- [ ] Status panel still appears on recognition (non-activating, auto-dismiss)
- [ ] Launch-at-login toggle still works
- [ ] Log viewer still loads, filters, handles corrupt lines
- [ ] Onboarding wizard still completes full 4-step flow

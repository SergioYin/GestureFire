# Phase 2.5: UI Polish

## Goal

Make GestureFire's interface consistent, glanceable, and free of engineering jargon — without adding new product capabilities.

## Scope

### S1: Settings Restructure

- [ ] **Rename and regroup tabs**: General → Feedback, Sensitivity → Advanced. Final order: Feedback, Gestures, Advanced, Logs, Status
- [ ] **Feedback tab**: Group sound toggle + volume + status panel toggle under "Recognition Feedback" section. Separate "System" section for launch-at-login
- [ ] **Advanced tab**: Add one-line description per parameter. Hide `directionAngleTolerance` (inactive, expose in Phase 3). Keep "Reset to Defaults" with confirmation dialog
- [ ] **Gestures tab**: Add format hint text above shortcut fields ("Modifier+Key, e.g. cmd+left"). Show parse error as inline help text instead of only red color
- [ ] **Replace fixed-width labels**: Remove all `frame(width: N)` on text labels. Use `LabeledContent` or `Grid` for alignment

### S2: Diagnostics → Settings Merge

- [ ] **New "Status" tab in Settings**: Contains engine state display + system checks + recent events (last 5) + troubleshooting
- [ ] **Remove standalone Diagnostics window**: Delete `Window("Diagnostics", id: "diagnostics")` scene and "Diagnostics..." menu bar entry
- [ ] **Preserve all diagnostic capabilities**: Engine state toggle, system check results, permission request button, pipeline activity feed, troubleshooting tips — all must be accessible from the Status tab
- [ ] **Simplify terminology**: "Layer 1 / Layer 2" → "System Checks" / "Connection Test". Remove raw executable path from default view
- [ ] **Troubleshooting collapsible**: Wrap troubleshooting tips in `DisclosureGroup` to reduce visual clutter

### S3: Menu Bar Simplification

- [ ] **Shorten menu bar title**: `"GestureFire (Running · 5)"` → `"GF · 5"` (running), `"GF · Off"` (disabled), `"GF ⚠"` (error/needsPermission)
- [ ] **Consolidate menu items**: Merge "last event", "last gesture", "gesture count" into a single status line. Remove "Diagnostics..." entry. Rename "Setup Wizard..." → "Reconfigure Gestures..."
- [ ] **Target**: 5 logical items or fewer (status line, toggle, Settings, Reconfigure, Quit)

### S4: Onboarding Copy & Layout

- [ ] **Step indicator**: Replace dot + text with numbered pills or connected progress bar
- [ ] **Permission step**: "Grant Access" → "Open System Settings". Add brief explanation text
- [ ] **Practice step**: Show gesture grid before "Start Practice". "Skip" → "Skip Practice" with consequence note. "Start Practice" → "Start Gesture Test" with `.borderedProminent`
- [ ] **Confirm step**: Add practice results summary (e.g., "3/4 gestures verified")
- [ ] **Layout**: Consistent centering and max-width across all step content areas

### S5: Visual Consistency

- [ ] **Color semantics**: Apply unified color table — green (success/active), orange (warning), red (error), blue (in-progress), secondary (inactive/hint). No view uses a color for a conflicting meaning
- [ ] **Typography**: Section headers `.headline`, control labels `.body`, help text `.caption` + `.secondary`, monospaced for numbers and shortcuts
- [ ] **Section style**: All settings tabs use `Form` + `Section("Title")` consistently

### S6: Copy Rewrites

- [ ] `Hold Threshold` → `Hold Duration`
- [ ] `Movement Tolerance` → `Movement Sensitivity`
- [ ] `Debounce Cooldown` → `Repeat Delay`
- [ ] `Tap Max Duration` → `Tap Speed`
- [ ] `"No shortcut mapped"` (status panel) → `"Recognized (no shortcut)"`
- [ ] `"Shortcut fired"` (status panel) → `"Shortcut sent"`
- [ ] `"Setup Wizard..."` (menu bar) → `"Reconfigure Gestures..."`

## Out of Scope

- **"Test Sound" button**: New interactive behavior, not structural polish. Defer to Phase 3 or later if needed
- **Shortcut conflict detection**: New validation logic, not UI restructure. Defer to Phase 3 (when more gestures make conflicts more likely)
- **Settings search/filter**: Overengineering for current settings count. Revisit when settings grow in Phase 3+
- **Status panel position preference**: Requires new config field + UI. Defer to Phase 5 (personalization)
- **Status panel enter/exit animation**: Risk of reintroducing system sound issues. Defer
- **Log viewer export**: New feature. Defer to Phase 4 (alongside sample browser)
- **Log viewer time grouping**: Enhancement, not structural fix. Defer
- **Accessibility audit**: Important but orthogonal to visual consistency. Separate effort
- **New gesture types or recognizer changes**: Phase 3
- **Any behavioral change to sound feedback, status panel, log viewer, or launch-at-login**

## Deliverables

| Deliverable | Target | New/Modified |
|-------------|--------|--------------|
| `SettingsView.swift` | `GestureFireApp` | Modified — 5-tab layout, tab rename |
| `FeedbackSettingsView.swift` | `GestureFireApp` | New — replaces `GeneralSettingsView.swift` |
| `AdvancedSettingsView.swift` | `GestureFireApp` | New — replaces `SensitivityView` section in `SettingsView.swift` |
| `StatusSettingsView.swift` | `GestureFireApp` | New — absorbs `DiagnosticView.swift` content |
| `DiagnosticView.swift` | `GestureFireApp` | Deleted — merged into `StatusSettingsView` |
| `GeneralSettingsView.swift` | `GestureFireApp` | Deleted — replaced by `FeedbackSettingsView` |
| `GestureMappingView.swift` | `GestureFireApp` | Modified — format hint, inline error help |
| `MenuBarView.swift` | `GestureFireApp` | Modified — consolidated items, renamed entries |
| `GestureFireApp.swift` | `GestureFireApp` | Modified — remove Diagnostics Window scene, shorten menu bar title |
| `OnboardingView.swift` | `GestureFireApp` | Modified — step indicator, copy, layout |
| `StatusPanelView.swift` | `GestureFireApp` | Modified — copy rewrites only |
| `LogViewerView.swift` | `GestureFireApp` | Not modified this phase (lowest priority, functional as-is) |

## Technical Preconditions

- [x] Phase 2 closed and accepted
- [x] `docs/design/UI_POLISH_PLAN.md` reviewed and approved
- [x] No "tooltip" misuse remaining in project docs (verified)
- [x] All 153 tests pass — baseline for regression checking
- [x] StatusPanelController view-model refactor already landed (no further panel changes needed)

## Carry-Over Items Addressed

| Item | Source | Resolution |
|------|--------|------------|
| SwiftUI view unit tests | Phase 2 REVIEW.md | **Not addressed** — Phase 2.5 is structural refactoring, not test addition. Views change shape this phase; testing the new shape is Phase 3. Target: **Phase 3** |
| LogEntry stable identity (UUID) | Phase 2 REVIEW.md | **Not addressed** — Log viewer is lowest priority and functional as-is. Target: **Phase 3** |
| `directionAngleTolerance` visible but inactive | Phase 1 REVIEW.md | **Partially addressed** — hidden from Advanced tab until wired. Full wiring: **Phase 3** |
| NSPanel sound (if still present) | Phase 2 REVIEW.md | **Verified resolved** by user during Phase 2 close-out |

## Verification Criteria

### Automated
- [ ] `swift build` passes (clean, no warnings beyond existing SMAppService exhaustive switch)
- [ ] 153 tests in 30 suites pass — **zero regression** (no behavioral changes in this phase)
- [ ] No new test files expected (pure view restructuring, no new logic)

### Manual (real device)

**Settings:**
- [ ] Settings window has 5 tabs: Feedback, Gestures, Advanced, Logs, Status
- [ ] Feedback tab shows sound + panel toggles under "Recognition Feedback", launch-at-login under "System"
- [ ] Advanced tab shows parameter descriptions, no `directionAngleTolerance` visible
- [ ] Gestures tab shows format hint, parse error as inline help text
- [ ] No fixed-width `frame(width:)` on any text label — labels align dynamically
- [ ] "Reset to Defaults" in Advanced tab shows confirmation before resetting

**Status tab (merged Diagnostics):**
- [ ] Engine state display with toggle button (same as old Diagnostics)
- [ ] System checks auto-run on tab appear (same as old Diagnostics)
- [ ] Permission request button present when accessibility not granted
- [ ] Recent events feed shows last 5 pipeline events (same data as old Pipeline Activity)
- [ ] Troubleshooting tips in collapsible section
- [ ] No standalone Diagnostics window exists — `openWindow(id: "diagnostics")` removed

**Menu bar:**
- [ ] Title under 10 characters in running state
- [ ] Dropdown has: status line, Enable/Disable, Settings, Reconfigure Gestures, Quit
- [ ] No "Diagnostics..." entry
- [ ] No separate "last event" / "last gesture" / "gesture count" items

**Onboarding:**
- [ ] Step indicator uses numbered pills or progress bar (not plain dots)
- [ ] Permission step button says "Open System Settings"
- [ ] Practice step shows gesture grid before starting
- [ ] "Skip Practice" label with consequence note
- [ ] Confirm step includes practice results summary

**Copy:**
- [ ] All 7 copy rewrites from S6 applied
- [ ] No instances of "threshold", "debounce", "layer", or "pipeline" visible to users

**Visual:**
- [ ] Color semantics consistent across all views (green/orange/red/blue/secondary)
- [ ] All settings tabs use `Form` + `Section` style

**Regression:**
- [ ] Sound on/off/volume still works
- [ ] Status panel still appears, auto-dismisses, doesn't steal focus
- [ ] Launch-at-login toggle still works
- [ ] Log viewer loads, filters, handles corrupt lines
- [ ] Onboarding 4-step flow still completes successfully
- [ ] Menu bar Enable/Disable toggle still controls engine

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Diagnostics merge loses functionality | Med | P0 — can't troubleshoot | Line-by-line audit: every feature in DiagnosticView must appear in StatusSettingsView. Acceptance checklist verifies each |
| Settings window too tall after adding Status tab | Med | P1 — requires scrolling | Keep Status tab content compact. Use DisclosureGroup for troubleshooting. Test at minimum window size |
| Menu bar title too short to be recognizable | Low | P1 — users don't find the app | "GF" is recognizable for returning users. SF Symbol provides visual anchor. Can revert if confusing |
| Fixed-width removal breaks alignment | Med | P2 — visual regression | Test each tab at narrow and wide window sizes. Grid/LabeledContent handles dynamic sizing |
| Onboarding step indicator change breaks layout | Low | P2 — cosmetic | Test at 560x420 minimum size |

## Deferred Items

| Item | Reason Deferred | Target Phase |
|------|----------------|--------------|
| "Test Sound" button | New behavior, not structural polish | Phase 3 |
| Shortcut conflict detection | New validation logic | Phase 3 |
| Status panel position preference | New config field + UI | Phase 5 |
| Status panel enter/exit animation | Risk of reintroducing system sounds | Phase 3 (re-evaluate) |
| Log viewer export | New feature | Phase 4 |
| Log viewer time grouping | Enhancement, not structural | Phase 3+ |
| Accessibility audit | Orthogonal effort | Unphased (standalone) |

## Review / Retrospective

> Fill after implementation, before acceptance.

### Stats

| Metric | Value |
|--------|-------|
| Commits | ... |
| Source files (new/modified) | ... |
| Test files (new/modified) | ... |
| Source LOC delta | ... |
| Test LOC delta | ... |

### Bugs Found

| ID | Severity | Summary | Root Cause |
|----|----------|---------|------------|
| ... | P0/P1/P2 | ... | ... |

### What Went Well

- ...

### What Needs Improvement

- ...

## Next-Phase Carry-Over

Items to hand off to Phase 3. These will appear in Phase 3's "Carry-Over Items Addressed" section.

| Item | Target Phase | Notes |
|------|-------------|-------|
| ... | Phase 3 | ... |

# Phase 2: Experience Polish

## Goal

Make GestureFire comfortable as a daily-driver: audio/visual feedback on gesture recognition, system integration (launch-at-login), and operational visibility (log viewer).

## Scope

- [ ] **Sound feedback**: Play a short sound on gesture recognition. Configurable: enable/disable toggle + volume. Must not block or delay the recognition pipeline.
- [ ] **Status panel**: Floating NSPanel showing last recognized gesture + shortcut fired, auto-dismiss after ~3s. Position: near menu bar or configurable corner.
  - **Trigger policy (Phase 2)**: Only `.recognized` and `.shortcutFired` events trigger the panel. `.rejected`, `.unmapped`, `.frameReceived`, `.shortcutFailed` do NOT trigger — these are diagnostic-level events, not user feedback. This avoids noise during normal usage.
  - Rationale: The panel is positive reinforcement ("your gesture worked"), not a diagnostic console. Diagnostic events belong in the log viewer.
- [ ] **Log viewer**: New tab in SettingsView. Reads FileLogger JSONL, displays today's entries by default, filterable by gesture type. Date picker for history. **Must handle corrupt/malformed JSONL lines gracefully** — skip bad lines, never crash.
- [ ] **Launch-at-login**: Toggle in Settings using `SMAppService`. Persist preference in `GestureFireConfig`.
- [ ] **Menu bar tooltip polish**: Show engine status + gesture count in menu bar tooltip. Improve status display in menu dropdown.
- [ ] **Sample save failure feedback**: Surface `SampleRecorder.finishRecording()` errors in onboarding Practice step as an inline error message, instead of only writing to logger. User must see that a sample failed to save.

## Out of Scope

- New gesture types (Phase 3)
- Auto-parameter tuning / true calibration (Phase 4)
- Per-app profiles / import-export (Phase 5)
- Sample browser / sample management UI (re-deferred, see Carry-Over Items)
- Gesture animation previews (re-deferred)
- `directionAngleTolerance` wiring (Phase 3)
- `fingerProximityThreshold` parameter splitting (Phase 3, only if needed)

## Deliverables

| Deliverable | Target | New/Modified |
|-------------|--------|--------------|
| `SoundFeedback.swift` | `GestureFireEngine` | New — `NSSound` playback, enable/disable, volume |
| `StatusPanelController.swift` | `GestureFireApp` | New — NSPanel lifecycle, auto-dismiss |
| `StatusPanelView.swift` | `GestureFireApp` | New — SwiftUI content for status panel |
| `LogViewerView.swift` | `GestureFireApp` | New — JSONL reader, filter, date picker |
| `LaunchAtLoginManager.swift` | `GestureFireEngine` | New — `SMAppService` wrapper |
| `AppCoordinator.swift` | `GestureFireEngine` | Modified — wire sound feedback + status panel events |
| `SettingsView.swift` | `GestureFireApp` | Modified — add Log Viewer tab + launch-at-login toggle |
| `MenuBarView.swift` | `GestureFireApp` | Modified — tooltip, status polish |
| `GestureFireConfig.swift` | `GestureFireTypes` | Modified — add `soundEnabled`, `soundVolume`, `launchAtLogin` fields |
| `FileLogger.swift` | `GestureFireEngine` | Modified — expose `readEntries(for:)` if not already public, per-line corrupt JSONL resilience |
| `OnboardingView.swift` | `GestureFireApp` | Modified — inline error message when sample save fails |
| `OnboardingCoordinator.swift` | `GestureFireEngine` | Modified — propagate sample save errors to observable state |

## Technical Preconditions

- [x] Phase 1.5 closed and accepted
- [x] Carry-over items reviewed (see below)
- [x] `FileLogger` already supports JSONL write + `readToday()` + `readEntries(for:)` — log viewer reads existing data
- [x] `PipelineEvent` has `.shortcutFired` case with `.displayDescription`, `.color`, `.systemImage` — status panel can consume directly
- [x] `AppCoordinator` exposes `lastPipelineEvent`, `lastGesture`, `gestureCount` as `@Observable` properties
- [x] `OnboardingWindowController` uses `NSWindow` with `.regular` activation policy — proven pattern for status panel research

## Carry-Over Items Addressed

| Item | Source | Resolution |
|------|--------|------------|
| Sample save failure not surfaced to user | Phase 1.5 REVIEW.md | Implementing: inline error message in Practice step |
| Sample library management UI | Phase 1.5 REVIEW.md | **Re-deferred to Phase 4**: Phase 2 focus is feedback/polish, not asset management. Phase 4 needs sample browser for calibration workflow anyway — better to build it there alongside replay-based tuning. |
| Gesture animation previews | Phase 1.5 REVIEW.md | **Re-deferred to Phase 3**: Previews become more valuable when there are more gesture types to demonstrate. |
| `directionAngleTolerance` not wired | Phase 1 REVIEW.md | **Remains Phase 3**: No change — Phase 2 doesn't touch recognizer logic. |
| `fingerProximityThreshold` dual-purpose | Phase 1.5 REVIEW.md | **Remains Phase 3**: Documentation-only in Phase 1.5. Split only when Phase 3 adds multi-finger gestures. |
| Swift Testing requires Xcode toolchain | Phase 1.5 REVIEW.md | **Resolved**: `scripts/test.sh` exists and handles toolchain switching. No further action needed — document as engineering convention. |
| FileLogger not thread-safe (M1) | Phase 1 REVIEW.md | **Evaluate in Phase 2**: FileLogger gets more usage (log viewer reads). If still @MainActor-only, safe. If accessed from background, needs actor conversion. |
| Settings save feedback | Phase 1 REVIEW.md | **Opportunistic**: If touching SettingsView for log viewer tab, consider adding brief save confirmation. Not a hard requirement. |

## Verification Criteria

### Automated
- [ ] `swift build` passes
- [ ] `scripts/test.sh` passes (toolchain: Xcode 16.x)
- [ ] New tests: `SoundFeedback` (enable/disable/volume state management, fire-and-forget contract)
- [ ] New tests: `LaunchAtLoginManager` (status query, error branch handling — NOT persistence as main focus)
- [ ] New tests: JSONL parsing — normal lines, empty lines, corrupt/malformed lines, empty file, mixed valid+invalid
- [ ] New tests: Log entry filtering by gesture type
- [ ] New tests: `OnboardingCoordinator` sample save failure → error state propagation
- [ ] Existing 135+ tests still pass (no regression)

### Manual (real device)
- [ ] Perform TipTap gesture → hear sound (if enabled) + see status panel appear
- [ ] Disable sound in Settings → perform gesture → no sound, status panel still shows
- [ ] Status panel: only appears on successful recognition (`.recognized` / `.shortcutFired`), NOT on rejected/unmapped gestures
- [ ] Status panel: does NOT steal focus from current app, does NOT block typing
- [ ] Status panel: auto-dismisses after ~3s
- [ ] Open Settings → Logs tab → see today's entries, filter by gesture type, pick a past date
- [ ] Log viewer: manually corrupt a line in a `.jsonl` file → log viewer still loads, skips bad line, does not crash
- [ ] Toggle launch-at-login in Settings → log out and log in → GestureFire auto-starts (or doesn't, based on toggle)
- [ ] Menu bar tooltip shows engine state + count
- [ ] During onboarding Practice: make `~/.config/gesturefire/samples/` read-only → perform gesture → user sees inline error message in wizard that sample save failed

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Status panel steals focus or blocks input | High | P0 — unusable for daily driving | Research `NSPanel` + `.nonActivating` + `.utilityWindow` behavior BEFORE building content. Phase 1.5 lesson: test window lifecycle first. |
| Status panel hidden by activation policy | Med | P1 — invisible feedback | Already using `.regular` policy. But panel should be `.floating` level — test with multi-app workflows. |
| `NSSound` playback latency | Low | P1 — delayed feedback feels wrong | `NSSound` is synchronous on main thread. Use `DispatchQueue` or pre-load sound. Measure latency. |
| Sound blocks recognition pipeline | Med | P0 — defeats purpose | Sound must be fire-and-forget, never awaited in the recognition hot path. |
| `SMAppService` registration fails silently | Med | P1 — user thinks it's enabled but it's not | Check `SMAppService.mainApp.status` after register, surface errors. |
| Log viewer slow with large JSONL files | Low | P2 — settings lag | Lazy loading, limit to last N entries, paginate if needed. 30-day retention keeps files manageable. |
| FileLogger corrupt lines crash JSON decoder | Med | P1 — log viewer broken | Per-line try/catch parsing. Skip corrupt lines, don't crash. |

## Deferred Items

> Pre-populated with known items. Will grow during implementation.

| Item | Reason Deferred | Target Phase |
|------|----------------|--------------|
| Sample browser / management UI | Better fit alongside calibration workflow | Phase 4 |
| Gesture animation previews | More valuable with expanded gesture vocabulary | Phase 3 |
| `directionAngleTolerance` wiring | Phase 2 doesn't touch recognizer logic | Phase 3 |
| `fingerProximityThreshold` splitting | Only needed when multi-finger gestures land | Phase 3 |

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

| Item | Target Phase | Notes |
|------|-------------|-------|
| ... | Phase 3 | ... |

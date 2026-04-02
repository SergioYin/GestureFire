# Phase 1 Review — Core Loop Hardening

## Scope

Phase 1 delivered the minimum viable gesture recognition pipeline: TipTap 4-direction recognition, keyboard shortcut firing, permission management, diagnostics, and menu bar UI.

## Stats

| Metric | Value |
|--------|-------|
| Commits | 10 (8 planned steps + 2 hardening fixes) |
| Source files | 28 (.swift) |
| Test files | 13 (.swift) |
| Source LOC | ~2,257 |
| Test LOC | ~1,310 |
| Test coverage | 82 tests across 19 suites, all passing |
| SPM targets | 7 libraries + 1 executable + 5 test targets |

## Architecture Decisions Validated

1. **Struct recognizer + explicit state machine**: `TipTapRecognizer` as a value type with `enum State { idle, tracking, cooldown }` made state transitions testable and deterministic. The critical lift detection bug (fingers transitioning `.touching` -> `.breaking` being lost) was caught and fixed precisely because the state machine made the logic auditable.

2. **TouchFrame abstraction**: Isolating OMS dependency to `GestureFireIntegration` paid off immediately — all 82 tests run without touching the private framework. Recognition tests use pure `TouchFrame` fixtures.

3. **Single-owner actor model**: `RecognitionLoop` actor owns all recognizer structs. No shared mutable state, no data races. Swift 6 strict concurrency passed cleanly.

4. **`@Observable` macro over `Observable` protocol**: The protocol version silently broke SwiftUI reactivity (pipeline events wouldn't update in real-time). Switching to `@Observable` + `@ObservationIgnored` for internal properties fixed it.

5. **`TouchFrame.timestamp` as sole time authority**: All recognizer timing uses frame timestamps, never `Date()`. This will enable deterministic sample replay in Phase 1.5.

## Bugs Found and Fixed During Hardening

### P0: TipTap recognizer never firing (critical)

**Root cause**: Lift detection used all frame point IDs (including `.breaking`/`.leaving` states) to determine which fingers were still present. A finger transitioning `.touching` -> `.breaking` still appeared in the frame, so it was never detected as "lifted" — but it was also removed from the active tracking dict. The finger fell into a detection gap.

**Fix**: Build `updatedFingers` (active `.touching`/`.making` only) first, then detect lift as `fingers[id] present but updatedFingers[id] absent`. This catches the transition immediately.

**Lesson**: Touch state machines have more states than "touching" and "not touching". The OMS framework reports transitional states (`.breaking`, `.lingering`, `.leaving`) that must be handled explicitly.

### P0: Permission dialog spam

**Root cause**: `DiagnosticRunner.runAll()` called `requestAccessibility()` (which triggers `AXIsProcessTrustedWithOptions(prompt: true)`) on every 2-second poll cycle. The system showed a new dialog each time.

**Fix**: Strict separation — `DiagnosticChecking` protocol only has `checkAccessibility()` (read-only `AXIsProcessTrusted()`). The prompt function `requestAccessibilityPrompt()` is a standalone free function, only callable from explicit user button taps.

**Lesson**: macOS accessibility APIs have a critical distinction between checking and requesting. Polling must always be read-only.

### P1: Contradictory state display

**Root cause**: `hasReceivedFrame` flag lived on `OMSTouchSource` instance, which was destroyed on stop/restart. But old `PipelineEvent` records persisted in the coordinator, showing "frames received" while the fresh source reported "no frames yet".

**Fix**: Added coordinator-level `hasEverReceivedFrame` that survives stop/restart. Clear stale pipeline events in `beginListening()`.

### P1: Pipeline not updating in real-time

**Root cause**: `AppCoordinator` declared `Observable` (the protocol) instead of using `@Observable` (the macro). The protocol requires manual `objectWillChange` calls; the macro auto-tracks property access. SwiftUI views never got notified.

**Fix**: Switch to `@Observable` macro + `@ObservationIgnored` for internal-only properties.

## What Went Well

- **TDD discipline held**: All 9 implementation steps followed red-green-refactor. The 82 tests caught real bugs during hardening.
- **Multi-target SPM isolation**: Each target has a clear responsibility boundary. OMS coupling is confined to one target.
- **Struct + actor concurrency model**: Zero data race issues under Swift 6 strict checking.
- **Diagnostic two-layer design**: Layer 1 (automated checks) + Layer 2 (user confirmation) cleanly separates what machines can verify from what needs human judgment.

## Code Review — Post-Hardening

Automated code review found 0 critical, 4 high, 6 medium, 5 low issues.

### HIGH issues (all fixed)

| # | Issue | Fix |
|---|-------|-----|
| H1 | `OMSTouchSource` used `@unchecked Sendable` with unsynchronized mutable state | Converted to `actor` — actor isolation protects `task` and `hasReceivedFrame` |
| H2 | Silent `try?` on `persistence.save()` in `ConfigStore.update` | Added `do/catch` with `Logger.config.error` |
| H3 | Silent `try?` on `fileLogger.log()` in `AppCoordinator.handleFrame` | Added `do/catch` with `Logger.engine.warning` |
| H4 | `TipTapRecognizer.processFrame` recursed into itself on cooldown expiry | Inlined idle-state logic to avoid recursive `mutating func` re-entry |

### MEDIUM issues (deferred to Phase 1.5)

- M1: `FileLogger` not thread-safe (safe today under `@MainActor`, latent risk)
- M2: `FileLogger.log` force-unwraps String/Data conversion
- M3: `DiagnosticView` polling task lifecycle could use `.task(id:)`
- M4: Unnecessary `reloadSensitivity()` call on gesture mapping change — **fixed** (removed)
- M5: Magic numbers `0.5s`/`1.0s` in TipTapRecognizer — **fixed** (now reads `tapGroupingWindowMs` from config)
- M6: Dead `Key.Codable` conformance in `KeyShortcut`

### LOW issues (deferred)

- L1: `hasTouchFrames` alias duplicates `hasEverReceivedFrame`
- L2: `DiagnosticView` checks diagnostic names by string literal
- L3: Logger instances implicitly `internal`
- L4: `SensitivityConfig` doesn't clamp parameter ranges on init
- L5: `startingTimeoutTask` uses `try?` on `Task.sleep` hiding cancellation

## What Needs Improvement

- **macOS permission UX**: Binary path + code signature changes on rebuild invalidate old accessibility permissions. Users must delete the old entry in System Settings. This is an OS limitation, not fixable in code, but needs better user guidance.
- **Pipeline event flooding**: Initial implementation logged every frame. Fixed with deduplication (only log on finger count change), but more sophisticated filtering may be needed for Phase 2.
- **No sample recording yet**: All testing is with constructed fixtures. Phase 1.5 sample recording/replay will close this gap.
- **Settings save feedback**: No visual confirmation when a shortcut is saved successfully (only error on parse failure). Could add a brief success indicator.
- **`directionAngleTolerance` not wired**: The parameter exists in `SensitivityConfig`, is exposed in Settings UI, and persists to config — but `TipTapRecognizer.computeDirection()` still uses a simple `abs(dx) > abs(dy)` check without applying the tolerance angle. Do not treat this as an active tunable parameter until the recognizer reads it. Carry-over to Phase 3 (when direction logic may need refinement for new gesture types).

## Phase 1.5 Readiness

Phase 1 provides a solid foundation for Phase 1.5 (onboarding + calibration + sample library):
- `TouchFrame` abstraction ready for recording/replay
- Frame timestamp authority ensures replay determinism
- `SensitivityConfig` has all 10 parameters with defaults
- `RecognitionLoop` actor can be fed frames from either live OMS or recorded samples
- Diagnostic infrastructure ready for onboarding permission flow

---

# Phase 1.5 Review — Onboarding + Calibration + Sample Library

## Scope

Phase 1.5 delivered the first-run onboarding wizard, sample recording pipeline, sample replay infrastructure, and calibration flow with gesture verification.

## Stats

| Metric | Value |
|--------|-------|
| Commits | 4 (foundation + samples + coordinator + UI) + pending fixes |
| Source files | 34 (.swift) |
| Test files | 21 (.swift) |
| Source LOC | ~3,600 |
| Test LOC | ~2,250 |
| New types | `OnboardingCoordinator`, `SampleRecorder`, `SamplePlayer`, `GesturePreset`, `GestureSample`, `OnboardingWindowController` |

## Naming Clarification: "Calibration" vs "Practice"

The onboarding step labeled "Practice" (and internally named `startCalibration` / `isCalibrating`) is **not** true calibration in the signal-processing sense. What it actually does:

- **Real-time gesture verification**: user performs gestures, recognizer validates against current sensitivity defaults
- **Sample capture**: successful attempts are recorded as `.gesturesample` files for future use

What it does **not** do:

- Analyze captured samples to compute better sensitivity parameters
- Compare multiple samples to find optimal thresholds
- Auto-tune any `SensitivityConfig` values

**True calibration** — using captured samples + replay to optimize parameters — belongs to **Phase 4 (Smart Tuning)**. The current "practice" step produces the raw material (samples) that Phase 4 will consume.

## What Was Delivered

### Onboarding Wizard (4 steps)
1. **Permission**: Accessibility permission request → polling → auto-detect grant → "Try Again" recovery from denial (30s timeout)
2. **Preset**: Card-based selection from 3 presets (Browser, IDE, Window Manager) with mapping preview
3. **Practice**: Real-time gesture verification + sample recording (3 attempts per gesture, correct/wrong validation, shortcut suppression)
4. **Confirm**: Summary of selected preset + practice results → "Start GestureFire" button

### Window Management (macOS-specific complexity)
- `OnboardingWindowController` using `NSWindow` (not NSPanel — panels auto-minimize on focus loss)
- Auto-open on first launch via `AppDelegate.applicationDidFinishLaunching`
- Reopenable from Menu Bar via `showDeferred()` (200ms delay for menu dismiss animation)
- `applicationDidBecomeActive` brings wizard to front after System Settings steals focus
- `NSApp.setActivationPolicy(.regular)` permanently — agent apps hide windows on deactivation

### Sample Recording Pipeline
- `SampleRecorder`: records `TouchFrame` sequences during calibration, saves as `.gesturesample` JSON
- Wired into calibration lifecycle: `startRecording(for:)` at gesture start, `finishRecording()` on success, `cancelRecording()` on failure/skip
- Files saved to `~/.config/gesturefire/samples/` with UUID suffix for uniqueness
- `SamplePlayer` + `RecognitionLoop.replay()` for deterministic playback

### Engine Safety During Calibration
- `isCalibrating` check suppresses `KeyboardSimulator.fire()` during practice (prevents Cmd+W closing windows)
- `.running`/`.starting` guard prevents duplicate `OMSTouchSource` creation on repeated `start()` calls
- `gestureCount` watcher (not `lastGesture`) enables detecting consecutive same-gesture recognition

### Returning User UX
- `beginOnboarding()` loads existing config: matches known presets or creates ad-hoc "Custom" preset
- Skips permission step if `AXIsProcessTrusted()` already granted

## Bugs Found and Fixed

### P0: Setup Wizard window lifecycle (5 iterations)

The most complex issue in Phase 1.5. Menu-bar-only macOS apps have severe window management limitations.

| Attempt | Approach | Failure |
|---------|----------|---------|
| 1 | SwiftUI `Window` scene | Never opens — SwiftUI doesn't auto-present Window scenes in menu-bar apps |
| 2 | `NSApp.delegate as? AppDelegate` | Cast returns nil — SwiftUI wraps the delegate adapter |
| 3 | `DispatchQueue.main.asyncAfter` | Closure not `@MainActor`-isolated in Swift 6 |
| 4 | `NSPanel` + agent activation policy | Panel auto-minimizes when app loses focus |
| 5 | `NSWindow` + `.regular` activation policy + `applicationDidBecomeActive` | Works |

**Lesson**: macOS menu-bar apps need imperative window management (`NSWindow`), not declarative SwiftUI `Window` scenes. Agent apps (`.accessory` activation policy) cannot reliably keep windows visible.

### P0: Shortcuts firing during practice
Cmd+W / Cmd+T during calibration closed windows. Fixed by checking `isCalibrating` before `KeyboardSimulator.fire()`.

### P0: Duplicate engine start
`startCalibration()` → `startEngine()` → `start()` on already-running engine created duplicate `OMSTouchSource`. Fixed by adding state guard.

### P1: Same gesture not detected consecutively
`.onChange(of: appCoordinator.lastGesture)` doesn't fire when the same gesture is recognized twice. Fixed by watching `gestureCount` instead.

### P1: Wrong gesture accepted as calibration success
`recordCalibrationAttempt` didn't validate gesture type. Replaced with `handleRecognizedGesture(_:)` that checks `gesture == currentCalibrationGesture`.

### P1: Permission stuck in "Waiting" after denial
Polling never reset state. Fixed with 30s timeout + `resetPermissionState()` + "Try Again" button.

## Known Issues and Carry-Over Items

### Two-finger swipe misrecognized as TipTap — FIXED (6214b59)
Added `fingerProximityThreshold` distance check in `TipTapRecognizer`. Two-finger swipe fingers (distance < 0.05) now rejected; real TipTaps (distance > 0.2) unaffected.

### `fingerProximityThreshold` semantic note
This parameter (default 0.15) is now **dual-purpose**:
- **Original intent** (Phase 3): minimum distance between fingers in multi-finger gestures
- **Current use** (Phase 1.5): anti-swipe filter in TipTap recognition

If these two use cases ever need different thresholds, split into separate parameters (e.g. `tipTapMinFingerDistance` + `multiFingerProximityThreshold`). For now, 0.15 works well for both.

### `directionAngleTolerance` NOT wired into recognizer
**Carried from Phase 1. Still inactive.** The parameter exists in `SensitivityConfig`, is exposed in Settings UI, and persists to config — but `TipTapRecognizer.computeDirection()` uses a simple `abs(dx) > abs(dy)` check without applying it. **Do not treat as a tunable parameter** — changing its value has no effect. Target: **Phase 3** (when direction logic needs refinement for swipe gestures and diagonal handling).

### Sample save failure not surfaced to user
`SampleRecorder.finishRecording()` failures are logged (`Logger.warning`) but not shown in UI. The user sees the sample count but has no way to know if a specific save failed. Target: **Phase 2** (UX polish).

### Sample library management not implemented
`.gesturesample` files accumulate in `~/.config/gesturefire/samples/` but there is no UI to:
- Browse existing samples
- Delete bad/unwanted samples
- Export samples for bug reports or regression testing
- View sample metadata (gesture type, timestamp, frame count)

Target: **Phase 2** (sample browser UI) and **Phase 4** (regression testing with sample replay).

### Gesture animation previews not implemented
Planned in Phase 1.5 spec but deprioritized. Text instructions sufficient for now. Target: **Phase 2**.

### Auto sensitivity calculation not implemented
Practice step captures samples but does not analyze them to compute optimal parameters. True sample-based calibration (replay + parameter search) belongs to **Phase 4 (Smart Tuning)**.

### Swift Testing requires Xcode toolchain
`swift test` fails with `no such module 'Testing'` when using Swift 6.3 CLI-only toolchain (CommandLineTools). Tests require Xcode's bundled Swift Testing framework. See `scripts/test.sh` for the recommended test command. Not a code issue.

## What Went Well

- **Iterative window management**: Despite 5 iterations, each step taught something about macOS window behavior. Final solution is robust.
- **Sample recording pipeline**: Clean integration — recorder wired into calibration lifecycle without leaking into recognition logic.
- **Returning user flow**: Config-based preset matching makes re-running the wizard seamless.
- **Shortcut suppression**: Clean separation of calibration vs production mode.

## What Needs Improvement

- **Build/test discipline**: Mid-phase, changes accumulated without building or testing. Must always verify after every significant change.
- **macOS window management expertise**: Too much trial-and-error. Should research NSWindow/NSPanel/activation policy behavior upfront before coding.
- **Test environment**: Need Xcode installed or a workaround for Swift Testing in CLI-only environments.

---

# Phase 2 Review — Experience Polish

## Scope

Phase 2 delivered daily-driver comfort: sound feedback, floating status panel, log viewer, launch-at-login, and sample save error visibility.

## Stats

| Metric | Value |
|--------|-------|
| Commits | 6 (spec + 4 features + hardening) |
| Source files | 40 (.swift), +6 new |
| Test files | 24 (.swift), +3 new |
| Source LOC | ~4,163 (+563) |
| Test LOC | ~2,549 (+299) |
| New types | `SoundFeedback`, `StatusPanelController`, `StatusPanelView`, `LogViewerView`, `LogEntryRow`, `GeneralSettingsView`, `LaunchAtLoginManager`, `PipelineEvent.SemanticColor` |
| Tests | 153 in 30 suites (was 135 in 27) |

## What Was Delivered

### Sound Feedback
- `SoundFeedback`: fire-and-forget `NSSound` playback with pre-loaded "Tink" sound
- Configurable: `soundEnabled` toggle + `soundVolume` slider (0–100%)
- Wired into `AppCoordinator.handleFrame`: plays on `.shortcutFired` and unmapped `.recognized` events
- Suppressed during calibration

### Status Panel
- `StatusPanelController`: non-activating `NSPanel` with `.floating` level
- Does not steal focus, does not block typing
- Auto-dismisses after 3 seconds (cancellable)
- Trigger policy: only `.recognized` and `.shortcutFired` events (no noise from rejections)
- Suppressed during calibration

### Log Viewer
- `LogViewerView`: new "Logs" tab in Settings
- Reads FileLogger JSONL with date picker and gesture type filter
- Reverse-chronological display with entry count
- Corrupt JSONL lines silently skipped (existing `compactMap`/`try?` in `FileLogger.readEntries`)
- Async loading via `Task` (spinner renders during I/O)

### Launch-at-Login
- `LaunchAtLoginManager`: `SMAppService.mainApp` wrapper
- Status query, enable/disable with error reporting
- `requiresApproval` state shown as guidance text
- Toggle in General settings tab

### General Settings Tab
- New first tab in Settings: sound toggle/volume, status panel toggle, launch-at-login toggle
- All settings persist via `GestureFireConfig` (backward-compatible `decodeIfPresent`)

### Menu Bar Polish
- Menu bar title shows engine state + gesture count
- Existing pipeline event / gesture count display unchanged

### Sample Save Failure Feedback
- `OnboardingCoordinator.lastSampleSaveError`: observable error state
- Inline warning label in Practice step when sample save fails
- Cleared on next successful save

## Bugs Found and Fixed

### H1: StatusPanelController dismiss task cancel race (code review)
`try?` on `Task.sleep` swallowed `CancellationError`, allowing stale `hide()` calls. Fixed: `try/catch` with cancellation handling + `[weak self]`.

### H2: GeneralSettingsView instantiated LaunchAtLoginManager on every render (code review)
`SMAppService.mainApp.status` called on every SwiftUI body evaluation. Fixed: cached instance + `.onAppear` for status load.

### H3: StatusPanelView stringly-typed color switch (code review)
`PipelineEvent.color` returned `String`, risking silent fallback on new cases. Fixed: typed `SemanticColor` enum with exhaustive switch.

### H4: Status panel shown during calibration (code review)
`.recognized` events during calibration triggered status panel with misleading "No shortcut mapped" subtitle. Fixed: suppress `onStatusEvent` and `soundFeedback.play()` during calibration.

### M1: LogViewerView synchronous file I/O on main thread (code review)
`isLoading` was set and cleared synchronously — spinner never rendered. Fixed: wrapped in `Task`.

## Known Issues and Carry-Over Items

### `FileLogger` is a `Sendable` struct with non-atomic write path
**Status**: Currently safe because `log()` is only called from `@MainActor`. If `FileLogger` is ever used from background tasks, it needs actor isolation or a serial queue.
**Target**: Phase 3 (if FileLogger usage expands) or Phase 4 (smart tuning may log from background)

### `AppCoordinator.stop()` fire-and-forget Task for source.stop()
**Status**: The unstructured `Task { await source.stop() }` can outlive the coordinator. If `start()` is called immediately after `stop()`, two sources may coexist briefly. Mitigated by `.running`/`.starting` guard, but not fully safe.
**Target**: Phase 3 (when multiple recognizer sources may amplify the issue)

### `GestureFireConfig.version` field is inert
**Status**: Decoded but never used for migration logic. All new fields use `decodeIfPresent` with defaults, so backward compatibility is maintained without migrations. The field exists as a reserved hook.
**Target**: Phase 4 or Phase 5 (when schema changes may require migration)

### `FileLogger.log()` force-unwrap on String encoding
**Status**: `String(data: data, encoding: .utf8)!` — safe because JSONEncoder always produces valid UTF-8, but violates Swift convention against force-unwraps in production code.
**Target**: Phase 3 (low priority)

### Sample browser / management UI
**Status**: Re-deferred from Phase 1.5. `.gesturesample` files accumulate without management UI.
**Target**: Phase 4 (alongside calibration workflow)

### Gesture animation previews
**Status**: Re-deferred from Phase 1.5.
**Target**: Phase 3 (more valuable with expanded gesture vocabulary)

### `directionAngleTolerance` NOT wired
**Status**: Unchanged from Phase 1. Parameter exists in UI but has no effect.
**Target**: Phase 3

## What Went Well

- **Risk-first approach**: StatusPanelController's NSPanel prototype worked on first attempt thanks to `.nonactivatingPanel` + `.floating` — Phase 1.5 lessons on window lifecycle paid off.
- **Build discipline**: `swift build` after every change, no accumulated breakage.
- **Code review caught real issues**: 4 HIGH findings, all fixed before shipping. SemanticColor enum prevents future string-matching regressions.
- **Backward-compatible config**: `decodeIfPresent` with defaults means existing config files load without migration.

## What Needs Improvement

- **Test coverage for UI components**: `StatusPanelView`, `LogViewerView`, `GeneralSettingsView` have no unit tests (SwiftUI views are hard to test without ViewInspector or similar). Consider snapshot testing in Phase 3.
- **LogEntry lacks stable identity**: Uses array index as List key — fragile for animations. Should add UUID field.
- **`InMemoryPersistence.Storage` uses `@unchecked Sendable`** in tests — should be converted to `@MainActor`-constrained class.

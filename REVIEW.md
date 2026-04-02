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

## What Was Delivered

### Onboarding Wizard (4 steps)
1. **Permission**: Accessibility permission request → polling → auto-detect grant → "Try Again" recovery from denial (30s timeout)
2. **Preset**: Card-based selection from 3 presets (Browser, IDE, Window Manager) with mapping preview
3. **Practice**: Calibration with 3 attempts per gesture, correct/wrong validation, shortcut suppression, sample recording per attempt
4. **Confirm**: Summary of selected preset + calibration results → "Start GestureFire" button

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

## Known Issues

### Two-finger swipe misrecognized as TipTap
**Status**: Solution designed, not yet implemented.
**Root cause**: `TipTapRecognizer` doesn't check distance between hold and tap positions. Two-finger swipe with sequential lift triggers false TipTap.
**Fix**: Add `fingerProximityThreshold` distance check (1 line + tests). Parameter already exists in `SensitivityConfig`.

### `directionAngleTolerance` not wired
Carried over from Phase 1. `computeDirection()` uses simple `abs(dx) > abs(dy)` without angle tolerance. Deferred to Phase 3.

### Gesture animation previews not implemented
Planned in Phase 1.5 spec but deprioritized. Not required for usability — text instructions sufficient.

### Auto sensitivity calculation not implemented
Calibration validates gestures but doesn't auto-compute optimal sensitivity parameters. Deferred to Phase 4 (smart tuning).

### Swift Testing unavailable in CLI toolchain
`swift test` fails with `no such module 'Testing'` on Swift 6.3 CLI-only toolchain (no Xcode). Tests require Xcode's Swift Testing framework. Pre-existing environment issue, not a code problem.

## What Went Well

- **Iterative window management**: Despite 5 iterations, each step taught something about macOS window behavior. Final solution is robust.
- **Sample recording pipeline**: Clean integration — recorder wired into calibration lifecycle without leaking into recognition logic.
- **Returning user flow**: Config-based preset matching makes re-running the wizard seamless.
- **Shortcut suppression**: Clean separation of calibration vs production mode.

## What Needs Improvement

- **Build/test discipline**: Mid-phase, changes accumulated without building or testing. Must always verify after every significant change.
- **macOS window management expertise**: Too much trial-and-error. Should research NSWindow/NSPanel/activation policy behavior upfront before coding.
- **Test environment**: Need Xcode installed or a workaround for Swift Testing in CLI-only environments.

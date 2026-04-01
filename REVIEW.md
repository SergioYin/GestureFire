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
- M5: Magic numbers `0.5s`/`1.0s` in TipTapRecognizer should be named constants or config params
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

## Phase 1.5 Readiness

Phase 1 provides a solid foundation for Phase 1.5 (onboarding + calibration + sample library):
- `TouchFrame` abstraction ready for recording/replay
- Frame timestamp authority ensures replay determinism
- `SensitivityConfig` has all 10 parameters with defaults
- `RecognitionLoop` actor can be fed frames from either live OMS or recorded samples
- Diagnostic infrastructure ready for onboarding permission flow

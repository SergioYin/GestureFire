# Architecture Overview

## Module Dependency Graph

```
GestureFireApp (executable)
    └── GestureFireEngine
            ├── GestureFireRecognition
            │       └── GestureFireTypes
            ├── GestureFireIntegration
            │       ├── GestureFireTypes
            │       └── OpenMultitouchSupport (external)
            ├── GestureFireShortcuts
            │       └── GestureFireTypes
            └── GestureFireConfig
                    └── GestureFireTypes
```

**GestureFireTypes** is the leaf — pure value types, zero dependencies.
**OpenMultitouchSupport** is the only external dependency, isolated to GestureFireIntegration.

## Data Flow

```
Trackpad → OMS → OMSTouchSource (actor)
                      │
                      ▼
               TouchFrame (value type)
                      │
                      ▼
            AppCoordinator (@MainActor)
                      │
                      ▼
           RecognitionLoop (actor)
              │  (priority-ordered recognizer array,
              │   highest-first, first-to-recognize wins)
              ├── CornerTapRecognizer         (struct)
              ├── MultiFingerTapRecognizer    (struct)
              ├── MultiFingerSwipeRecognizer  (struct)
              └── TipTapRecognizer            (struct)
                      │
                      ▼
           RecognitionResult (value type)
                      │
              ┌───────┴────────┐
              ▼                ▼
        .recognized       .rejected / .empty
              │
              ├──► OnboardingCoordinator (if calibrating)
              │        └── SampleRecorder → .gesturesample files
              │
              ▼
     ConfigStore.shortcut(for:)
              │  (suppressed during calibration)
              ▼
     KeyboardSimulator.fire()
         (CGEvent post)
              │
              ▼
       PipelineEvent
              │
              ├──► SoundFeedback.play()     (if soundEnabled)
              ├──► StatusPanelController     (if statusPanelEnabled)
              └──► UI (recentEvents, lastPipelineEvent)
```

## Target Responsibilities

| Target | Responsibility | Key Types |
|--------|---------------|-----------|
| **GestureFireTypes** | Shared value types, protocols | `TouchFrame`, `TouchPoint`, `TouchState`, `GestureType`, `KeyShortcut`, `SensitivityConfig`, `GestureFireConfig`, `EngineState`, `PipelineEvent`, `GestureRecognizer` protocol, `RejectionReason`, `RecognitionResult` |
| **GestureFireRecognition** | Gesture state machines + direction geometry | `RecognitionLoop` (actor), `TipTapRecognizer`, `CornerTapRecognizer`, `MultiFingerTapRecognizer`, `MultiFingerSwipeRecognizer`, `TrackedFinger`, `Geometry` (shared `Cardinal` + `nearestCardinal` helper reused by TipTap and MultiFingerSwipe) |
| **GestureFireIntegration** | OMS bridge | `OMSTouchSource` (actor), `TouchFrameAdapter` |
| **GestureFireShortcuts** | Keyboard simulation | `KeyboardSimulator`, `KeyCodeMap` |
| **GestureFireConfig** | Persistence + migration | `ConfigStore` (`@Observable`), `ConfigPersistence`, `ConfigMigration` |
| **GestureFireEngine** | Orchestration + onboarding + feedback | `AppCoordinator` (`@Observable`, `@MainActor`), `OnboardingCoordinator`, `SampleRecorder`, `SamplePlayer`, `DiagnosticRunner`, `FileLogger`, `SoundFeedback`, `LaunchAtLoginManager` |
| **GestureFireApp** | SwiftUI UI + onboarding wizard + settings | `MenuBarView`, `SettingsView` (Cmd+1..5 tab switching), `GestureMappingView` (per-family sections), `AdvancedSettingsView` (10 active parameters, 4 semantic sections), `FeedbackSettingsView`, `StatusSettingsView`, `LogViewerView`, `OnboardingView`, `OnboardingWindowController`, `StatusPanelController`, `StatusPanelView` |

## Concurrency Model

```
@MainActor:  AppCoordinator, ConfigStore, SoundFeedback, StatusPanelController,
             StatusPanelViewModel, all SwiftUI views
actor:       RecognitionLoop, OMSTouchSource
Sendable:    all types in GestureFireTypes (value types)
             KeyboardSimulator, FileLogger (structs, no mutable state)
```

- **No locks, no dispatch queues.** All synchronization via Swift actors.
- **No `@unchecked Sendable`.** All Sendable conformances are compiler-verified.
- Unstructured `Task {}` used only for: OMS stream listening, permission polling, starting timeout. All tracked and cancelled in `stop()`.

## Key Design Decisions

### 1. Struct Recognizers + Priority Order

Recognizers are value types (`struct`) with explicit state machines (`enum State`). They are owned exclusively by the `RecognitionLoop` actor — never shared. `RecognitionLoop` holds a **priority-ordered array** of `[any GestureRecognizer]`, built once at construction from the current `SensitivityConfig`. On every `TouchFrame`, every recognizer is fed the frame in array order; the **first recognizer that returns `.recognized` wins**, and that single gesture becomes the frame's `EngineResult`. Rejections from all recognizers are aggregated into `allRejections` for diagnostics, regardless of who won.

Phase 3 priority (highest-first):

1. **`CornerTapRecognizer`** — most constrained (exactly 1 finger, location-gated to a corner region)
2. **`MultiFingerTapRecognizer`** — 3/4/5 stationary fingers grouped within `tapGroupingWindowMs`
3. **`MultiFingerSwipeRecognizer`** — 3/4 fingers grouped + cluster-coherent translation
4. **`TipTapRecognizer`** — fallback (exactly 1 hold + 1 tap)

Rationale for ordering: the most constrained recognizer runs first so it has the chance to claim the gesture before a looser recognizer catches it. `MultiFingerTap` is above `MultiFingerSwipe` so a stationary cluster settles as a tap instead of triggering a zero-distance swipe. `TipTap` is last because it is the only recognizer that accepts a touching + tapping two-finger pattern and cannot collide with any of the multi-finger recognizers.

### 2. Shared Direction Geometry

`Geometry.nearestCardinal(of:)` is the single source of truth for direction classification. It returns `(Cardinal, angleDegrees)` — the nearest cardinal axis and the angle offset from it — and is reused by **both** `TipTapRecognizer` and `MultiFingerSwipeRecognizer`. Both recognizers compare the returned angle against `directionAngleTolerance` and emit an identical `RejectionReason(label: "directionAmbiguous", parameter: "directionAngleTolerance", ...)` when the vector is outside tolerance. One canonical meaning of "ambiguous direction" across the recognizer family.

### 3. Timestamp Authority

Recognizers receive time only via `frame.timestamp`. They never call `Date()`. This enables:
- Deterministic unit tests with constructed timestamps
- Sample replay producing identical results to live input
- No flaky timing-dependent tests

### 4. OMS Isolation

`OpenMultitouchSupport` is imported only in `GestureFireIntegration`. All other targets work with `TouchFrame` — a pure value type. This means:
- All recognition tests run without OMS/trackpad access
- Recognition logic is testable on CI without hardware
- OMS can be replaced without touching recognition code

### 5. @Observable over ObservableObject

`AppCoordinator` and `ConfigStore` use the `@Observable` macro (Observation framework), not `ObservableObject` + `@Published`. This provides:
- Automatic property tracking (no manual `objectWillChange`)
- Fine-grained view updates (only properties actually read trigger refresh)
- `@ObservationIgnored` for internal-only properties

### 6. Parameter Semantics

**All 14 `SensitivityConfig` parameters are active as of Phase 3 (H2 hardening).** 10 shared + 4 multi-finger dedicated. Every slider in Advanced Settings is backed by live recognizer code — there are no reserved knobs or hidden multipliers. Current usage:

| Parameter | Status | Used By |
|-----------|--------|---------|
| `holdThresholdMs` | Active (shared) | TipTap (hold detection) |
| `tapMaxDurationMs` | Active (shared) | TipTap, CornerTap (tap window) |
| `movementTolerance` | Active (shared) | TipTap, CornerTap (stationary check) |
| `debounceCooldownMs` | Active (shared) | All four recognizers (post-recognition / post-rejection cooldown) |
| `tapGroupingWindowMs` | Active (shared) | TipTap (lifted-finger grouping), MultiFingerTap, MultiFingerSwipe (multi-finger touchdown grouping) |
| `fingerProximityThreshold` | Active (shared) | TipTap (anti-swipe min distance) |
| `directionAngleTolerance` | Active (shared) | TipTap, MultiFingerSwipe (via `Geometry.nearestCardinal`) |
| `swipeMinDistance` | Active (shared) | MultiFingerSwipe (centroid displacement floor) |
| `swipeMaxDurationMs` | Active (shared) | MultiFingerSwipe (total gesture duration cap) |
| `cornerRegionSize` | Active (shared) | CornerTap (corner region radius) |
| `multiFingerTapDurationMs` | Active (dedicated) | MultiFingerTap (tap window — more permissive than shared `tapMaxDurationMs`) |
| `multiFingerMovementTolerance` | Active (dedicated) | MultiFingerTap (stationary check — more permissive than shared `movementTolerance`) |
| `multiFingerSpreadMax` | Active (dedicated) | MultiFingerTap (max cluster spread — replaces hidden `fingerProximityThreshold × 3`) |
| `swipeClusterTolerance` | Active (dedicated) | MultiFingerSwipe (per-frame cluster integrity) |

**Dual/triple-use parameters, kept as single knobs:**

- **`fingerProximityThreshold`** is used three different ways across three recognizers. The Phase 3 spec explicitly decided not to split it unless a real conflict arises — so far tuning one default (`0.15`) satisfies all three uses. Any future tuning dispute should reopen the split discussion rather than silently drifting the default.
- **`tapGroupingWindowMs`** is used twice: TipTap groups lifted fingers inside this window, while MultiFingerTap/Swipe group touchdown events. Same default (`200 ms`) works for both.

Advanced Settings exposes all 10 parameters, organized into **4 semantic sections** (Timing / Precision / Swipe / Corner Tap) rather than by owning recognizer. This matches the user's mental model and sidesteps the dual-use attribution problem.

### 7. Check vs Request Separation

Accessibility permission has two distinct operations:
- **Check**: `AXIsProcessTrusted()` — read-only, no UI, safe to poll
- **Request**: `AXIsProcessTrustedWithOptions(prompt: true)` — shows system dialog

These are strictly separated. Polling only ever checks. Request is triggered only by explicit user action (button tap). This prevents dialog spam.

## Gesture Families

`GestureType` enumerates every recognizable gesture. Phase 3 grouped them into five families that are reflected identically in the recognizers, in `GestureMappingView`'s section layout, and in user-facing captions:

| Family | GestureType cases | Recognizer | User-facing caption |
|--------|-------------------|------------|---------------------|
| TipTap | `tipTapLeft/Right/Up/Down` | `TipTapRecognizer` | "Hold one finger, tap another in a direction." |
| Multi-Finger Tap | `multiFingerTap3/4/5` | `MultiFingerTapRecognizer` | "Tap several fingers together and lift." |
| 3-Finger Swipe | `multiFingerSwipe3{Left/Right/Up/Down}` | `MultiFingerSwipeRecognizer` (count = 3) | "Place three fingers and slide in a direction." |
| 4-Finger Swipe | `multiFingerSwipe4{Left/Right/Up/Down}` | `MultiFingerSwipeRecognizer` (count = 4) | "Place four fingers and slide in a direction." |
| Corner Tap | `cornerTapTopLeft/TopRight/BottomLeft/BottomRight` | `CornerTapRecognizer` | "Single-finger tap inside a corner region." |

The UI's `GestureMappingView.GestureFamily` struct is the single source of truth for family ordering and membership. Adding a new gesture type means touching three places: the `GestureType` enum case, the owning recognizer, and the `GestureFamily` it belongs to.

## File Layout

```
Sources/
├── GestureFireTypes/       # 11 files — pure types + protocols
├── GestureFireRecognition/ # 7 files — recognizers + loop + geometry
│   ├── RecognitionLoop.swift
│   ├── TipTapRecognizer.swift
│   ├── CornerTapRecognizer.swift
│   ├── MultiFingerTapRecognizer.swift
│   ├── MultiFingerSwipeRecognizer.swift
│   ├── Geometry.swift          (shared nearestCardinal helper)
│   └── TrackedFinger.swift
├── GestureFireIntegration/ # 2 files — OMS bridge
├── GestureFireShortcuts/   # 2 files — CGEvent keyboard
├── GestureFireConfig/      # 4 files — persistence + presets
├── GestureFireEngine/      # 9 files — orchestration + onboarding + samples + feedback
└── GestureFireApp/         # 11 files — SwiftUI UI + onboarding wizard + settings + status panel

Tests/
├── GestureFireTypesTests/       # 7 files
├── GestureFireRecognitionTests/ # 10 files
│   ├── (one *RecognizerTests per recognizer)
│   ├── GeometryTests.swift
│   ├── MultiRecognizerReplayTests.swift   (the canary)
│   ├── FixtureGenerator.swift             (env-gated)
│   └── Fixtures/samples/                  (19 .gesturesample files)
├── GestureFireShortcutsTests/   # 1 file
├── GestureFireConfigTests/      # 3 files
└── GestureFireEngineTests/      # 9 files
```

Total: 46 source files, 30 test files (~5,375 source LOC, ~3,821 test LOC). Current test count: **215 tests in 44 suites, all passing**.

## Replay Regression Canary

`MultiRecognizerReplayTests` is the end-to-end regression net for the recognizer family. It loads every checked-in `.gesturesample` fixture, constructs a fresh `RecognitionLoop` with the sample's recorded `SensitivityConfig`, calls `replay(frames:)`, and asserts the emitted gesture list matches exactly `[sample.header.gestureType]`. Current coverage:

| Family | Fixtures |
|--------|----------|
| TipTap | 4 (one per cardinal) |
| Corner Tap | 4 (one per corner) |
| Multi-Finger Tap | 3 (3F, 4F, 5F) |
| Multi-Finger Swipe | 8 (3F/4F × 4 cardinals) |
| **Total** | **19** |

**Per-recognizer fixture rule:** every new recognizer ships its own fixtures in the same commit that introduces the recognizer, and **every prior fixture must keep passing** through each subsequent step. This rule caught zero regressions during Phase 3 — because it was enforced on every step, not at the end.

Fixtures are generated by `FixtureGenerator`, which is gated on the `GFIRE_GENERATE_FIXTURES=1` environment variable so a normal `swift test` run never regenerates them. Regeneration writes to the source tree via `#filePath`, making fixture diffs visible in version control.

## Cross-Phase Infrastructure

These components serve roles beyond their originating phase:

| Component | Created In | Current Role |
|-----------|-----------|--------------|
| `SampleRecorder` / `SamplePlayer` | Phase 1.5 | Phase 4: sample browser UI, auto-calibration input. Still future work. |
| `RecognitionLoop.replay()` | Phase 1.5 | **Phase 3 active**: the engine behind the 19-fixture replay canary in `MultiRecognizerReplayTests`. Phase 4: parameter search via replay. |
| `.gesturesample` format | Phase 1.5 | **Phase 3 active**: all 19 checked-in fixtures use the JSONL header + frames format unchanged. Format changes must be backward-compatible or include migration. |
| `GestureSample.toJSONL` / `fromJSONL` | Phase 1.5 | **Phase 3 active**: used by `FixtureGenerator` to serialize fixtures deterministically (ISO8601 with fractional seconds, sorted JSON keys). |
| `DiagnosticRunner` | Phase 1 | Extensible via `DiagnosticChecking` protocol for new diagnostic checks. |
| `OnboardingCoordinator` | Phase 1.5 | Phase 3: may need new steps for expanded gesture types. Not yet updated. |
| `SoundFeedback` | Phase 2 | Stable. May gain sound selection UI in Phase 5 (personalization). |
| `StatusPanelController` / `StatusPanelViewModel` | Phase 2 | Phase 3: will show new gesture types. View model pattern supports content updates without window server operations. |
| `FileLogger.readEntries(for:)` | Phase 2 | Phase 4: data source for tuning analytics dashboard. |
| `LaunchAtLoginManager` | Phase 2 | Stable. No expected changes unless macOS API changes. |
| Custom settings tab bar (Phase 2.6 → H3 rewrite) | Phase 2.6 | **Phase 3 active**: same visual tab bar, rewritten for accessibility in H3. Uses `.focusable()` views with `@FocusState` + `onMoveCommand` + `onKeyPress` instead of `.buttonStyle(.plain)` buttons. Tab key reaches tab bar, arrow keys switch tabs, Return/Space activates. `Cmd+1..5` via hidden background buttons. |

## Implementation Notes

Small SwiftUI-specific footguns that aren't worth a full process doc but are easy to trip over again:

- **`KeyEquivalent` in localized strings.** Interpolating a `KeyEquivalent.character` into an `accessibilityHint(_:)` that accepts `LocalizedStringKey` triggers the `appendInterpolation` deprecation warning in Swift 6 — `Character` is not `LocalizedStringKey`-friendly. Use `accessibilityHint(Text(verbatim: "..."))` or convert via `String(key.character)` first. This came up on the `Cmd+1..5` tab buttons (pre-H3).
- **`.buttonStyle(.plain)` removes macOS focus chain participation.** Never use `.plain` on interactive controls that must be keyboard/VoiceOver accessible. The Phase 2.6 custom tab bar was invisible to Tab key and VoiceOver until H3 rewrote it with `.focusable()` + `@FocusState` + `onMoveCommand`. Lesson: accessibility annotations (`.accessibilityLabel`, `.isSelected`) cannot fix a structurally unfocusable control.

Process documentation for all phases: `docs/process/`.

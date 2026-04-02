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
              ├── TipTapRecognizer (struct)
              └── [future recognizers]
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
       PipelineEvent → UI
```

## Target Responsibilities

| Target | Responsibility | Key Types |
|--------|---------------|-----------|
| **GestureFireTypes** | Shared value types, protocols | `TouchFrame`, `TouchPoint`, `TouchState`, `GestureType`, `KeyShortcut`, `SensitivityConfig`, `GestureFireConfig`, `EngineState`, `PipelineEvent`, `GestureRecognizer` protocol |
| **GestureFireRecognition** | Gesture state machines | `TipTapRecognizer`, `RecognitionLoop` (actor), `TrackedFinger` |
| **GestureFireIntegration** | OMS bridge | `OMSTouchSource` (actor), `TouchFrameAdapter` |
| **GestureFireShortcuts** | Keyboard simulation | `KeyboardSimulator`, `KeyCodeMap` |
| **GestureFireConfig** | Persistence + migration | `ConfigStore` (`@Observable`), `ConfigPersistence`, `ConfigMigration` |
| **GestureFireEngine** | Orchestration + onboarding | `AppCoordinator` (`@Observable`, `@MainActor`), `OnboardingCoordinator`, `SampleRecorder`, `SamplePlayer`, `DiagnosticRunner`, `FileLogger` |
| **GestureFireApp** | SwiftUI UI + onboarding wizard | `MenuBarView`, `SettingsView`, `DiagnosticView`, `OnboardingView`, `OnboardingWindowController` |

## Concurrency Model

```
@MainActor:  AppCoordinator, ConfigStore, all SwiftUI views
actor:       RecognitionLoop, OMSTouchSource
Sendable:    all types in GestureFireTypes (value types)
             KeyboardSimulator, FileLogger (structs, no mutable state)
```

- **No locks, no dispatch queues.** All synchronization via Swift actors.
- **No `@unchecked Sendable`.** All Sendable conformances are compiler-verified.
- Unstructured `Task {}` used only for: OMS stream listening, permission polling, starting timeout. All tracked and cancelled in `stop()`.

## Key Design Decisions

### 1. Struct Recognizers

Recognizers are value types (`struct`) with explicit state machines (`enum State`). They are owned exclusively by `RecognitionLoop` actor — never shared. This makes state transitions testable and deterministic.

### 2. Timestamp Authority

Recognizers receive time only via `frame.timestamp`. They never call `Date()`. This enables:
- Deterministic unit tests with constructed timestamps
- Sample replay producing identical results to live input
- No flaky timing-dependent tests

### 3. OMS Isolation

`OpenMultitouchSupport` is imported only in `GestureFireIntegration`. All other targets work with `TouchFrame` — a pure value type. This means:
- 82 tests run without OMS/trackpad access
- Recognition logic is testable on CI without hardware
- OMS can be replaced without touching recognition code

### 4. @Observable over ObservableObject

`AppCoordinator` and `ConfigStore` use the `@Observable` macro (Observation framework), not `ObservableObject` + `@Published`. This provides:
- Automatic property tracking (no manual `objectWillChange`)
- Fine-grained view updates (only properties actually read trigger refresh)
- `@ObservationIgnored` for internal-only properties

### 5. Parameter Semantics

Not all `SensitivityConfig` parameters are active. Current status:

| Parameter | Status | Used By |
|-----------|--------|---------|
| `holdThresholdMs` | Active | TipTapRecognizer |
| `tapMaxDurationMs` | Active | TipTapRecognizer |
| `movementTolerance` | Active | TipTapRecognizer |
| `debounceCooldownMs` | Active | TipTapRecognizer |
| `tapGroupingWindowMs` | Active | TipTapRecognizer |
| `fingerProximityThreshold` | Active | TipTapRecognizer (anti-swipe filter) |
| `directionAngleTolerance` | **NOT WIRED** | None — `computeDirection()` ignores it. Phase 3. |
| `swipeMinDistance` | Reserved | Phase 3 (swipe recognizers) |
| `swipeMaxDurationMs` | Reserved | Phase 3 |
| `cornerRegionSize` | Reserved | Phase 3 (corner tap recognizer) |

**`fingerProximityThreshold`** is dual-purpose: originally reserved for multi-finger proximity (Phase 3), now also used as TipTap anti-swipe distance check. May need splitting if the two use cases diverge.

### 6. Check vs Request Separation

Accessibility permission has two distinct operations:
- **Check**: `AXIsProcessTrusted()` — read-only, no UI, safe to poll
- **Request**: `AXIsProcessTrustedWithOptions(prompt: true)` — shows system dialog

These are strictly separated. Polling only ever checks. Request is triggered only by explicit user action (button tap). This prevents dialog spam.

## File Layout

```
Sources/
├── GestureFireTypes/       # 11 files — pure types + protocols
├── GestureFireRecognition/ # 3 files — recognizers + loop
├── GestureFireIntegration/ # 2 files — OMS bridge
├── GestureFireShortcuts/   # 2 files — CGEvent keyboard
├── GestureFireConfig/      # 4 files — persistence + presets
├── GestureFireEngine/      # 7 files — orchestration + onboarding + samples
└── GestureFireApp/         # 5 files — SwiftUI UI + onboarding wizard

Tests/
├── GestureFireTypesTests/       # 7 files
├── GestureFireRecognitionTests/ # 4 files
├── GestureFireShortcutsTests/   # 1 file
├── GestureFireConfigTests/      # 3 files
└── GestureFireEngineTests/      # 6 files
```

Total: 34 source files, 21 test files (~3,600 source LOC, ~2,250 test LOC).

## Cross-Phase Infrastructure

These components serve roles beyond their originating phase:

| Component | Created In | Role in Future Phases |
|-----------|-----------|----------------------|
| `SampleRecorder` / `SamplePlayer` | Phase 1.5 | Phase 2: sample browser UI. Phase 4: regression testing, auto-calibration input. |
| `RecognitionLoop.replay()` | Phase 1.5 | Phase 3: validate new recognizers against existing samples. Phase 4: parameter search via replay. |
| `DiagnosticRunner` | Phase 1 | Phase 2+: extensible via `DiagnosticChecking` protocol for new diagnostic checks. |
| `.gesturesample` files | Phase 1.5 | Long-lived assets. Format changes must be backward-compatible or include migration. |
| `OnboardingCoordinator` | Phase 1.5 | Phase 3: may need new steps for expanded gesture types. |

Process documentation for all phases: `docs/process/`.

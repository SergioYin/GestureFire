# GestureFire v1 Roadmap

> Canonical phase plan. Supersedes all earlier planning discussions.
> Updated: 2026-04-03

## Phase Summary

| Phase | Name | Scope | Status |
|-------|------|-------|--------|
| 1 | Core Loop | TipTap 4-direction + shortcut mapping + menu bar UI + diagnostics | ✅ Done |
| 1H | Hardening | Engine state model, pipeline observability, permission safety, code review fixes | ✅ Done |
| 1.5 | Onboarding + Calibration | First-run wizard, sample recording/replay, calibration flow | ✅ Done |
| 2 | Experience Polish | Sound feedback, status panel, log viewer, launch-at-login | ✅ Done |
| 2.5 | UI Structure Polish | Settings restructure, menu bar simplification, onboarding copy | ✅ Done |
| 2.6 | Visual Polish | Design system, surface hierarchy, status weight, spacing | ✅ Done |
| 3 | More Gestures | Multi-finger tap, multi-finger swipe, corner tap | ⬜ |
| 4 | Smart Tuning | Rejection tracking, keyboard correlation, auto-adjust parameters | ⬜ |
| 5 | Personalization | Profiles, per-app mappings, import/export | ⬜ |

---

## Phase 1: Core Loop ✅

**Deliverables:** TipTap 4-direction recognition, CGEvent keyboard simulation, menu bar toggle, settings UI, diagnostics view.

**Verification (all passed):**
- `swift test` — 82 tests, 19 suites, all green
- Diagnostics Layer 1 (accessibility, touch frames, CGEvent) automated
- Layer 2 user confirmation (DiagnosticView)
- Daily TipTap usable via `dist/GestureFire.app`
- JSONL file logging with daily rotation

**Key files:** 28 source files, 13 test files, ~2,257 source LOC.

## Phase 1H: Hardening ✅

**Deliverables:** EngineState enum, PipelineEvent enum, `@Observable` coordinator, permission check/request separation, TipTap lift detection fix, code review fixes (4 HIGH resolved).

**See:** REVIEW.md for full retrospective.

---

## Phase 1.5: Onboarding + Verification + Sample Capture ✅

**Goal:** New user can go from first launch to working gesture recognition in under 2 minutes.

**Delivered:** 4-step onboarding wizard, 3 preset schemes, real-time gesture verification with sample recording, sample replay infrastructure, NSWindow lifecycle for menu-bar apps.

**Naming note:** The "Practice" step performs real-time verification + sample capture, not parameter optimization. True calibration (sample-based auto-tuning) is Phase 4.

**See:** `REVIEW.md` Phase 1.5 section for full retrospective, `docs/PHASE-1.5-ACCEPTANCE.md` for verification checklist.

**Key files:** 34 source files, 21 test files, ~3,600 source LOC.

---

## Phase 2: Experience Polish ✅

**Goal:** Daily-driver comfort — audio/visual feedback, system integration.

**Delivered:** Sound feedback (NSSound, configurable), floating status panel (non-activating NSPanel, view-model-driven), log viewer with JSONL parsing + filtering, launch-at-login (SMAppService), General settings tab, sample save failure feedback in onboarding, menu bar title status display.

**See:** `REVIEW.md` Phase 2 section for full retrospective.

**Key files:** 40 source files, 24 test files, ~4,163 source LOC.

---

## Phase 2.5: UI Structure Polish ✅

**Goal:** Clean up information architecture — settings tab restructure, menu bar simplification, onboarding copy rewrites.

**Delivered:** Settings tabs reorganized (General renamed to Feedback, Diagnostics merged into Status tab), menu bar title shortened to `"GF · N"`, onboarding copy tightened, visual consistency pass.

**See:** `docs/phases/PHASE-2.5.md` for spec.

---

## Phase 2.6: Visual Polish ✅

**Goal:** Make the interface look finished with surface hierarchy, visual weight on status indicators, and consistent spacing.

**Delivered:** `DesignSystem.swift` (Spacing grid, SettingsCard, StatusBadge), `.formStyle(.grouped)` on all Form tabs, Status tab hero card with tinted background, onboarding visual lift (32pt pills, 96pt icon circles, accent left border on preset cards), status panel with `.thickMaterial` + `.headline` text + accent border.

**Key files:** 42 source files, 24 test files. 1 new file, 7 modified. 153 tests pass.

**See:** `docs/phases/PHASE-2.6.md` for spec and retrospective.

---

## Phase 3: More Gestures ⬜

**Goal:** Expand gesture vocabulary beyond TipTap.

### Scope

- `MultiFingerTapRecognizer` — 3/4/5-finger tap
- `MultiFingerSwipeRecognizer` — 3/4-finger swipe (up/down/left/right)
- `CornerTapRecognizer` — tap in trackpad corners
- UI: new sections in Settings for each gesture type
- Sensitivity UI exposes Phase 2+ parameters (`fingerProximityThreshold`, `swipeMinDistance`, `swipeMaxDurationMs`, `cornerRegionSize`)

### Carry-Over from Phase 2

| Item | Priority | Notes |
|------|----------|-------|
| `directionAngleTolerance` not wired | P1 | Wire into `TipTapRecognizer.computeDirection()` when adding swipe recognizers with angular thresholds |
| Gesture animation previews | P2 | More valuable with expanded gesture vocabulary |
| `FileLogger` thread safety | P2 | Evaluate when recognizers may log from background |
| `FileLogger.log()` force-unwrap | P3 | Fix alongside FileLogger refactoring |
| `AppCoordinator.stop()` race | P2 | Multi-recognizer architecture amplifies the issue |
| SwiftUI view unit tests | P3 | Consider snapshot testing for gesture-specific UI |
| LogEntry stable identity (UUID) | P3 | Fix when expanding log viewer |
| `InMemoryPersistence.Storage @unchecked Sendable` | P3 | Convert to `@MainActor`-constrained class |
| NSPanel sound (if still present) | P0 | Verify on Phase 3 kickoff — if still audible, escalate |

### Verification Criteria

- [ ] Each new recognizer has ≥10 tests with fixture sequences
- [ ] `RecognitionLoop` handles multiple recognizers (priority order)
- [ ] Settings UI shows all gesture types with shortcut mapping
- [ ] Sensitivity UI shows all 10 parameters
- [ ] No regression in TipTap recognition (replay baseline samples from 1.5)

---

## Phase 4: Smart Tuning ⬜

**Goal:** System learns from user behavior to reduce false negatives.

### Scope

- `TouchSessionTracker` — log raw metrics per gesture attempt
- `GlobalShortcutMonitor` — detect when user presses a mapped shortcut manually (gesture failed)
- `FeedbackCorrelator` — match manual shortcut press within 3s of rejection → "false negative"
- `FeedbackAccumulator` — after 5 correlated false negatives for same gesture, auto-adjust relevant parameter (with safety bounds + 24h cooldown)
- Dashboard showing tuning history and parameter drift

### Carry-Over from Earlier Phases

| Item | Source | Notes |
|------|--------|-------|
| Sample browser / management UI | Phase 1.5 | Build alongside auto-calibration — browse, delete, export `.gesturesample` files |
| `GestureFireConfig.version` migration | Phase 2 | Activate if Phase 4 schema changes require explicit migration |

### Verification Criteria

- [ ] Session logs contain raw touch metrics for each attempt
- [ ] Correlator correctly matches shortcut press to prior rejection
- [ ] Accumulator adjusts parameter after threshold (configurable, default 5)
- [ ] Safety bounds prevent parameters from leaving valid range
- [ ] 24h cooldown prevents runaway adjustment
- [ ] User can review and revert auto-adjustments

---

## Phase 5: Personalization ⬜

**Goal:** Per-context adaptation.

### Scope

- Multiple configuration profiles (e.g. "Work", "Creative", "Browsing")
- Per-app gesture mappings (detect frontmost app via NSWorkspace)
- Import/export config as `.gesturefire` file
- Cloud sync consideration (iCloud key-value store or file)

### Verification Criteria

- [ ] Profile switching works from menu bar
- [ ] Per-app mappings activate on app focus change
- [ ] Import/export round-trips correctly
- [ ] Migration handles profile-aware config format

---

## Process

All phases from Phase 2 onward follow the unified workflow and principles documented in:

- `docs/process/WORKING_PRINCIPLES.md` — 9 validated principles from Phase 1–1.5
- `docs/process/PHASE_WORKFLOW.md` — 7-step phase lifecycle (kickoff → close)
- `docs/process/IMPLEMENTATION_PLAYBOOK.md` — rules for implementer collaboration
- `docs/process/PHASE_TEMPLATE.md` — copy-and-fill template for each new phase

## Design Principles (all phases)

1. **Struct recognizers + actor isolation** — recognizers are value types owned by `RecognitionLoop` actor. No shared mutable state.
2. **TouchFrame abstraction** — all recognition code is OMS-independent. OMS is confined to `GestureFireIntegration`.
3. **Timestamp authority** — recognizers use only `frame.timestamp`, never `Date()`. Enables deterministic replay.
4. **Protocol extension points** — `GestureRecognizer` protocol for new gestures, `ConfigPersisting` for storage, `DiagnosticChecking` for diagnostics.
5. **Immutable config updates** — `SensitivityConfig.withValue()` returns new copy. `ConfigStore.update()` takes a transform closure.

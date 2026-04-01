# GestureFire v1 Roadmap

> Canonical phase plan. Supersedes all earlier planning discussions.
> Updated: 2026-04-01

## Phase Summary

| Phase | Name | Scope | Status |
|-------|------|-------|--------|
| 1 | Core Loop | TipTap 4-direction + shortcut mapping + menu bar UI + diagnostics | ✅ Done |
| 1H | Hardening | Engine state model, pipeline observability, permission safety, code review fixes | ✅ Done |
| 1.5 | Onboarding + Calibration | First-run wizard, sample recording/replay, calibration flow | ✅ Done |
| 2 | Experience Polish | Sound feedback, status panel, log viewer, launch-at-login | ⬜ Next |
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

## Phase 1.5: Onboarding + Calibration + Sample Library ⬜

**Goal:** New user can go from first launch to working gesture recognition in under 2 minutes.

### Scope

1. **First-Run Wizard (4 steps)**
   - Step 1: Grant accessibility permission (guided, with troubleshooting)
   - Step 2: Choose gesture preset (e.g. "Browser Navigation", "IDE Shortcuts", "Custom")
   - Step 3: Practice — user performs each mapped gesture, system confirms recognition
   - Step 4: Confirm — summary of what was configured, start engine

2. **Sample Recording**
   - Record TouchFrame sequences as `.gesturesample` files during calibration
   - Format: JSONL of TouchFrame snapshots with metadata header
   - Storage: `~/Library/Application Support/GestureFire/samples/`

3. **Sample Replay for Testing**
   - Feed recorded samples into `RecognitionLoop` via `[any GestureRecognizer]`
   - Enables deterministic regression tests from real trackpad data
   - No OMS dependency in replay path (uses TouchFrame abstraction)

4. **Calibration Flow**
   - After preset selection, user performs each gesture 3× to validate defaults
   - If recognition fails, offer to adjust sensitivity (guided slider)
   - Record successful samples as baseline for future comparison

### Verification Criteria

- [ ] First launch shows wizard (detected via absence of config file)
- [ ] Permission step correctly handles: already granted, needs grant, denied
- [ ] Practice step recognizes gestures in real-time with visual feedback
- [ ] At least 3 `.gesturesample` files generated after calibration
- [ ] Sample replay produces same recognition results as live input
- [ ] Wizard can be re-triggered from Settings

### Technical Prerequisites (from Phase 1)

- ✅ `TouchFrame` abstraction (OMS-independent)
- ✅ `frame.timestamp` as sole time authority (replay-safe)
- ✅ `SensitivityConfig` with 10 parameters + dynamic access
- ✅ `RecognitionLoop` accepts `[any GestureRecognizer]` (feed from file or live)
- ✅ Diagnostic infrastructure for permission flow

### New Files (estimated)

| File | Target | Purpose |
|------|--------|---------|
| `OnboardingView.swift` | GestureFireApp | 4-step wizard UI |
| `OnboardingCoordinator.swift` | GestureFireEngine | Wizard state machine |
| `SampleRecorder.swift` | GestureFireEngine | TouchFrame → .gesturesample |
| `SamplePlayer.swift` | GestureFireEngine | .gesturesample → TouchFrame stream |
| `GestureSample.swift` | GestureFireTypes | Sample file format types |
| `PresetConfig.swift` | GestureFireConfig | Bundled gesture presets |

---

## Phase 2: Experience Polish ⬜

**Goal:** Daily-driver comfort — audio/visual feedback, system integration.

### Scope

- Sound feedback on gesture recognition (NSSound, configurable)
- Status panel (NSPanel) showing last recognized gesture + shortcut fired
- Log viewer in Settings (read FileLogger JSONL, filterable)
- Launch-at-login (SMAppService)
- Menu bar tooltip with engine status

### Verification Criteria

- [ ] Sound plays on recognition (can be disabled)
- [ ] Status panel shows gesture → shortcut mapping in real-time
- [ ] Log viewer displays today's entries with gesture type filter
- [ ] Launch-at-login toggle works in Settings
- [ ] No new gesture types — only UX improvements

---

## Phase 3: More Gestures ⬜

**Goal:** Expand gesture vocabulary beyond TipTap.

### Scope

- `MultiFingerTapRecognizer` — 3/4/5-finger tap
- `MultiFingerSwipeRecognizer` — 3/4-finger swipe (up/down/left/right)
- `CornerTapRecognizer` — tap in trackpad corners
- UI: new sections in Settings for each gesture type
- Sensitivity UI exposes Phase 2+ parameters (`fingerProximityThreshold`, `swipeMinDistance`, `swipeMaxDurationMs`, `cornerRegionSize`)

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

## Design Principles (all phases)

1. **Struct recognizers + actor isolation** — recognizers are value types owned by `RecognitionLoop` actor. No shared mutable state.
2. **TouchFrame abstraction** — all recognition code is OMS-independent. OMS is confined to `GestureFireIntegration`.
3. **Timestamp authority** — recognizers use only `frame.timestamp`, never `Date()`. Enables deterministic replay.
4. **Protocol extension points** — `GestureRecognizer` protocol for new gestures, `ConfigPersisting` for storage, `DiagnosticChecking` for diagnostics.
5. **Immutable config updates** — `SensitivityConfig.withValue()` returns new copy. `ConfigStore.update()` takes a transform closure.

# Phase 3: More Gestures

> Draft — pending user sign-off before implementation. No code written yet.

## Goal

Expand GestureFire's gesture vocabulary from 4 TipTap directions to a complete multi-finger set — multi-finger taps, multi-finger swipes, and corner taps — while evolving `RecognitionLoop` to host multiple recognizers and settling the Phase 2.6 carry-over items that directly touch the recognition path or the settings UI the new gestures will live in.

## Scope

### S1 — Recognition engine foundations

- [ ] Extend `GestureType` with the new cases (see S2/S3/S4). All new cases get `displayName`, `CaseIterable` ordering, and are grouped by family for UI purposes.
- [ ] `RecognitionLoop` evolves from a hard-coded `[TipTapRecognizer]` to an ordered array of heterogeneous `any GestureRecognizer` instances. Frames go through recognizers in priority order; first `.recognized` short-circuits the rest. All others still receive the frame when the loop is idle so they can update their own state (the short-circuit applies only once a gesture is emitted).
- [ ] Shared geometry helpers extracted to a new `Sources/GestureFireRecognition/Geometry.swift`: angle-from-vector, angle tolerance check, centroid, pairwise-max-distance. Only code used by 2+ recognizers moves there — no speculative helper library.
- [ ] **Recognizer priority order is fixed for this phase** (not "to be decided during implementation"). Highest-first:
    1. `CornerTapRecognizer` — most constrained: single finger, location-gated. Must pre-empt TipTap's single-tap path.
    2. `MultiFingerTapRecognizer` — constrained by finger count (≥3) and grouping window. Cannot collide with TipTap (TipTap uses exactly 1 hold + 1 tap).
    3. `MultiFingerSwipeRecognizer` — constrained by finger count (3 or 4) and motion. Placed below multi-finger tap so that a stationary 3-finger touchdown cannot accidentally fire a swipe before settling as a tap.
    4. `TipTapRecognizer` — lowest priority: the oldest, least-constrained gesture. Acts as a fallback.
  This order is documented in both `RecognitionLoop` doc comment and `docs/architecture/overview.md`. Any change to this order after spec lock must be a written Deferred-Items entry justifying why.

### S2 — `MultiFingerTapRecognizer` (3/4/5-finger tap)

- [ ] New file `Sources/GestureFireRecognition/MultiFingerTapRecognizer.swift`. Struct, explicit `enum State { case idle; case grouping(...); case cooldown(until:) }`, no `Date()`.
- [ ] Recognizes: N fingers (N ∈ {3,4,5}) make contact within `tapGroupingWindowMs`, stay stationary within `movementTolerance`, all lift within `tapMaxDurationMs`, pairwise max distance ≤ `fingerProximityThreshold × 3` (or a dedicated multiplier if the Phase 3 evaluation in S6 decides to split).
- [ ] Emits `.multiFingerTap3`, `.multiFingerTap4`, `.multiFingerTap5`. Enters cooldown on recognition.
- [ ] Timestamp authority: all durations computed from `frame.timestamp` diffs. No system clock.

### S3 — `MultiFingerSwipeRecognizer` (3/4-finger × 4 directions)

- [ ] New file `Sources/GestureFireRecognition/MultiFingerSwipeRecognizer.swift`. Struct, explicit state machine.
- [ ] Recognizes: N fingers (N ∈ {3,4}) touch down together (within `tapGroupingWindowMs`), their centroid moves ≥ `swipeMinDistance` within `swipeMaxDurationMs`, the resulting vector's angle is within `directionAngleTolerance` of one of the 4 cardinal axes, and the N fingers stay within `fingerProximityThreshold` of the centroid throughout the motion. Emits `.multiFingerSwipe3Up/Down/Left/Right`, `.multiFingerSwipe4Up/Down/Left/Right`.
- [ ] **Wires `directionAngleTolerance`** for the first time. Geometry helper is shared with the TipTap direction wiring (S6).

### S4 — `CornerTapRecognizer` (4 corners)

- [ ] New file `Sources/GestureFireRecognition/CornerTapRecognizer.swift`. Struct, explicit state machine.
- [ ] Recognizes: single finger tap (down+up within `tapMaxDurationMs`, stationary within `movementTolerance`) whose position falls inside a corner region defined by `cornerRegionSize` (fraction of each edge). Emits `.cornerTapTopLeft/TopRight/BottomLeft/BottomRight`.
- [ ] Priority note: CornerTap runs before TipTap so that a corner tap is never accidentally consumed by the tap-only half of TipTap's state machine.

### S5 — Settings UI extension (fits inside Phase 2.6 visual structure)

- [ ] `Gestures` tab: reorganize into **families** inside the existing `Form(.grouped)`. One `Section` per family: "TipTap", "Multi-Finger Tap", "Multi-Finger Swipe (3 Fingers)", "Multi-Finger Swipe (4 Fingers)", "Corner Tap". Rows inside each section are the existing `LabeledContent` + `ShortcutField` pattern — no component redesign. This keeps the Phase 2.6 surface hierarchy intact.
- [ ] `Advanced` tab: add a new `Section("Multi-Finger & Swipe")` exposing the parameters the new recognizers actually use: `fingerProximityThreshold`, `tapGroupingWindowMs`, `swipeMinDistance`, `swipeMaxDurationMs`, `directionAngleTolerance`, `cornerRegionSize`. Existing TipTap section stays as-is. The "Reset to Defaults" action resets everything (no change).
- [ ] UI must not expose any parameter that is still not wired by the end of Phase 3 (Principle §6). The parameter-status table in `docs/architecture/overview.md` gets updated in the same PR as wiring.
- [ ] `GestureMappingView`'s `ForEach(GestureType.allCases)` is replaced by an explicit per-family iteration so the section grouping is stable.

### S6 — Phase 2.6 carry-over items addressed in this phase

- [ ] **`directionAngleTolerance` wiring**: `TipTapRecognizer.computeDirection()` replaces the hard-coded `abs(dx) > abs(dy)` with an angle check that honours `directionAngleTolerance`. A vector whose angle to the nearest cardinal axis exceeds the tolerance is rejected (new `RejectionReason.directionAmbiguous`). Shared with the swipe recognizer via `Geometry.swift`.
- [ ] **`Cmd+1..5` keyboard cycling** for Settings tabs: add `.keyboardShortcut("1", modifiers: .command)` … `"5"` to each `SettingsTabButton` (Phase 2.6 carry-over, P2).
- [ ] **`fingerProximityThreshold` dual-use evaluation**: as the multi-finger recognizers come in, decide in writing (in `docs/architecture/overview.md` §5) whether to split the parameter into `tipTapMinSeparation` + `multiFingerMaxSpread` or keep a single knob. Default path: **keep single knob unless a real conflict shows up during S2/S3 implementation**. The evaluation and decision are part of scope; the split itself is only in scope if the evaluation concludes it must ship.

### S7 — Accessibility verification pass (Phase 2.6 carry-over, P1)

- [ ] Manual Tab-key focus traversal across the custom Settings tab bar and each tab's content (including the Status tab `ScrollView` from Phase 2.6).
- [ ] Manual VoiceOver pass on the same surfaces plus the new gesture mapping sections.
- [ ] Findings recorded in `docs/PHASE-3-ACCEPTANCE.md`. Any blockers fix in scope; any non-blockers re-deferred with target phase. **No new accessibility features are in scope** — this is verification + tactical fixes only.

### S8 — Regression via replay assets (per-recognizer, not TipTap-only)

**Rule for this phase**: every recognizer that ships in Phase 3 ships with its own replay regression assets. The replay test is not a one-off TipTap guard — it is a running ledger that every subsequent step must keep green.

- [ ] New test file `Tests/GestureFireRecognitionTests/MultiRecognizerReplayTests.swift` exercises `RecognitionLoop.replay()` on a checked-in fixture bundle.
- [ ] **TipTap fixtures** (baseline, added in Step 0 before any behaviour change): at minimum 4 samples, one per direction, hand-authored via `Fixtures.tipTapSequence(...)` and serialised to `.gesturesample` JSON. Must pass against the current single-recognizer `RecognitionLoop` before Step 1 begins.
- [ ] **Corner tap fixtures**: 4 samples, one per corner. Added alongside `CornerTapRecognizer` in its step, not later.
- [ ] **Multi-finger tap fixtures**: 3 samples, one per finger count (3, 4, 5). Added alongside `MultiFingerTapRecognizer`.
- [ ] **Multi-finger swipe fixtures**: 8 samples covering 3- and 4-finger × 4 directions (may be reduced to 4 if authoring cost is high, but each direction must be represented at least once). Added alongside `MultiFingerSwipeRecognizer`.
- [ ] **Replay invariant** (mandatory gate for every step from Step 1 onward): after each code change, the full replay suite must stay green. A recognizer step is only considered complete when **all prior-recognizer fixtures still pass** — adding a new recognizer is never an excuse for an older one to regress. If a prior fixture goes red, roll back before continuing.
- [ ] Fixtures live under `Tests/GestureFireRecognitionTests/Fixtures/samples/`, are version-controlled, and are explicitly labelled "fixture, not user sample" in a `README.md` inside that directory to prevent confusion with runtime `.gesturesample` files under `~/Library/Application Support/...`.
- [ ] Fixture encoding uses whatever on-disk format `GestureSample` + `SamplePlayer` already define — no new serialisation path. If the authoring harness needs a small helper (`Fixtures.writeGestureSample(...)` etc.), it lives in `Tests/GestureFireRecognitionTests/` only.

### S9 — Architecture doc update

- [ ] `docs/architecture/overview.md` §2 (data flow) updated to show the multi-recognizer array.
- [ ] `docs/architecture/overview.md` §5 (parameter status table) updated: `directionAngleTolerance` → Active, `swipeMinDistance`/`swipeMaxDurationMs`/`cornerRegionSize` → Active, `fingerProximityThreshold` dual-use note resolved per S6 evaluation.
- [ ] `docs/architecture/overview.md` §3 (concurrency) unchanged (`RecognitionLoop` is still a single actor).

## Out of Scope

Explicitly **not** in Phase 3. Anything below that turns out to be needed gets a `Deferred Items` entry, not a silent scope bump.

- Smart tuning, rejection-reason tracking, auto-adjust (Phase 4).
- Sample browser / management UI, sample import/export, sample deletion (Phase 4).
- Real sample-based calibration (parameter search over recorded samples) (Phase 4).
- Per-application profiles, frontmost-app detection, profile switching (Phase 5).
- Config import/export file format, cloud sync (Phase 5).
- Card hover effects, onboarding step transition animations, custom dark/light specialization (Phase 5).
- `ShortcutField` pill restyle — still defers to a visual-polish phase, not here. Phase 3 reuses the existing `ShortcutField` as-is.
- Slider endpoint labels — not in scope; the Advanced tab gets more parameters, not more visual ornamentation.
- `LogViewerView` alternating row tint — blocked on custom row rendering outside `List`. Stays deferred.
- `FileLogger` thread-safety rework, `FileLogger.log()` force-unwrap fix, `LogEntry` UUID identity, `InMemoryPersistence.Storage @unchecked Sendable` conversion — **not touched in Phase 3** unless the multi-recognizer work directly disturbs them. Each keeps its own carry-over entry re-deferred to Phase 4 (see Carry-Over table below).
- SwiftUI view unit / snapshot tests — not in scope. The new recognizers get heavy unit coverage; the UI changes are small section additions, not new components.
- `AppCoordinator.stop()` race — re-deferred to Phase 4 unless the multi-recognizer evolution hits it.
- `GestureFireConfig.version` migration activation — stays Phase 5.
- Onboarding wizard changes for new gesture types — the Phase 1.5 wizard is preset-driven and uses TipTap for practice. Phase 3 does **not** extend the practice step to the new gestures. Rationale: the wizard is the user's first-2-minutes experience, changing it alongside a recogniser expansion doubles the risk. If the new gestures need a wizard pass, that is its own scope.

## Deliverables

| Deliverable | Target | New/Modified |
|-------------|--------|--------------|
| `Geometry.swift` | `GestureFireRecognition/` | New |
| `MultiFingerTapRecognizer.swift` | `GestureFireRecognition/` | New |
| `MultiFingerSwipeRecognizer.swift` | `GestureFireRecognition/` | New |
| `CornerTapRecognizer.swift` | `GestureFireRecognition/` | New |
| `RecognitionLoop.swift` | `GestureFireRecognition/` | Modified (multi-recognizer array + priority) |
| `TipTapRecognizer.swift` | `GestureFireRecognition/` | Modified (`directionAngleTolerance` wiring via `Geometry`) |
| `GestureType.swift` | `GestureFireTypes/` | Modified (new cases, family grouping, `displayName`) |
| `RecognizerResult.swift` | `GestureFireTypes/` | Modified if new `RejectionReason` cases needed (`directionAmbiguous`, `fingersNotGrouped`, etc.) |
| `SettingsView.swift` | `GestureFireApp/` | Modified (Gestures tab per-family sections, `.keyboardShortcut` on tab buttons) |
| `AdvancedSettingsView.swift` | `GestureFireApp/` | Modified (new parameter section) |
| `MultiFingerTapRecognizerTests.swift` | `Tests/GestureFireRecognitionTests/` | New |
| `MultiFingerSwipeRecognizerTests.swift` | `Tests/GestureFireRecognitionTests/` | New |
| `CornerTapRecognizerTests.swift` | `Tests/GestureFireRecognitionTests/` | New |
| `MultiRecognizerReplayTests.swift` | `Tests/GestureFireRecognitionTests/` | New |
| `Fixtures.swift` | `Tests/GestureFireRecognitionTests/` | Modified (new factories: `multiTapSequence`, `multiSwipeSequence`, `cornerTapSequence`) |
| `docs/architecture/overview.md` | — | Modified |
| `docs/PHASE-3-ACCEPTANCE.md` | `docs/` | New (before acceptance) |

## Technical Preconditions

- [x] Phase 2.6 closed and accepted (`docs/PHASE-2.6-ACCEPTANCE.md`).
- [x] `RecognitionLoop.replay()` and `SamplePlayer` already exist and are used in Phase 1.5 tests — no new infrastructure needed for the regression path.
- [x] `SensitivityConfig` already contains all 10 parameters with bounds — no schema change needed.
- [x] `ConfigStore` + `ConfigPersistence` handle forward-compatible decoding (`decodeIfPresent` with defaults) — new `GestureType` cases with no mapping simply decode as "unmapped".
- [x] `.formStyle(.grouped)` Gestures tab structure from Phase 2.6 — the new sections drop in without revisiting the visual system.

## Carry-Over Items Addressed

| Item | Source | Resolution |
|------|--------|------------|
| `directionAngleTolerance` NOT wired | Phase 1 / 2.6 | **In scope (S6)**. Wired via `Geometry.swift` and honored by both `TipTapRecognizer.computeDirection()` and `MultiFingerSwipeRecognizer`. |
| Settings tab bar `Cmd+1..5` cycling | Phase 2.6 | **In scope (S6)**. `.keyboardShortcut` on each `SettingsTabButton`. |
| Tab key / VoiceOver manual verification (custom tab bar + Status tab ScrollView) | Phase 2.6 | **In scope (S7)**. Manual pass; findings recorded in acceptance doc. |
| `fingerProximityThreshold` dual-use evaluation | Phase 2.6 | **In scope (S6)**. Written decision in `overview.md` §5. Actual parameter split only if evaluation concludes it must ship. |
| Gesture animation previews | Phase 1.5 | **Re-deferred to Phase 5**. Not on the critical path for gesture recognition itself; more valuable alongside other personalization polish. |
| SwiftUI view snapshot tests | Phase 2 | **Re-deferred to Phase 4**. Phase 3 UI additions are section-level, not new components — still not the right time to bring in snapshot infra. |
| `LogEntry` stable identity (UUID) | Phase 2 | **Re-deferred to Phase 4**. Only worth fixing when the log viewer is expanded with richer rendering. |
| `InMemoryPersistence.Storage @unchecked Sendable` | Phase 2 | **Re-deferred to Phase 4**. Internal to test support; no Phase 3 code touches it. |
| `FileLogger` thread safety | Phase 2 | **Re-deferred to Phase 4**. Phase 3 recognizers do not log from background; all logging still happens on `@MainActor`. If that changes during implementation, the item becomes in-scope. |
| `FileLogger.log()` force-unwrap | Phase 2 | **Re-deferred to Phase 4**. Tied to the same refactor. |
| `AppCoordinator.stop()` race | Phase 2 | **Re-deferred to Phase 4**. Multi-recognizer evolution happens inside `RecognitionLoop`, which is re-entrant-safe; the race is still in the `source.stop()` path, untouched by Phase 3. Re-evaluated if implementation hits it. |
| `GestureFireConfig.version` migration | Phase 2 | **Re-deferred to Phase 5**. Per-app profiles are the real trigger. |
| Sample browser / management UI | Phase 1.5 | **Re-deferred to Phase 4**. Phase 3 uses samples for regression only, no user-facing management. |
| `GestureFireConfig.version` activation | Phase 2 | **Re-deferred to Phase 5**. Unchanged. |
| Unused-shortcut detection / warning | Phase 2.6 (investigation) | **Re-deferred to Phase 4**. Lives naturally in `FeedbackCorrelator`. |
| `ShortcutField` pill restyle | Phase 2.6 | **Re-deferred to Phase 5**. Keeps existing look in Phase 3; fits alongside personalization polish. |
| Slider endpoint labels | Phase 2.6 | **Re-deferred to Phase 5**. Same rationale as above. |
| Onboarding step transition animation | Phase 2.6 | **Re-deferred to Phase 5**. |
| `LogViewerView` alternating row tint | Phase 2.6 | **Re-deferred**. Blocked on custom row rendering; revisit in a future log-viewer phase. |

## Verification Criteria

### Automated

- [ ] `swift build` passes under the CLI toolchain.
- [ ] `./scripts/test.sh` (Xcode toolchain, because Swift Testing requires Xcode's bundled framework) passes with **zero regression**: the current 153-test baseline must still pass, plus new tests from S2/S3/S4/S8.
- [ ] New tests added: a minimum of 10 tests per new recognizer covering happy path per direction/finger-count, each rejection reason, state transitions, cooldown. Replay regression test loads the checked-in fixture bundle and asserts recognised gesture list is identical.
- [ ] No new `@unchecked Sendable`. No new `Date()` call in any recognizer (`rg "Date\(\)" Sources/GestureFireRecognition/` must return no results outside comments).
- [ ] `swift build` warnings budget: no new warnings introduced (Swift 6 strict concurrency stays clean).

### Manual (real device)

- [ ] Each new gesture triggers reliably on a real trackpad when mapped to a visible shortcut (e.g. `cmd+left`). Map one per family as smoke test.
- [ ] Priority order: a corner tap in the top-left does not also fire TipTap; a 3-finger tap in the middle does not also fire a 2-finger TipTap.
- [ ] TipTap continues to work in all 4 directions with no perceptible latency regression.
- [ ] `Cmd+1..5` cycles Settings tabs.
- [ ] Tab key traverses interactive elements in Settings (all tabs) and Status tab without landing on dead zones.
- [ ] VoiceOver reads all new gesture mapping rows and new Advanced parameters with sensible labels.
- [ ] Light mode + dark mode both render the extended Gestures / Advanced tabs without visual glitches at 560×520 minimum window size.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Multi-recognizer priority causes TipTap false negatives | Medium | P0 | S8 replay test on the TipTap sample corpus is the primary guard. Priority order documented and unit-tested. |
| `directionAngleTolerance` wiring changes TipTap recognition for directions near diagonals | Medium | P1 | Replay regression on TipTap samples. Tolerance default (30°) chosen to be permissive enough that existing samples still pass; narrowing is deferred. |
| Multi-finger recognizer misfires on palm rest / accidental touches | High | P0 | `movementTolerance` + `fingerProximityThreshold` + `tapGroupingWindowMs` all must pass. Real-device test mandatory. |
| 3-finger swipe conflicts with macOS system gestures (Mission Control, spaces) | Medium | P1 | Known macOS behaviour; document in acceptance doc that system-reserved 3-finger swipes may be intercepted by macOS first. Do not attempt to fight the OS — recommend users disable the colliding system gesture if they want ours. |
| `fingerProximityThreshold` dual-use becomes contradictory | Medium | P2 | S6 evaluation is mandatory. If evaluation concludes a split is needed, S6 ships the split. If not, document why single-knob still works. |
| Gestures tab becomes visually cluttered with 4 families × several rows | Medium | P2 | Use `.formStyle(.grouped)` sections — the Phase 2.6 grouping naturally handles density. Re-evaluate mid-implementation; if still cluttered, add sub-headers, not a new UI paradigm. |
| CI cannot run `./scripts/test.sh` because no Xcode available | Low | P1 | Document the toolchain used for verification; never claim "tests pass" without naming the toolchain. `swift build` with CLI toolchain is the minimum gate. |
| `.gesturesample` regression fixtures drift from real user samples | Low | P2 | Fixture bundle is explicitly hand-authored, version-controlled, and labelled "fixture, not user sample". Real user samples remain outside `Tests/`. |
| New `GestureType` cases break existing `configStore` decoding | Low | P1 | `GestureFireConfig.gestures` is keyed on `String`; unknown keys are ignored on decode, new keys start unmapped. Roundtrip test in `ConfigPersistenceTests` if not already covered. |
| Accessibility verification surfaces a blocker | Low | P1 | S7 is in scope specifically so this gets found before acceptance, not during. Budget a tactical fix; if the fix is large, re-defer and document. |

## Deferred Items

Items discovered or confirmed deferred by this phase's spec. Every item has a target phase.

| Item | Reason Deferred | Target Phase |
|------|----------------|--------------|
| Wizard practice step for multi-finger / swipe / corner | Doubles the risk surface of Phase 3; wizard changes have historically been expensive | Phase 5 (alongside personalization polish) |
| `ShortcutField` pill restyle | Still out of visual-only scope; Phase 3 is not visual | Phase 5 |
| Slider endpoint labels | Same as above | Phase 5 |
| Multi-finger swipe usability: natural hand posture tolerance | Cluster tolerance + centroid direction too strict for natural gestures; needs Phase 4 rejection-reason data | Phase 4 (Smart Tuning) |
| `LogViewerView` alternating row tint | Requires custom row rendering outside `List` | Phase 4 (alongside log viewer expansion) |
| Onboarding step transition animation | Behavior change, not gesture vocabulary | Phase 5 |
| Card hover effects, custom dark/light specialization | Pure polish, not blocking | Phase 5 |
| `FileLogger` thread safety / force-unwrap / `LogEntry` identity | No direct contact with Phase 3 work | Phase 4 |
| `InMemoryPersistence.Storage @unchecked Sendable` | Test support only; no Phase 3 code path touches it | Phase 4 |
| `AppCoordinator.stop()` source race | In `source.stop()` path, not `RecognitionLoop` | Phase 4 |
| Gesture animation previews in onboarding | More valuable once the gesture set is final | Phase 5 |
| Sample browser / management UI | Belongs with calibration | Phase 4 |
| `GestureFireConfig.version` migration activation | Triggered by per-app profile schema change | Phase 5 |
| Unused-shortcut detection / warning | `FeedbackCorrelator` is the natural home | Phase 4 |

## Review / Retrospective

### Implementation History

| Step | Commit | Summary |
|------|--------|---------|
| 0 | `b2c74b4` | Replay regression canary + TipTap fixture bundle (4 fixtures) |
| 1 | `4f74e2c` | `Geometry.nearestCardinal` + TipTap `directionAngleTolerance` wiring |
| 2 | `b25c0d1` | `RecognitionLoop` → priority-ordered multi-recognizer array |
| 3 | `cb6b1a7` | `CornerTapRecognizer` + 4 corner tap fixtures |
| 4 | `5ff4d81` | `MultiFingerTapRecognizer` + 3 multi-finger tap fixtures |
| 5 | `449b576` | `MultiFingerSwipeRecognizer` + 8 multi-finger swipe fixtures |
| 6 | `e889322` | Settings UI extension (5 family sections, Cmd+1..5, Advanced 10-param) |
| 7 | `a3ed884` | `docs/architecture/overview.md` synced with reality |
| 8 | (uncommitted) | Accessibility verification pass — tactical fixes to StatusSettingsView + OnboardingView |
| 9 | (this step) | Phase 3 close-out: retrospective, acceptance doc |
| H1 | (hardening round 1) | `.breaking` state in active filter, static gesture instructions, conservative shared default relaxation |
| H2 | (hardening round 2) | 4 explicit dedicated multi-finger params, eliminated hidden ×3 multiplier, AdvancedSettingsView Multi-Finger section |
| H3 | (accessibility hardening) | Replaced custom `SettingsTabButton` (`.buttonStyle(.plain)`) with focusable `SettingsTabItem` using `.focusable()` + `@FocusState` + `onMoveCommand` + `onKeyPress`. Tab bar now keyboard-navigable and VoiceOver-accessible without requiring macOS "Keyboard Navigation" system setting. |

### Stats

| Metric | Before Phase 3 | After Phase 3 | Delta |
|--------|---------------|---------------|-------|
| Source LOC | ~4,455 | ~5,428 | +973 |
| Test LOC | ~2,100 | ~3,821 | +1,721 |
| Tests | 153 in 30 suites | 215 in 44 suites | +62 tests, +14 suites |
| Recognizers | 1 (TipTap) | 4 (CornerTap, MultiFingerTap, MultiFingerSwipe, TipTap) | +3 |
| GestureType cases | 4 | 19 | +15 |
| Replay fixtures | 0 | 19 (4 TipTap + 4 CornerTap + 3 MultiFingerTap + 8 MultiFingerSwipe) | +19 |
| SensitivityConfig params active | 4/10 | 14/14 (10 shared + 4 multi-finger dedicated) | +10 |
| GestureFireRecognition files | 3 | 7 | +4 |
| Settings gesture families | 1 (flat list) | 5 (TipTap / Multi-Finger Tap / 3F Swipe / 4F Swipe / Corner Tap) | +4 |

### Scope Decisions Made During Implementation

1. **`fingerProximityThreshold` single-knob decision → dedicated parameters (S6 evaluation + Round 2 hardening)**: Initially kept as a single parameter with a hidden 3× multiplier in MultiFingerTap. Real-device testing revealed multi-finger gestures were unusable with shared parameters. Round 2 hardening introduced 4 explicit dedicated parameters (`multiFingerTapDurationMs`, `multiFingerMovementTolerance`, `multiFingerSpreadMax`, `swipeClusterTolerance`) to replace all hidden multipliers and give multi-finger recognizers independent tuning knobs. The hidden `fingerProximityThreshold × 3` in MultiFingerTap was replaced by `multiFingerSpreadMax`.

2. **MultiFingerSwipe `initialCentroid` recomputation (Step 5)**: When new fingers join inside the grouping window mid-motion, `initialCentroid` is recomputed from all tracked start positions. This was the critical design insight that resolved the grouping + motion conflict identified in the risk matrix.

3. **Silent-reset vs rejection pattern**: Recognizers that see touches outside their finger-count domain (e.g. MultiFingerTap seeing 2 fingers, MultiFingerSwipe seeing 5) silently reset to idle instead of emitting a rejection. This prevents noise in the pipeline and preserves clean boundary separation between recognizer territories.

4. **`RejectionReason` as struct**: Confirmed that `RejectionReason` is a struct with a `label: String`, not an enum. New rejection labels (`fingersTooSpread`, `tapTooSlow`, `fingerMoved`, `clusterBroken`, `swipeTooSlow`, `directionAmbiguous`) were added as static factory methods without schema change.

5. **`KeyEquivalent` + `LocalizedStringKey` deprecation**: `KeyEquivalent.character` interpolated into a `LocalizedStringKey` triggers a deprecation warning. Workaround: cast to `String(...)` and use `Text(verbatim:)`. Documented in `overview.md` Implementation Notes.

### Bugs Found and Fixed

| Bug | Step | Resolution |
|-----|------|------------|
| `KeyEquivalent.character` deprecation warning in accessibility hint | 6 | `Text(verbatim: ...)` workaround |
| StatusSettingsView section headers missing `.isHeader` trait | 8 | Added `.accessibilityAddTraits(.isHeader)` |
| StatusSettingsView decorative icons read by VoiceOver | 8 | Added `.accessibilityHidden(true)` + row-level `.accessibilityElement(children: .combine)` |
| OnboardingView hero icons read by VoiceOver | 8 | Added `.accessibilityHidden(true)` to decorative ZStacks |
| OnboardingView step titles missing `.isHeader` | 8 | Added `.accessibilityAddTraits(.isHeader)` |
| StepIndicator fragments not grouped for VoiceOver | 8 | Combined per-step elements with accessibility labels + step value |
| PresetCard icon + text not cohesive for VoiceOver | 8 | Added `accessibilityLabel`, `accessibilityHint`, `.isSelected` trait |
| CalibrationRow attempt icons invisible to VoiceOver | 8 | Combined row with descriptive label including attempt count |
| Settings tab bar unreachable by Tab key and VoiceOver | H3 | `.buttonStyle(.plain)` removed buttons from macOS focus chain. Replaced with `.focusable()` + `@FocusState` + `onMoveCommand` + `onKeyPress` |

### Risks Realized

| Risk (from spec) | Occurred? | Notes |
|-------------------|-----------|-------|
| Multi-recognizer priority causes TipTap false negatives | No | Replay canary held green across all 8 steps |
| `directionAngleTolerance` changes TipTap recognition | No | Default 30° is permissive; all existing fixtures passed |
| Multi-finger misfires on palm rest | Not tested in initial implementation | Round 2 hardening with dedicated params improved real-device usability significantly |
| 3-finger swipe conflicts with macOS system gestures | Investigated — not the cause of Round 1/2 failures | Confirmed not the root cause of recognition failures; macOS system gestures were disabled during testing. Still documented as a mandatory pre-verification check for other machines. |
| `fingerProximityThreshold` dual-use contradictory | No | Single-knob worked; no split needed |
| Gestures tab visually cluttered | No | 5 family sections with `.formStyle(.grouped)` work well |
| Accessibility verification surfaces a blocker | Yes → resolved | Step 8 structural fixes were insufficient: `.buttonStyle(.plain)` removed tab bar from macOS focus chain entirely. Required H3 hardening to replace Button with `.focusable()` views + `@FocusState` + `onMoveCommand`. M4 passed after H3. |

### Carry-Over Status (from spec → resolution)

| Item | Spec Status | Final Resolution |
|------|-------------|-----------------|
| `directionAngleTolerance` wiring | In scope (S6) | ✅ Shipped in Step 1 |
| `Cmd+1..5` keyboard cycling | In scope (S6) | ✅ Shipped in Step 6 |
| Tab/VoiceOver verification | In scope (S7) | ✅ Step 8 structural fixes + H3 focusable tab bar. M4 passed. |
| `fingerProximityThreshold` dual-use evaluation | In scope (S6) | ✅ Resolved: real-device testing proved single-knob insufficient → 4 dedicated multi-finger params added in Round 2 hardening |
| `ShortcutField` pill restyle | Re-deferred | Re-deferred to Phase 5 |
| Slider endpoint labels | Re-deferred | Re-deferred to Phase 5 |
| `LogViewerView` alternating row tint | Re-deferred | Re-deferred to Phase 4 |
| Onboarding step transition animation | Re-deferred | Re-deferred to Phase 5 |
| `FileLogger` thread safety / force-unwrap | Re-deferred | Re-deferred to Phase 4 |
| `AppCoordinator.stop()` race | Re-deferred | Re-deferred to Phase 4 |
| Sample browser / management UI | Re-deferred | Re-deferred to Phase 4 |
| Gesture animation previews | Re-deferred | Re-deferred to Phase 5 |

### What Went Well

- **Replay canary as regression gate**: The Step 0 investment in replay fixtures paid off immediately — every subsequent step had an automatic safety net. The per-recognizer fixture rule ensured coverage grew monotonically.
- **Strict RED-first TDD**: Writing failing tests before implementation caught design issues early (e.g. the staggered touchdown trace in Step 4, the grouping+motion conflict in Step 5).
- **Priority-ordered recognizer array**: Simple, deterministic, and easy to reason about. No complex conflict resolution needed.
- **Step boundaries**: The 9-step plan with explicit scope fences prevented scope creep and made each step reviewable in isolation.

### Real-Device Testing Results (Post-Hardening)

#### Round 1 (conservative shared defaults + `.breaking` filter)
- ✅ 3-Finger Tap: now works
- ❌ 4-Finger Tap, 5-Finger Tap: still fails (shared defaults not relaxed enough)
- ❌ 3-Finger Swipe: still fails (cluster tolerance too tight)

#### Round 2 (4 dedicated multi-finger parameters)
- ✅ 3-Finger Tap: still works
- ✅ 4-Finger Tap: now works
- ✅ 5-Finger Tap: now works
- ✅ 3-Finger Swipe: now works

#### Usability Finding: Multi-finger swipe still sensitive to finger arrangement
After Round 2, multi-finger gestures are **functional** but not yet fully natural. Specific observation: 4-finger swipe up requires fingers to be arranged relatively evenly and close to horizontal alignment for stable triggering. Under natural hand posture, recognition is still pickier than ideal.

**Root cause analysis**: The `swipeClusterTolerance` (default 0.30) and cluster integrity check assume fingers stay within a tight radius from the centroid throughout the motion. During natural swipes, outer fingers (especially pinky and index) tend to drift further from the centroid than the current tolerance allows. Additionally, the direction calculation uses centroid displacement, which can be affected by non-uniform finger movement — if one finger leads while others lag, the centroid path is not as clean as when all fingers move in lockstep.

**Potential optimization directions** (not in Phase 3 scope):
1. Relax `swipeClusterTolerance` further or make it direction-dependent (vertical swipes may need more lateral tolerance)
2. Use per-finger displacement vectors instead of centroid-only for direction determination
3. Allow progressive cluster loosening as the swipe progresses (tight at start, looser during motion)
4. Weight centroid by finger confidence or movement coherence

**Classification**: Not a Phase 3 blocker — gestures are functional. Logged as a usability improvement for Phase 4 (Smart Tuning) where rejection-reason tracking and auto-adjust can provide data-driven tuning.

### System Gesture Conflict: Documentation and Verification Requirement

macOS system trackpad gestures can intercept multi-finger swipes before GestureFire receives the touch events. This was **investigated during testing and confirmed NOT to be the root cause** of the Round 1/2 recognition failures (system gestures were disabled on the test machine).

However, this remains a **mandatory pre-verification environmental check** for any machine running GestureFire:
- **3-finger swipe**: Conflicts with Mission Control (swipe up), App Exposé (swipe down), and Switch Spaces (swipe left/right). Path: System Settings → Trackpad → More Gestures.
- **4-finger swipe**: Conflicts with the same system gestures if the user has configured them for 4 fingers.
- **Recommendation**: Before multi-finger swipe verification, confirm that conflicting macOS system gestures are disabled or set to a different finger count.

This is documented in the Settings UI gesture family captions (added in Hardening Round 1) and in the acceptance doc (M1 prerequisites).

### What Could Be Improved

- **Accessibility was Step 8 instead of incremental**: Finding 8+ issues across two hardening rounds (Step 8 annotations + H3 focus rewrite) confirms accessibility must be part of the definition-of-done for each UI step. `.buttonStyle(.plain)` was the root cause of tab bar inaccessibility — this should have been caught when the custom tab bar was introduced in Phase 2.6.
- **Real-device testing should happen earlier**: The three hardening rounds (H1 + H2 for gestures, H3 for accessibility) were all discovered only during real-device testing at close-out. Future phases should include a real-device checkpoint mid-implementation.
- **Hidden multipliers were a design smell**: The original `fingerProximityThreshold × 3` in MultiFingerTap was expedient but violated the "all parameters explicit and tunable" principle. Round 2 fixed this, but it should have been caught during code review in Step 4.
- **Annotation != accessibility**: Adding `.accessibilityLabel` and `.isSelected` traits to a fundamentally inaccessible structure (`.plain` buttons) does not make it accessible. The structure itself must participate in the focus system.

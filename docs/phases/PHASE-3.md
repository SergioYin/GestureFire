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
| `ShortcutField` pill restyle | Phase 2.6 | **Re-deferred**. Keeps existing look in Phase 3. Target: a future visual-polish pass. |
| Slider endpoint labels | Phase 2.6 | **Re-deferred**. Same as above. |
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
| `ShortcutField` pill restyle | Still out of visual-only scope; Phase 3 is not visual | A future visual-polish pass |
| Slider endpoint labels | Same as above | A future visual-polish pass |
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

> Fill after implementation, before acceptance. Empty until then.

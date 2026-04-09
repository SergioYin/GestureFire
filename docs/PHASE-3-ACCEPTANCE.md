# Phase 3 Acceptance — More Gestures

> Status: **Accepted** (2026-04-09)
> Spec: `docs/phases/PHASE-3.md`
> Architecture: `docs/architecture/overview.md`
> Retrospective: `docs/phases/PHASE-3.md` § Review / Retrospective

## Automated Verification

### Prerequisites

```bash
cd ~/workspace/0329/GestureFire-v1
```

### 1. Clean build (CLI toolchain)

```bash
swift build
```

**Expected**: `Build complete!` with zero errors. No new warnings beyond pre-existing SMAppService exhaustive switch.

### 2. Full test suite (Xcode toolchain — required for Swift Testing framework)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

**Expected**: `215 tests in 44 suites passed` with zero failures.

### 3. Replay canary — core Phase 3 regression gate

The replay canary is the mandatory regression gate for Phase 3. It replays 19 checked-in `.gesturesample` fixtures through `RecognitionLoop.replay()` and asserts the correct gesture type is recognized.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter "MultiRecognizerReplayTests"
```

**Expected**: All 4 parameterized test cases pass (19 total fixture assertions):

| Suite | Fixtures | Expected gestures |
|-------|----------|-------------------|
| TipTap | `tiptap-left/right/up/down` | `.tipTapLeft/Right/Up/Down` |
| CornerTap | `cornertap-top-left/top-right/bottom-left/bottom-right` | `.cornerTapTopLeft/TopRight/BottomLeft/BottomRight` |
| MultiFingerTap | `multifingertap-3/4/5` | `.multiFingerTap3/4/5` |
| MultiFingerSwipe | `multifingerswipe-3-left/right/up/down`, `multifingerswipe-4-left/right/up/down` | `.multiFingerSwipe3Left/Right/Up/Down`, `.multiFingerSwipe4Left/Right/Up/Down` |

### 4. No `Date()` in recognizers

```bash
rg "Date\(\)" Sources/GestureFireRecognition/ --glob '!*.md'
```

**Expected**: Zero matches. All recognizers use `frame.timestamp` exclusively.

### 5. No `@unchecked Sendable` introduced

```bash
rg "@unchecked Sendable" Sources/GestureFireRecognition/
```

**Expected**: Zero matches.

### 6. Recognition test coverage per recognizer

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter "TipTap"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter "CornerTap"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter "MultiFingerTap"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter "MultiFingerSwipe"
```

**Expected minimum per recognizer**:

| Recognizer | Suites | Minimum tests |
|------------|--------|---------------|
| TipTap | happy path, rejections, state transitions, direction-angle tolerance | 24+ |
| CornerTap | happy path, rejections, state transitions | 14+ |
| MultiFingerTap | happy path, rejections, state transitions | 11+ |
| MultiFingerSwipe | happy path (3F + 4F), rejections, state transitions | 16+ |

## Manual Verification

### M1. New gesture recognition (real trackpad required)

**Environment prerequisite**: Before testing multi-finger swipes, confirm that conflicting macOS system gestures are disabled. Go to System Settings → Trackpad → More Gestures and disable or reassign: Mission Control (3/4-finger swipe up), App Exposé (3/4-finger swipe down), Switch Spaces (3/4-finger swipe left/right). This is NOT the root cause of prior recognition failures but will intercept touch events on machines where these are enabled.

For each gesture family, map one gesture to a visible shortcut (e.g. `Cmd+Left`) and verify:

- [x] **TipTap** (all 4 directions): hold one finger, tap another in the indicated direction → shortcut fires
- [x] **Corner Tap** (all 4 corners): single tap in a trackpad corner → shortcut fires
- [x] **Multi-Finger Tap** (3, 4, 5 fingers): quick tap with N fingers simultaneously → shortcut fires
- [x] **3-Finger Swipe** (4 directions): 3 fingers swipe in a direction → shortcut fires
- [x] **4-Finger Swipe** (4 directions): 4 fingers swipe in a direction → shortcut fires

### M2. Priority order (no cross-firing)

- [x] Corner tap in top-left → fires `cornerTapTopLeft`, does NOT fire any TipTap gesture
- [x] 3-finger stationary tap → fires `multiFingerTap3`, does NOT fire a swipe
- [x] Single TipTap left → fires `tipTapLeft`, is NOT consumed by any higher-priority recognizer
- [x] 2-finger touch → no gesture fires (2-finger domain is not handled by any Phase 3 recognizer)

### M3. Settings UI

- [x] **Cmd+1..5** switches between Feedback / Gestures / Advanced / Logs / Status tabs
- [x] **Gestures tab**: 5 family sections visible — TipTap (4 rows), Multi-Finger Tap (3 rows), 3-Finger Swipe (4 rows), 4-Finger Swipe (4 rows), Corner Tap (4 rows)
- [x] **Advanced tab**: 5 semantic sections — Timing (3 params), Precision (2 params), Multi-Finger (4 params: Tap Duration, Movement Sensitivity, Finger Spread, Swipe Group Tightness), Swipe (2 params), Corner Tap (1 param) + Repeat Delay and Direction Strictness visible
- [x] All 14 sliders have readable labels and respond to drag
- [x] "Reset to Defaults" resets all parameters
- [x] Window renders cleanly at 560×520 minimum in both light and dark mode

### M4. Accessibility (Tab + VoiceOver)

**Status**: ✅ **Passed** (2026-04-09). Step 8 applied structural annotations (`.isHeader`, `.accessibilityHidden`, `.accessibilityElement(children: .combine)`). H3 hardening replaced `.buttonStyle(.plain)` tab buttons with `.focusable()` views using `@FocusState` + `onMoveCommand` + `onKeyPress`, making the tab bar keyboard-navigable and VoiceOver-accessible.

- [x] **Tab key** can sequentially reach all main interactive elements in the Settings tab bar
- [x] **Tab key** can reach interactive elements within each tab's content without dead zones
- [x] **VoiceOver** reads the custom tab bar (tab names + selected state)
- [x] **VoiceOver** reads Status tab content
- [x] **VoiceOver** reads gesture mapping sections
- [x] **VoiceOver** reads Advanced slider labels with value and unit
- [x] **VoiceOver** reads Onboarding screens

### M5. Regression — existing Phase 2.6 functionality

- [x] Sound feedback plays on gesture recognition (Settings → Feedback → enable sound)
- [x] Status panel appears showing gesture name + shortcut
- [x] Status panel auto-dismisses without stealing focus
- [x] Launch at login toggle works in Settings → Feedback
- [x] Log viewer shows entries with date picker and gesture filter
- [x] Onboarding wizard completes full Permission → Preset → Practice → Confirm flow

## Known Limitations (Non-Blocking)

### 1. macOS system gesture conflicts (environment-dependent)
macOS uses 3- and 4-finger swipes for Mission Control, App Exposé, and Spaces by default. If enabled in System Settings → Trackpad → More Gestures, the OS intercepts the gesture before GestureFire sees it. **Investigated during real-device testing and confirmed NOT the root cause of recognition failures** — system gestures were disabled on the test machine. However, this remains a **mandatory pre-verification environmental check** on any new machine. **Recommendation**: Disable conflicting macOS system gestures before using GestureFire multi-finger swipes.

### 2. Multi-finger swipe sensitive to finger arrangement (usability finding)
After Round 2 hardening, multi-finger gestures are **functional** — 4F Tap, 5F Tap, and 3F Swipe all trigger reliably. However, certain gestures (notably 4-finger swipe up) require relatively even finger spacing and near-horizontal alignment for stable triggering. Natural hand posture with splayed or staggered fingers reduces recognition reliability.

**Root cause**: `swipeClusterTolerance` and centroid-based direction calculation assume uniform finger movement. Potential optimizations (relaxed tolerance curves, per-finger displacement vectors, progressive cluster loosening) are deferred to Phase 4 Smart Tuning.

### 3. No real-device validation in automated tests
All multi-finger recognizers are tested against synthetic fixtures. Real trackpad behavior (finger pressure, palm rejection, sensor noise) may differ. Manual verification (M1) is mandatory.

### 4. Custom tab bar required focusable rewrite for accessibility (resolved)
The original `.buttonStyle(.plain)` tab bar was invisible to macOS keyboard focus and VoiceOver. Step 8 annotations alone were insufficient — H3 hardening replaced Button-based tabs with `.focusable()` views using `@FocusState` + `onMoveCommand` + `onKeyPress`. M4 now passed. Lesson: annotations cannot fix a structurally inaccessible control.

### 5. Onboarding Practice step does not include new gesture types
The Phase 1.5 practice wizard only calibrates TipTap gestures. Multi-finger tap, swipe, and corner tap are not tested during onboarding. Users must configure and test these from Settings. Deferred to Phase 5.

### 6. `ShortcutField` visual style unchanged
The existing plain text-field style is preserved. A pill/tag restyle is deferred to a future visual-polish phase.

## Carry-Over Items

Every item has an explicit target phase. No unphased entries.

| Item | Source Phase | Target Phase | Priority | Notes |
|------|-------------|-------------|----------|-------|
| Multi-finger swipe usability: natural hand posture tolerance | Phase 3 real-device testing | Phase 4 | P1 | Cluster tolerance + centroid direction too strict for natural gestures; needs rejection-reason data to guide tuning |
| Smart tuning / rejection-reason tracking / auto-adjust | Phase 3 spec (Out of Scope) | Phase 4 | P1 | Core Phase 4 feature |
| Sample browser / management UI | Phase 1.5 | Phase 4 | P2 | Belongs with calibration work |
| Real sample-based calibration (parameter search) | Phase 3 spec (Out of Scope) | Phase 4 | P2 | Requires sample browser |
| Unused-shortcut detection / warning | Phase 2.6 | Phase 4 | P1 | `FeedbackCorrelator` natural home |
| `FileLogger` thread safety + force-unwrap fix | Phase 2 | Phase 4 | P2 | No Phase 3 contact |
| `LogEntry` UUID identity | Phase 2 | Phase 4 | P3 | Log viewer expansion prerequisite |
| `InMemoryPersistence.Storage @unchecked Sendable` | Phase 2 | Phase 4 | P3 | Test support only |
| `AppCoordinator.stop()` race | Phase 2 | Phase 4 | P2 | In `source.stop()` path |
| `LogViewerView` alternating row tint | Phase 2.6 | Phase 4 | P3 | Requires custom row rendering |
| SwiftUI view snapshot tests | Phase 2 | Phase 4 | P3 | Phase 3 UI additions are section-level |
| Per-application profiles + frontmost-app detection | Phase 3 spec (Out of Scope) | Phase 5 | P1 | Core Phase 5 feature |
| `GestureFireConfig.version` migration activation | Phase 2 | Phase 5 | P2 | Triggered by profile schema |
| Config import/export / cloud sync | Phase 3 spec (Out of Scope) | Phase 5 | P2 | Alongside profiles |
| Onboarding practice step for new gesture types | Phase 3 spec (Out of Scope) | Phase 5 | P2 | Risk reduction: separate from recognizer work |
| Gesture animation previews in onboarding | Phase 1.5 | Phase 5 | P3 | Personalization polish |
| Onboarding step transition animation | Phase 2.6 | Phase 5 | P3 | Behavior change, not gesture vocabulary |
| Card hover effects / dark-light specialization | Phase 2.6 | Phase 5 | P3 | Pure polish |
| `ShortcutField` pill restyle | Phase 2.6 | Phase 5 | P3 | Alongside personalization polish |
| Slider endpoint labels | Phase 2.6 | Phase 5 | P3 | Alongside personalization polish |

## Decision: Proceed to Phase 4?

**Decision**: **Yes — proceed to Phase 4.** All automated gates green (215 tests, 19-fixture replay canary, zero `Date()` / `@unchecked Sendable`). Manual acceptance M1–M5 all passed (2026-04-09). Phase 3 is formally closed.

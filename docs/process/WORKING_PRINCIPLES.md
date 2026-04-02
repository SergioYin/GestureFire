# Working Principles

Principles validated through Phase 1 / 1H / 1.5 development. Each principle has a concrete rationale from project history — not abstract engineering advice.

## 1. Stability Over Features

GestureFire's value proposition is "set it and forget it" reliability. A misfire (wrong shortcut triggered) or false negative (gesture ignored) erodes trust faster than a missing feature. Every phase prioritizes recognition correctness and permission robustness before adding new capabilities.

**Evidence**: Phase 1H found that a single lift-detection bug (`.breaking` state not handled) made TipTap completely non-functional. Phase 1.5 found two-finger swipe misrecognition that would fire unintended shortcuts during normal trackpad use. Both were invisible in unit tests with synthetic fixtures — only discovered through real trackpad usage.

**Implication**: Real-device verification is mandatory before any phase closes. Fixture-only testing is necessary but not sufficient.

## 2. OMS Dependency Must Be Isolated

`OpenMultitouchSupport` is a private framework with no documentation, no stability guarantees, and no way to construct test objects. Only `GestureFireIntegration` imports it. Every other target works with `TouchFrame` — a pure `Sendable` value type.

**Evidence**: All recognition tests (~80+) run without OMS, without a trackpad, and without accessibility permissions. This isolation made TDD practical for the recognizer: red-green-refactor cycles take seconds, not manual gesture attempts.

**Implication**: New recognizers (Phase 3) must accept `TouchFrame`, never `OMSTouchData`. If OMS changes its API or gets removed, only `TouchFrameAdapter` and `OMSTouchSource` need updating.

## 3. `TouchFrame.timestamp` Is the Only Time Authority

Recognizers never call `Date()` or any system clock. All duration calculations (hold threshold, tap duration, cooldown) use `frame.timestamp` differences.

**Evidence**: This decision was made upfront in the architecture plan. It paid off immediately: `SamplePlayer` replays recorded frames with their original timestamps, and recognition produces identical results to live input. Unit tests construct frames with precise timestamp control — no flaky timing.

**Implication**: Any new recognizer or timing-dependent logic must follow this rule. If you find `Date()` inside a recognizer, it's a bug.

## 4. Recognizers Are Structs, Owned by Actor

Each recognizer is a `struct` with an explicit `enum State`. The `RecognitionLoop` actor is the sole owner — recognizers are never shared across isolation domains.

**Evidence**: v0.2 used `class TipTapRecognizer: @unchecked Sendable` with 4 mutable vars. That design led to crashes under concurrent access. v1's struct approach eliminated all data race issues and made state transitions directly testable via pattern matching on `.idle` / `.tracking(...)` / `.cooldown(...)`.

**Implication**: New recognizers (Phase 3) must be structs conforming to `GestureRecognizer` protocol. They register in `RecognitionLoop`'s array and share no mutable state with anything else.

## 5. Permission Check vs Request Must Be Strictly Separated

- **Check**: `AXIsProcessTrusted()` — read-only, no UI side effects, safe to call in tight loops
- **Request**: `AXIsProcessTrustedWithOptions(prompt: true)` — opens System Settings, steals app focus

**Evidence**: Phase 1H had a P0 bug where the diagnostic polling loop called the request function every 2 seconds, spamming system dialogs. The fix was architectural: `DiagnosticChecking` protocol only exposes `checkAccessibility()`. The prompt function is a standalone free function, callable only from explicit user button taps.

**Implication**: Any new code that needs to know permission status must use `AXIsProcessTrusted()`. The prompt function must never appear in a loop, timer, or automatic flow.

## 6. UI-Exposed Parameters Must Match Real Logic

If a parameter appears in Settings UI, it must actually affect recognition behavior. If it doesn't, either wire it or remove it from the UI.

**Evidence**: `directionAngleTolerance` exists in `SensitivityConfig`, is editable in Settings, and persists to config — but `computeDirection()` ignores it entirely. Users can change the value and see no effect. This was caught during review and explicitly documented as a carry-over to Phase 3, with the architecture overview marking it as "NOT WIRED".

**Implication**: When adding new parameters, wire them into recognition logic in the same PR. If the recognizer isn't ready, don't expose the parameter in UI. The architecture overview's parameter status table (`docs/architecture/overview.md` §5) is the source of truth.

## 7. Samples Are Long-Lived Assets

`.gesturesample` files are not disposable test artifacts. They serve three purposes:
1. **Regression testing**: After parameter changes, replay samples to verify no regressions
2. **Bug reproduction**: Attach sample files to bug reports for exact replay
3. **Future calibration**: Phase 4 will use sample libraries to auto-compute optimal sensitivity parameters

**Evidence**: Phase 1.5 wired sample recording into the calibration lifecycle: each successful gesture attempt produces a sample file. `SamplePlayer` + `RecognitionLoop.replay()` already support deterministic playback. The infrastructure exists — the samples themselves are the growing asset.

**Implication**: Sample format changes must be backward-compatible or include migration. Sample files should not be casually deleted. Phase 2 will add a management UI; Phase 4 will build calibration on top of the sample library.

## 8. macOS Window Lifecycle Requires Upfront Research

Menu-bar apps on macOS have non-obvious window management behavior. SwiftUI `Window` scenes don't auto-present. `NSPanel` auto-minimizes on focus loss. Agent apps (`.accessory` policy) hide all windows when another app activates. Permission dialogs steal focus.

**Evidence**: Phase 1.5 went through 5 iterations to get the onboarding wizard window working correctly. Each iteration discovered a new macOS behavior that wasn't documented in Apple's guides. The final solution uses `NSWindow` (not NSPanel), permanent `.regular` activation policy, and `applicationDidBecomeActive` to restore the wizard after System Settings steals focus.

**Lesson**: Before implementing any new window or panel (e.g., Phase 2 status feedback panel), research the specific window type's behavior with focus changes, activation policies, and other-app interactions. Test the window lifecycle before building the content.

## 9. Build and Test After Every Change

No exceptions. "I'll test it later" leads to accumulated breakage that's harder to diagnose.

**Evidence**: Mid-Phase 1.5, several changes accumulated without building or testing. When the build was finally run, multiple issues were entangled. This was caught by user review and flagged as a process failure.

**Implication**: `swift build` after every code change. `scripts/test.sh` (which switches to Xcode toolchain) for test verification. If the build breaks, fix it before moving to the next task.

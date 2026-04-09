# GestureFire

Custom macOS trackpad gestures for keyboard shortcuts.

[中文说明](README.zh-CN.md) | [日本語](README.ja.md)

GestureFire is a macOS menu bar app for creating custom trackpad gestures that trigger keyboard shortcuts. It supports TipTap, corner tap, multi-finger tap, and multi-finger swipe, with replay-backed testing and a growing tuning pipeline.

## Why GestureFire

macOS gives you a fixed set of trackpad gestures. GestureFire is for people who want their own:

- Trigger app shortcuts from custom gestures
- Use corner taps and multi-finger gestures beyond the built-in macOS set
- Tune gesture sensitivity instead of accepting one-size-fits-all behavior
- Keep recognition logic testable with replay fixtures and deterministic timing

This project has reached its MVP milestone at the end of Phase 3.

## What You Can Do Today

- Map **19 gesture types** to keyboard shortcuts
- Use **4 recognizers**: `TipTap`, `CornerTap`, `MultiFingerTap`, `MultiFingerSwipe`
- Configure gestures from a menu bar app
- Walk through first-run onboarding and practice
- Inspect diagnostics, logs, sound feedback, and status panel behavior
- Run **215 tests across 44 suites**
- Protect recognition changes with **19 replay fixtures**

## Gesture Families

- **TipTap**: 4 directional gestures
- **Corner Tap**: top-left, top-right, bottom-left, bottom-right
- **Multi-Finger Tap**: 3-finger, 4-finger, 5-finger
- **Multi-Finger Swipe**: 3-finger and 4-finger swipes in 4 directions

## Who This Is For

- macOS power users
- developers who live on the trackpad
- people who want custom trackpad shortcuts without a giant automation suite
- anyone interested in gesture recognition, replay-based testing, and tuning systems

## Current MVP Status

GestureFire is now a solid MVP:

- core recognition pipeline implemented
- real-device validation completed
- accessibility baseline verified for the current Settings flow
- advanced sensitivity controls in place
- replay-based regression safety established

Known limitations:

- multi-finger swipe still benefits from deliberate finger alignment
- macOS system gestures can conflict with 3- and 4-finger swipes
- onboarding practice currently focuses on TipTap only

These are tracked as later-phase improvements rather than blocking the MVP milestone.

## Quick Start

### Requirements

- macOS 14+
- Xcode installed at `/Applications/Xcode.app`

### Build

```bash
swift build
./scripts/build-app.sh debug
open dist/GestureFire.app
```

Release app bundle:

```bash
./scripts/build-app.sh release
```

### Test

Swift Testing requires Xcode's bundled toolchain:

```bash
./scripts/test.sh
```

Equivalent direct command:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Project Structure

- `Sources/GestureFireRecognition` — recognizers and replay loop
- `Sources/GestureFireEngine` — coordinator, diagnostics, logging, onboarding, launch-at-login
- `Sources/GestureFireApp` — SwiftUI app, settings, status, onboarding UI
- `Sources/GestureFireTypes` — shared models and configuration
- `Tests/GestureFireRecognitionTests/Fixtures/samples` — checked-in replay fixtures

## Documentation

- [ROADMAP](ROADMAP.md)
- [REVIEW](REVIEW.md)
- [Architecture Overview](docs/architecture/overview.md)
- [Phase 3 Spec](docs/phases/PHASE-3.md)
- [Phase 3 Acceptance](docs/PHASE-3-ACCEPTANCE.md)

## Roadmap Snapshot

- Phase 1: Core Loop — done
- Phase 1H: Hardening — done
- Phase 1.5: Onboarding + Verification + Sample Capture — done
- Phase 2: Experience Polish — done
- Phase 2.5: UI Structure Polish — done
- Phase 2.6: Visual Polish — done
- Phase 3: More Gestures — done
- Phase 4: Smart Tuning — next
- Phase 5: Personalization — planned

## Technical Notes

GestureFire depends on OpenMultitouchSupport for raw trackpad input. Recognition code stays isolated from OMS-specific APIs through the `TouchFrame` abstraction, which also enables deterministic replay tests and future calibration work.

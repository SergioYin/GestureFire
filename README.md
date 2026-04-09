# GestureFire

GestureFire is a macOS menu bar app for trackpad gesture recognition and keyboard shortcut triggering.

It reached its MVP milestone at the end of Phase 3:

- 4 recognizers: `TipTap`, `CornerTap`, `MultiFingerTap`, `MultiFingerSwipe`
- 19 gesture types
- Onboarding, diagnostics, sound feedback, status panel, logs, launch-at-login
- Replay-based regression safety with checked-in `.gesturesample` fixtures
- 215 tests across 44 suites

## What It Does

GestureFire listens to trackpad touch data, recognizes configured gestures, and sends mapped keyboard shortcuts to the foreground app.

Current gesture families:

- TipTap: 4 directions
- Corner Tap: 4 corners
- Multi-Finger Tap: 3 / 4 / 5 fingers
- Multi-Finger Swipe: 3 / 4 fingers x 4 directions

## MVP Status

This repository currently represents a solid MVP:

- Core recognition pipeline is implemented
- Real-device validation has been completed
- Settings and advanced tuning UI are in place
- Accessibility baseline for the current UI has been verified

Known limitations:

- Multi-finger swipe is still somewhat sensitive to finger arrangement
- macOS system gestures can conflict with 3- and 4-finger swipes
- Onboarding practice currently focuses on TipTap only

These are tracked in later phases rather than blocking the MVP milestone.

## Requirements

- macOS 14+
- Xcode installed at `/Applications/Xcode.app`

## Build

From the project root:

```bash
swift build
./scripts/build-app.sh debug
open dist/GestureFire.app
```

Release app bundle:

```bash
./scripts/build-app.sh release
```

## Test

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

## Notes

GestureFire depends on OpenMultitouchSupport for raw trackpad input. Recognition code stays isolated from OMS-specific APIs through the `TouchFrame` abstraction, which is also what enables deterministic replay tests.

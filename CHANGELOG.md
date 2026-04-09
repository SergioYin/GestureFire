# Changelog

## v1.0.0 - 2026-04-09

This release marks the MVP milestone for GestureFire.

### Added

- TipTap, CornerTap, MultiFingerTap, and MultiFingerSwipe recognizers
- 19 total gesture types
- Replay regression canary with 19 checked-in `.gesturesample` fixtures
- Onboarding wizard with practice and sample capture
- Sound feedback, floating status panel, log viewer, and launch-at-login
- Advanced tuning UI with 14 gesture parameters

### Improved

- Recognition loop evolved to a priority-ordered multi-recognizer pipeline
- Accessibility hardening for Settings, Status, and Onboarding surfaces
- Settings reorganization and visual polish through Phase 2.5 and Phase 2.6
- Multi-finger gesture hardening through dedicated tuning parameters

### Verified

- `swift build` passes
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passes
- 215 tests in 44 suites
- 19 replay fixtures green
- Real-device manual acceptance passed for Phase 3

### Known Limitations

- Multi-finger swipe still benefits from deliberate finger alignment
- macOS system gestures can conflict with multi-finger swipes
- Onboarding practice currently covers TipTap only

### Next

- Phase 4: Smart Tuning
- Feedback-aware calibration
- Replay-backed tuning suggestions
- Sample browser and management

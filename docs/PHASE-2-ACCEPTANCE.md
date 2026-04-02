# Phase 2 Acceptance Checklist

## Preparation

```bash
cd ~/workspace/0329/GestureFire-v1
swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Automated Checks

- [ ] `swift build` passes (clean build, no warnings except SMAppService exhaustive switch)
- [ ] 153 tests in 30 suites pass (toolchain: Xcode via `DEVELOPER_DIR`)
- [ ] No regression in existing 135+ tests from Phase 1.5

## Manual Checks — Sound Feedback

- [ ] Perform TipTap gesture → hear "Tink" sound
- [ ] Open Settings → General tab → disable "Play sound on gesture recognition" → perform gesture → no sound
- [ ] Re-enable sound → adjust volume slider → perform gesture → volume changes audibly
- [ ] Sound does not cause any perceptible delay in shortcut execution

## Manual Checks — Status Panel

- [ ] Perform TipTap gesture with mapped shortcut → floating panel appears near top-right showing gesture name + shortcut
- [ ] Panel auto-dismisses after ~3 seconds
- [ ] Panel does NOT steal focus — can continue typing in current app while panel is visible
- [ ] Panel does NOT appear for rejected gestures (e.g., random trackpad touches)
- [ ] Panel does NOT appear during onboarding Practice step
- [ ] Open Settings → General tab → disable "Show floating panel" → perform gesture → no panel (sound still plays if enabled)
- [ ] Perform unmapped gesture → panel shows "recognized" (not "shortcut fired")

## Manual Checks — Log Viewer

- [ ] Open Settings → Logs tab → see today's entries (if any gestures were performed)
- [ ] Select a past date → entries for that date shown (or "No Entries" message)
- [ ] Use gesture type filter dropdown → only matching entries displayed
- [ ] Click refresh button → entries reload
- [ ] Entry count shown in toolbar matches visible entries
- [ ] Manually corrupt a line in `~/.config/gesturefire/logs/YYYY-MM-DD.jsonl` → log viewer still loads, skips bad line, does not crash

## Manual Checks — Launch-at-Login

- [ ] Open Settings → General tab → toggle "Launch at login" ON
- [ ] If `requiresApproval` message appears: go to System Settings → General → Login Items → approve GestureFire
- [ ] Log out and log in → GestureFire starts automatically
- [ ] Toggle "Launch at login" OFF → log out and log in → GestureFire does not start

## Manual Checks — Menu Bar

- [ ] Menu bar title displays engine state and gesture count (e.g., "GestureFire (Running · 5)")
- [ ] Gesture count in menu bar title updates live as gestures are recognized

## Manual Checks — Sample Save Failure

- [ ] Make `~/.config/gesturefire/samples/` read-only: `chmod 444 ~/.config/gesturefire/samples/`
- [ ] Run Setup Wizard → Practice step → perform gesture → inline warning message appears about save failure
- [ ] Restore permissions: `chmod 755 ~/.config/gesturefire/samples/`

## Known Limitations (not blocking)

- UI views (StatusPanelView, LogViewerView, GeneralSettingsView) have no unit tests — SwiftUI views are hard to test without ViewInspector
- LogEntry uses array index as List identity — animations may be imperfect on filter changes
- Launch-at-login may show error in unsigned debug builds (works correctly in .app bundle)
- `FileLogger.log()` has a force-unwrap on UTF-8 encoding (safe but not idiomatic)

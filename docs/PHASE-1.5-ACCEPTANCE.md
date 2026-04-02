# Phase 1.5 Acceptance Checklist

## Prerequisites

- [ ] `swift build` succeeds with zero errors
- [ ] `swift test` passes all suites (requires Xcode toolchain for Swift Testing)

## 1. First Launch — Onboarding Auto-Open

- [ ] Delete `~/.config/gesturefire/config.json` (simulate fresh install)
- [ ] Launch GestureFire — onboarding wizard opens automatically
- [ ] Wizard title: "Welcome to GestureFire"
- [ ] Step indicator shows 4 steps: Permission → Preset → Practice → Confirm
- [ ] Dock icon visible (not agent-only app)

## 2. Step 1: Permission

- [ ] Shows "Accessibility Permission" with explanation text
- [ ] "Grant Access" button visible
- [ ] Click "Grant Access" → System Settings opens to Privacy & Security → Accessibility
- [ ] Wizard window stays visible (does not minimize or disappear)
- [ ] If user switches to System Settings then back, wizard returns to front
- [ ] After toggling GestureFire ON in System Settings → wizard shows "Permission Granted" checkmark
- [ ] "Next" button becomes enabled
- [ ] **Denial flow**: If user doesn't grant within ~30s → state resets to "Denied" with "Try Again" option
- [ ] Clicking "Try Again" → returns to "Grant Access" button state

## 3. Step 2: Preset Selection

- [ ] Shows 3 preset cards: Browser Navigation, IDE Shortcuts, Window Management
- [ ] Each card shows icon, name, description
- [ ] Clicking a card highlights it (blue border + background)
- [ ] Below cards: mapping table shows gesture → shortcut pairs for selected preset
- [ ] "Next" button disabled until a preset is selected
- [ ] "Back" button returns to Permission step

## 4. Step 3: Practice (Calibration)

- [ ] Shows "Practice Gestures" with instruction text
- [ ] "Start Practice" button visible
- [ ] Click "Start Practice" → calibration grid appears (4 gestures × 3 attempts)
- [ ] Current gesture indicated with arrow marker
- [ ] **Correct gesture**: fills a green checkmark circle
- [ ] **Wrong gesture**: fills a red X circle
- [ ] **Shortcut suppression**: performing gestures during practice does NOT fire keyboard shortcuts (no Cmd+W etc.)
- [ ] After 3 attempts per gesture, automatically advances to next gesture
- [ ] After all gestures: "All gestures verified!" green label appears
- [ ] Sample count displayed: "N sample(s) recorded"
- [ ] **Sample files**: `~/.config/gesturefire/samples/` contains `.gesturesample` files
- [ ] "Skip" button available to skip practice entirely
- [ ] "Next" button available after calibration completes (or if skipped)

## 5. Step 4: Confirm

- [ ] Shows "Ready to Go!" with green checkmark seal
- [ ] Displays selected preset name and full mapping table
- [ ] If calibration passed: shows "All gestures verified" label
- [ ] "Start GestureFire" button (large, default action)
- [ ] Click "Start GestureFire" → wizard closes, engine starts, menu bar icon active
- [ ] Config saved: `~/.config/gesturefire/config.json` has `hasCompletedOnboarding: true` and selected preset mappings

## 6. Re-Open Wizard from Menu Bar

- [ ] Click menu bar icon → dropdown appears
- [ ] Click "Setup Wizard..." → wizard window opens (after ~200ms delay)
- [ ] Wizard loads with current config (selected preset pre-filled, permission step skipped if already granted)
- [ ] Can complete wizard again → config updated
- [ ] Closing wizard via window X button → wizard dismissed, no crash

## 7. Returning User Flow

- [ ] With existing config (hasCompletedOnboarding: true), wizard opens at Preset step (skips Permission)
- [ ] Previously selected preset is pre-selected in the card grid
- [ ] For custom mappings (not matching any preset): shows "Custom" preset with current config

## 8. Sample Recording Integrity

- [ ] Each successful calibration attempt creates one `.gesturesample` file
- [ ] File is valid JSON with structure: `{ "gesture": "...", "sensitivity": {...}, "frames": [...] }`
- [ ] Each frame has: `timestamp`, `points` array with `id`, `position` [x, y], `state`
- [ ] Failed attempts do NOT create sample files (recording cancelled)
- [ ] Skipping calibration does NOT create partial sample files

## 9. Engine Safety

- [ ] Engine doesn't crash when Practice starts (no duplicate OMSTouchSource)
- [ ] Starting engine while already running is a no-op
- [ ] Completing wizard while engine is running keeps it running (no restart)
- [ ] Completing wizard while engine is stopped starts it

## 10. Edge Cases

- [ ] Close wizard via X button during any step → no crash, can reopen
- [ ] Switch between steps freely with Back/Next → no state corruption
- [ ] Rapid repeated "Setup Wizard..." clicks → only one window opens
- [ ] App regains focus after System Settings → wizard window restored

## Known Limitations (Not Blocking)

- **Gesture animation previews**: Not implemented. Text instructions only.
- **Auto sensitivity calculation**: Calibration validates but doesn't auto-tune parameters. Deferred to Phase 4.
- **`directionAngleTolerance`**: Exists in config but not used by recognizer. Deferred to Phase 3.
- **Two-finger swipe misrecognition**: Designed fix (fingerProximityThreshold check) not yet applied. P1 fix queued.
- **Swift Testing in CLI toolchain**: `swift test` requires Xcode. CLI-only environment gets `no such module 'Testing'`.

# Implementation Playbook

Rules for model/implementer collaboration on GestureFire. This document can be included in implementation prompts directly.

---

## Scope Discipline

**Do not cross phase boundaries.** Each phase has a spec (`docs/phases/PHASE-{N}.md`). Implement exactly what's in scope. If you discover something that should be done but isn't in scope, add it to Deferred Items — don't implement it.

**Evidence**: Phase 1.5 correctly deferred gesture animation previews and auto-calibration despite them being in the original spec. This kept the phase focused and closable.

**Do not "improve" surrounding code.** A bug fix doesn't need nearby refactoring. A new feature doesn't need extra configurability. Don't add docstrings, comments, or type annotations to code you didn't change.

## Verification Requirements

### After every code change

```bash
swift build    # must pass, no exceptions
```

### After every feature completion

```bash
scripts/test.sh    # runs swift test with Xcode toolchain
```

If `scripts/test.sh` cannot run (no Xcode, CI environment), document explicitly:
- Which toolchain was available
- Which test suites were verified
- What remains unverified

**Never say "tests pass" without specifying the environment.** "Tests pass" means nothing if `swift test` silently skipped suites due to toolchain issues.

### Before phase close

Manual verification on real hardware:
- Real trackpad gestures (not just fixture-based tests)
- macOS permission grant/deny flows
- Window lifecycle (open, close, focus loss, reopen)
- Edge cases specific to the phase

Generate an acceptance checklist (`docs/PHASE-{N}-ACCEPTANCE.md`) with separate sections for automated and manual checks.

## High-Risk Areas

These areas have caused P0/P1 bugs in previous phases. Verify them first, not last.

### macOS Accessibility Permissions
- `AXIsProcessTrusted()` (check) vs `AXIsProcessTrustedWithOptions(prompt:)` (request) must never be confused
- Permission polling must use check-only. Request only on explicit user button tap.
- Binary path changes on rebuild invalidate old permissions — test with fresh permission state
- Test both grant and deny flows

### Window Lifecycle (Menu Bar Apps)
- SwiftUI `Window` scenes don't auto-present in menu-bar apps
- `NSPanel` auto-minimizes when another app activates
- Agent apps (`.accessory` policy) hide windows on deactivation
- `orderFrontRegardless()` works when `makeKeyAndOrderFront` doesn't
- Always test: open window → switch to another app → switch back. Does it survive?

### Sample Persistence
- `SampleRecorder.finishRecording()` can fail (disk full, permissions, encoding)
- Failed recordings must be cancelled, not left in partial state
- Sample files must be valid JSON — verify with `SamplePlayer` roundtrip
- File naming must handle concurrent/rapid saves (UUID suffix)

### Engine State Machine
- `start()` on an already-running engine must be a no-op (not create duplicate sources)
- `stop()` must cancel all tasks and nil all references
- State transitions: `.disabled` → `.starting` → `.running` / `.failed` / `.needsPermission`
- Shortcuts must not fire during calibration (`isCalibrating` check)

### Swift 6 Concurrency
- No `@unchecked Sendable` — if the compiler complains, fix the design
- `DispatchQueue.main.asyncAfter` closures are not `@MainActor`-isolated — use `Task` instead
- Unstructured `Task {}` must be tracked and cancelled in `stop()` / `deinit`

## Deferred Items

Every deferred item must have:
1. **What**: Clear description of what's not done
2. **Why**: Why it was deferred (not needed yet, too risky, out of scope)
3. **Where**: Target phase assignment (Phase 2, Phase 3, etc.)
4. **Impact**: What breaks or degrades if this stays unimplemented

Items without a target phase assignment are not accepted. "Later" or "TBD" is not a valid assignment.

## Documentation Updates

Documentation is not optional. Each phase produces:

| Document | When | Content |
|----------|------|---------|
| `REVIEW.md` (new section) | After hardening, before acceptance | Stats, decisions, bugs, carry-over |
| `docs/architecture/overview.md` | If data flow / types / concurrency changed | Updated diagrams, parameter table |
| `docs/PHASE-{N}-ACCEPTANCE.md` | Before user acceptance | Testable checklist |
| Plan file | After scope changes or carry-over | Updated phase table, future phase notes |

## Commit Practices

- Commit after each significant feature, not in batches
- Commit message explains **why**, not just **what**
- If a commit fixes a bug, name the root cause in the message
- Never commit `.env`, credentials, or user-specific paths

## Communication Style

- Lead with the action or result, not the reasoning
- Don't summarize what you just did — the diff is visible
- When proposing a plan: what you'll do, in what order, what the verification step is
- When reporting a bug: observed behavior, expected behavior, root cause, fix
- When deferring: what, why, target phase — one line each

## Checklist Before Declaring "Phase Complete"

- [ ] All scope items implemented and committed
- [ ] `swift build` passes
- [ ] `scripts/test.sh` passes (or environment limitation documented)
- [ ] Real-device manual testing done
- [ ] High-risk areas verified (permissions, windows, engine state, samples)
- [ ] `REVIEW.md` updated with phase section
- [ ] `docs/architecture/overview.md` updated if needed
- [ ] All deferred items have target phase assignments
- [ ] Acceptance checklist generated
- [ ] User has run acceptance and confirmed pass

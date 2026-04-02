# Phase Workflow

Step-by-step process for executing any GestureFire development phase. Extracted from Phase 1 / 1H / 1.5 experience.

## Overview

```
Kickoff → Scope Lock → TDD Implementation → Hardening → Docs & Review → Acceptance → Close
```

Each step has concrete entry/exit criteria. Phases do not overlap — finish one before starting the next.

---

## Step 1: Kickoff

**Input required before starting**:
- Previous phase fully closed (committed, reviewed, acceptance checklist passed)
- Carry-over items from previous phases collected (check `REVIEW.md` "Known Issues and Carry-Over Items" section)
- User has confirmed phase scope and priorities

**Actions**:
1. Copy `docs/process/PHASE_TEMPLATE.md` → `docs/phases/PHASE-{N}.md`
2. Fill in Goal, Scope, Out of Scope, Technical Preconditions
3. Review carry-over items — assign each to this phase or defer explicitly
4. List Deliverables and Verification Criteria
5. Identify Risks (especially macOS-specific: permissions, windows, focus)
6. Get user sign-off on the filled template before writing code

**Exit**: User approves the phase spec. No code has been written yet.

## Step 2: Scope Lock

**Rule**: Once the phase spec is approved, no feature additions during implementation. If a new idea comes up:
- If small and directly related: note it, discuss with user, add only if approved
- If unrelated or large: add to Deferred Items in the phase doc, assign to a future phase
- Never silently expand scope

**Evidence**: Phase 1.5 originally included gesture animation previews and auto-calibration. Both were correctly deprioritized during implementation — they didn't block the core deliverable.

## Step 3: TDD Implementation

**Process per feature**:
1. Write failing test (RED)
2. Implement minimal code to pass (GREEN)
3. Refactor if needed (IMPROVE)
4. `swift build` — must pass
5. `scripts/test.sh` — must pass (or document why not, e.g., Xcode toolchain)
6. Commit with descriptive message

**Boundaries**:
- One feature at a time. Finish and commit before starting the next.
- Don't modify code you haven't read.
- Don't add parameters to UI unless they're wired to real logic (Principle §6).
- New recognizers must be structs accepting `TouchFrame` (Principle §2, §4).
- All timing logic uses `frame.timestamp` (Principle §3).

**Build discipline**: `swift build` after every code change. No batching multiple changes before building.

## Step 4: Hardening

**When to enter hardening**: All planned features are implemented and committed. Tests pass. Basic manual verification done.

**Hardening checklist**:
- [ ] Real-device testing (actual trackpad, not just fixtures)
- [ ] macOS-specific edge cases (permission grant/deny, focus loss, window lifecycle)
- [ ] Error paths (what happens when things fail — permissions denied, files can't be written, engine already running)
- [ ] Code review (use code-reviewer agent): fix CRITICAL and HIGH, document MEDIUM+ as carry-over if deferred
- [ ] Concurrency audit: no `@unchecked Sendable`, no data races, no unstructured tasks without cleanup

**Evidence**: Phase 1H was a dedicated hardening pass that found 4 HIGH issues (including `@unchecked Sendable` on OMSTouchSource and silent `try?` on persistence). Phase 1.5 hardening found 6 P0/P1 bugs in window lifecycle and calibration safety.

## Step 5: Documentation & Review

**Required updates after implementation + hardening**:

1. **`REVIEW.md`**: Add a new section for the phase:
   - Scope summary
   - Stats (files, LOC, commits, new types)
   - What was delivered
   - Bugs found and fixed (with root cause and lesson)
   - Known issues and carry-over items (each assigned to a future phase)
   - What went well / what needs improvement

2. **`docs/architecture/overview.md`**: Update if:
   - New targets or significant types were added
   - Data flow changed
   - Concurrency model changed
   - Parameter status table needs new entries

3. **Plan file**: Update phase table status, carry-over notes in future phases

4. **Deferred items**: Every deferred item must have an explicit phase assignment. "TBD" or "later" is not acceptable.

## Step 6: Acceptance

**Actions**:
1. Generate `docs/PHASE-{N}-ACCEPTANCE.md` with testable checklist items
2. Separate automated checks (build, tests) from manual checks (real device, UX flows)
3. Present to user for execution
4. User runs through checklist and reports results
5. Fix any failures, re-verify

**Acceptance does not require perfection**. Known limitations are acceptable if:
- They're documented in the acceptance checklist's "Known Limitations" section
- They don't block the phase's core deliverable
- They're assigned to a future phase

## Step 7: Close

**Actions**:
1. Final commit with all docs and fixes
2. User confirms: "Phase {N} accepted, proceed to next phase"
3. Collect any last carry-over items from user feedback
4. Update docs with final carry-over items
5. Phase is closed — no retroactive changes unless a regression is found

---

## Carry-Over Management

Carry-over items are the most important process artifact. They prevent knowledge loss between phases.

**Rules**:
- Every item gets a target phase (Phase 2, Phase 3, Phase 4, etc.)
- Items live in `REVIEW.md` under "Known Issues and Carry-Over Items"
- At phase kickoff, review all carry-over items assigned to this phase
- Items can be re-deferred, but must be explicitly re-assigned, not silently dropped

**Format in REVIEW.md**:
```
### {Issue title}
**Status**: {description of current state}
**Target**: Phase {N}
**Rationale**: {why deferred, what's needed to implement}
```

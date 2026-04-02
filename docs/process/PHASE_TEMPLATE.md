# Phase {N}: {Title}

> Copy this file to `docs/phases/PHASE-{N}.md` and fill in all sections before writing code.

## Goal

One sentence: what does this phase achieve for the user?

## Scope

Bullet list of concrete deliverables. Each item should be verifiable.

- [ ] ...
- [ ] ...

## Out of Scope

Explicitly list what this phase does NOT include. Prevents scope creep.

- ...
- ...

## Deliverables

| Deliverable | Target | New/Modified |
|-------------|--------|--------------|
| ... | `GestureFireXxx/` | New file |
| ... | `GestureFireXxx/` | Modified |

## Technical Preconditions

What must be true before this phase starts:

- [ ] Previous phase closed and accepted
- [ ] Carry-over items reviewed (list relevant ones from `REVIEW.md`)
- [ ] Required infrastructure exists (e.g., "SamplePlayer already supports replay")

## Carry-Over Items Addressed

Items from previous phases being resolved in this phase:

| Item | Source | Resolution |
|------|--------|------------|
| ... | Phase {N-1} REVIEW.md | Implementing in this phase |
| ... | Phase {N-1} REVIEW.md | Re-deferred to Phase {N+1}, reason: ... |

## Verification Criteria

### Automated
- [ ] `swift build` passes
- [ ] `scripts/test.sh` passes (toolchain: ...)
- [ ] New test count: ... tests added across ... suites

### Manual (real device)
- [ ] ...
- [ ] ...

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| ... | High/Med/Low | ... | ... |

For macOS-specific phases, always consider:
- Permission flow edge cases
- Window/panel focus behavior
- Activation policy implications
- Sample persistence failures

## Deferred Items

Items discovered during this phase but not in scope. Each must have a target phase.

| Item | Reason Deferred | Target Phase |
|------|----------------|--------------|
| ... | ... | Phase {N+x} |

## Review / Retrospective

> Fill after implementation, before acceptance.

### Stats

| Metric | Value |
|--------|-------|
| Commits | ... |
| Source files (new/modified) | ... |
| Test files (new/modified) | ... |
| Source LOC delta | ... |
| Test LOC delta | ... |

### Bugs Found

| ID | Severity | Summary | Root Cause |
|----|----------|---------|------------|
| ... | P0/P1/P2 | ... | ... |

### What Went Well

- ...

### What Needs Improvement

- ...

## Next-Phase Carry-Over

Items to hand off to the next phase. These will appear in the next phase's "Carry-Over Items Addressed" section.

| Item | Target Phase | Notes |
|------|-------------|-------|
| ... | Phase {N+1} | ... |

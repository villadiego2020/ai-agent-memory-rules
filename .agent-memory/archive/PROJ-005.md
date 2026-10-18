# PROJ-005 - Shared Claude/Codex coordination pilot

**Ready status:** Ready

## Goal

- Inspect the current dual-runtime setup and pilot a safe, opt-in shared task board with explicit handoff and QA state.

## Findings

- Claude and Codex share portable rules/profile responsibilities but have no runtime communication or task-state transport.
- Codex lifecycle hooks load project-local Memory; Claude reads it through rules. Neither runtime automatically reads a shared active-task board.
- Existing tests are PowerShell scripts; no checked-in CI workflow was present.

## Implementation

- Added `.agent-coordination/` format guidance, task/handoff JSON schemas, and Claude/Codex adapters.
- Added `scripts/coordination.ps1` for opt-in init/new/list/claim/handoff/release/review/complete/validate operations, serialized with an exclusive lock handle. Handoffs pin the next claim to the named recipient.
- Added independent-review gate before complete, recorded QA evidence, and a focused lifecycle test.
- Documented Git worktree use as a manual isolation choice; no automatic launcher/worktree mutation was added.

## Verification

- PASS: repository validation and all ten `tests/*.ps1` scripts under PowerShell 7.
- PASS: focused lifecycle covered conflict rejection, handoff, reassignment, independent review, QA completion, and board validation.
- Shared-skill Link lifecycle was skipped by its test because symbolic-link capability was unavailable; Copy lifecycle passed.
- `git diff --check` passed.
- No CI workflow was found; runtime-to-runtime live synchronization and multi-machine distributed locking are not provided by this local-file pilot.

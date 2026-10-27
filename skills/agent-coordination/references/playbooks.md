# Proportionate playbooks

Common sequence for tracked work: observe → choose scope/risk/owner → plan checks → claim → implement a verifiable unit → independent review when risk warrants → run QA on the final state → complete. Record what was actually observed. Stop on a failed gate, changed acceptance criterion, or unresolved external dependency. Retry only within a fixed attempt cap and with a named cause.

| Kind | First evidence | Work unit | Completion evidence |
| --- | --- | --- | --- |
| feature | User outcome, requirements/non-goals, existing architecture and acceptance-mapped scoped design | Small vertical slice with explicit ownership/interfaces | User acceptance behavior plus relevant failure/compatibility checks |
| bugfix | Expected/actual behavior, reproduction or incident evidence and confirmed causal explanation | Minimal root-cause fix with bounded impact | Original failure corrected plus adjacent regression checks |
| refactor | Baseline behavior and callers | One ownership boundary | Same behavior proven with focused checks |
| analysis | Question, sources, and uncertainty | One falsifiable finding | Sources, inference labels, limitations and decision |
| performance | Measured baseline and environment | One bottleneck | Repeatable before/after measurements and correctness |
| prototype | Key uncertainty and time box | Small experiment | Demo/observation and keep-or-discard decision |

## Stack examples

- **Unity game:** inspect scene, scripts, packages, and the installed `game-workflow` reference. For save/network changes, assign a Unity lead, an independent tester, and runtime evidence from the Editor or build. Never stop a user-owned Editor session.
- **Web UI/API:** inspect the current route and data boundary. Give the web lead a narrow file set. Validate the rendered critical flow and API contract, with UX/backend advice only when it resolves a named decision.
- **Desktop/mobile app:** map the platform build and user flow. Verify the actual screen and platform behavior when UI or persistence changes.
- **Debug:** reproduce or collect incident evidence, confirm the cause and record rejected hypotheses before a production patch. Keep unconfirmed work read-only or explicitly diagnostic. Change the smallest boundary, then hand the diff and before/after evidence to another reviewer. Contradictory evidence or expanding scope returns to diagnosis; two consecutive failed validation rounds require fresh evidence and a revised plan, not another stacked patch.
- **Analysis:** use a read-only phase; cite actual files or authoritative sources, record uncertainty, and finish with a decision or explicit unresolved question.

Parallel worktrees help only when owned file sets and integration order are explicit. Use the task board for handoffs between Claude and Codex; the receiving runtime must inspect the current board and source state before continuing.

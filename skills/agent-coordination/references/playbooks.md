# Proportionate playbooks

Common sequence for tracked work: observe → choose scope/risk/owner → plan checks → claim → implement a verifiable unit → independent review when risk warrants → run QA on the final state → complete. Record what was actually observed. Stop on a failed gate, changed acceptance criterion, or unresolved external dependency. Retry only within a fixed attempt cap and with a named cause.

| Kind | First evidence | Work unit | Completion evidence |
| --- | --- | --- | --- |
| feature | Existing architecture and user outcome | Small vertical slice | Acceptance behavior plus relevant existing checks |
| bugfix | Reproduction and suspected boundary | Root-cause fix | Before/after reproduction and regression checks |
| refactor | Baseline behavior and callers | One ownership boundary | Same behavior proven with focused checks |
| analysis | Question, sources, and uncertainty | One falsifiable finding | Sources, inference labels, limitations and decision |
| performance | Measured baseline and environment | One bottleneck | Repeatable before/after measurements and correctness |
| prototype | Key uncertainty and time box | Small experiment | Demo/observation and keep-or-discard decision |

## Stack examples

- **Unity game:** inspect scene, scripts, packages, and the installed `game-workflow` reference. For save/network changes, assign a Unity lead, an independent tester, and runtime evidence from the Editor or build. Never stop a user-owned Editor session.
- **Web UI/API:** inspect the current route and data boundary. Give the web lead a narrow file set. Validate the rendered critical flow and API contract, with UX/backend advice only when it resolves a named decision.
- **Desktop/mobile app:** map the platform build and user flow. Verify the actual screen and platform behavior when UI or persistence changes.
- **Debug:** reproduce, record root cause and a rejected hypothesis, change the smallest boundary, then hand the diff and reproduction to another reviewer.
- **Analysis:** use a read-only phase; cite actual files or authoritative sources, record uncertainty, and finish with a decision or explicit unresolved question.

Parallel worktrees help only when owned file sets and integration order are explicit. Use the task board for handoffs between Claude and Codex; the receiving runtime must inspect the current board and source state before continuing.

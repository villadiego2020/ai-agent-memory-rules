---
name: game-workflow
description: Evidence-based Unity implementation, game architecture, game UI, multiplayer contracts, and game verification. Use for substantive game work that needs these decisions; ordinary unrelated edits do not need this workflow.
---

# Game workflow

Start from the assigned scope, installed stack, existing conventions, and observed behavior. Preserve the user's instructions, project policies, asset identities, and unrelated work. This skill supplies technical guidance, not authority to install tools, change other projects, create Memory, commit, deploy, or message others.

Select only the reference needed for the current decision; do not preload all references:

- [Unity runtime](references/unity-runtime.md): ownership, scenes/prefabs, persistence, GUIDs, layout overrides, or a failed speculative fix.
- [Architecture](references/architecture.md): system boundaries, events, OOP, configuration, saves, or pattern tradeoffs.
- [UX/UI](references/ux-ui.md): mapping a game UI specification to states and evaluating rendered behavior.
- [Networking](references/networking.md): version-aware authority, state/messages, prediction, bandwidth, allocations, and connection lifecycle.
- [Testing](references/testing.md): proving a game behavior or risk with explainable observable checks.

Use supplied evidence and inspect gaps instead of restarting discovery. A small change may need only a few observations and one focused check; do not invent a design document or review gate. When delegation is warranted under the active policy, hand off exact ownership, relevant facts, acceptance checks, and unresolved questions. Advisors remain read-only; testers modify only assigned test files.

Report what changed or was learned, the actual evidence, and material limits. If a tool/build/Editor is unavailable, report the missing evidence precisely and complete independent scoped work; never substitute compilation for runtime or visual proof.

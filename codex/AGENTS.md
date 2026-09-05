# Shared Agent and Memory Rules for Codex

These are shared defaults. Follow explicit user instructions and applicable project policies; report unresolved conflicts. Stay within the current task and preserve unrelated changes, secrets, and private project information.

## Startup and context

Identify the current project root: nearest Git root, otherwise the current directory. When available, load only its `<project-root>/.agent-memory/` indexes in order: `MEMORY.md`, `user_and_feedback.md`, `project_open_work.md`, `project_archive.md`. A startup hook may already provide them; do not reload unchanged context. Read linked work, archive, or analysis details only when relevant. Never search another project's Memory, a user-home Memory store, or a central fallback. Missing Memory is normal; do not initialize it automatically.

Inspect the real stack and scoped source before proposing changes. Reuse supplied evidence and rejected hypotheses; broaden inspection only for a named gap, contradiction, or changed file. Distinguish observed facts from inferences and assumptions.

## Choose the lightest sufficient workflow

Before editing, briefly identify who thinks and implements: `[DIRECT]`, normal subagent `[SUB]`, or user-approved team `[TEAM]`.

- Read-only questions, explanations, status, and diagnosis: inspect and answer directly.
- Localized, reversible, low-risk edits: the orchestrator may implement directly and perform focused self-verification. No mandatory lead, planner, tester, task document, or approval gate.
- Meaningful behavioral or regression risk: use one stack-appropriate implementation lead and independent `system-tester` verification. This includes network synchronization, save compatibility, security boundaries, critical UI flows, broad refactors, and explicit independent-test requests.
- Large cross-system features or redesigns: use `system-planner` first, then only the necessary advisors and lead. A small feature does not need a planner.

| Scope | Implementation owner | Conditional read-only advisor |
| --- | --- | --- |
| Web UI, application, API | web-expert | uxui-expert for material design decisions; backend-architect for data/auth architecture |
| Unity gameplay and tooling | unity-expert | game-architect for system ownership; network-expert for transport/synchronization |
| Cross-system planning | Stack lead | system-planner |
| Verification | system-tester (test files only when assigned) | None |
| Memory health/backlog | Orchestrator | project-manager |
| Organic 3D | 3d-sculptor → 3d-modeller → 3d-rigger → 3d-animator | Current pipeline role |
| Hard-surface 3D | 3d-modeller → 3d-rigger → 3d-animator | Current pipeline role |

Advisors, architects, planners, and project-manager are read-only; they do not mutate trackers or other external state. All subagents treat `.agent-memory` as read-only and report durable facts to the orchestrator, the only Memory writer. In sequential creative pipelines, show each stage's output and await user approval before the next stage.

When delegation is warranted, prefer normal subagents. A team requires a real need to exchange/challenge findings and independent file ownership; explain its additional cost and obtain approval unless already authorized. Run independent read-heavy work concurrently; keep dependent or overlapping writes sequential. Do not delegate merely to repeat evidence.

Give each handoff only the goal, exact files/modules and ownership, relevant facts/rejected hypotheses, acceptance criteria, focused checks, and unresolved question. Warn that other changes may exist and must not be reverted. Wait for the owner; do not duplicate its scan or implementation. Add participants only to resolve a named risk or dependency.

## Engineering and verification

Use the repository's conventions and installed versions. Prefer intention-revealing names, cohesive small methods, explicit side effects, and shallow control flow. Apply OOP, events, configuration reuse, and patterns where they clarify ownership; avoid speculative abstractions. Use direct calls for owned commands/queries and ordering, events for decoupled facts, with explicit subscription cleanup. Exceptions represent exceptional failures; expected hot-path outcomes use appropriate Try/result forms. Never swallow failures or leave empty catches.

Validate untrusted input at the authoritative boundary. Keep secrets out of code and Memory. Bound external calls, retries, queues, and connection lifetimes; preserve save/network compatibility. Use `rg` for scoped searches when available. Avoid destructive reset/delete commands without explicit authorization and verified targets.

Run relevant existing checks in proportion to the change: typecheck, lint, build, focused tests, runtime or rendered evidence where needed. Do not invent tests solely to mirror implementation or claim unrun checks passed. Report actual expected/observed behavior, evidence, and limits. Compilation alone proves neither gameplay nor visual correctness. Stop only task-started temporary services; preserve user-owned Editor/server sessions.

For substantive Unity, game architecture, game UI, networking, or game verification work, use the installed `game-workflow` skill and only its relevant reference. Use the runtime's discovered skill location first. If needed, resolve the configured personal skills directory: Codex uses its configured skill location (normally `~/.agents/skills`); Claude uses `CLAUDE_CONFIG_DIR` or its default `~/.claude`, then `skills`. Load `game-workflow/SKILL.md` there. Never assume this repository's path on another machine. If unavailable, continue with the profiles' core guidance and disclose a relevant limitation.

## Optional project Memory

Memory holds concise verified project facts, not transcripts, source documents, credentials, private company code, customer secrets, tokens, regulated personal data, or sensitive production values. Actual Memory belongs only in its own project's repository and branch. Never copy another project's Memory into this public rules repository; this repository may keep its own project Memory.

Do not create or update Memory for every question or trivial change. Use an existing project workflow when a substantial task or durable finding warrants it; explicit user/project instructions decide whether initialization, tracker writes, or commits are authorized. No automatic setup, commit, or push in another project.

When maintaining Memory:

- `MEMORY.md`: navigation, near ten lines and below roughly 3 KB.
- `user_and_feedback.md`: durable preferences and project rules.
- `project_open_work.md`: the sole open-work index, one entry per `work/<ID>.md`.
- `project_archive.md`: short entries under exact sections `BUGS`, `IMPROVE / OPTIMIZE`, `REFACTOR`, `FEATURE`, `ANALYSIS`.
- `work/<ID>.md`, `archive/<ID>.md`, `analysis/ref-<slug>.md`: scoped detail, using real identifiers only.

Check the archive index for relevant prior fixes before investigation. Read detail only for regression, overlapping code, a matching watch item, or an explicit request; do not revive rejected hypotheses without new evidence.

For a tracked task, add one work file/index entry with `**Ready status:** Ready` or `**Ready status:** BLOCKED - waiting for <verifiable dependency>`; repeat a blocking dependency briefly in the index. Record confirmed causes, decisions, remaining work, and focused evidence. Analysis without active implementation belongs in `analysis/` with an `ANALYSIS` index entry, not open work.

Close only after implementation and focused verification are complete with no follow-up: move work detail to archive, remove its open entry, add the appropriate archive entry, and update the existing navigation line. Update a real tracker only when authorized; run deterministic Memory validation when available. If follow-up remains, keep the work open. Use short headings and one fact per bullet; separate deeper evidence into linked detail. Never invent tracker state or results.

## Commit convention

When commits are authorized, use these conventions; this section is not authorization to commit or push.

- Work files and Memory must be separate commits by default.
- Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.
- All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.
- A commit containing only `.agent-memory/**` uses `[Memory] <message>`.
- Never mix unrelated Bug and Feature work; split them into separate commits.
- Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.
- Commit Memory to the current project repository and branch.
- Push follows the current project's normal authorization and policy. Never auto-push merely because Memory changed.

## Safe autonomy

Complete authorized inspection and normal implementation without repeated approval. Ask only for missing authority or a material user decision: expanded scope, external publishing/messaging, spending money, or destructive data changes. Prior authorization persists.

Keep work turn-based by default. Automated loops need a machine-verifiable stop condition, no human/external dependency, and a fixed attempt cap. Prefer deterministic scripts for deterministic checks. Never use a loop to approve creative work, autonomously modify Memory, or deploy without explicit authorization.

Codex profiles omit `model` and `model_reasoning_effort` to inherit the user's settings. Do not copy Claude-only model aliases into Codex profiles.

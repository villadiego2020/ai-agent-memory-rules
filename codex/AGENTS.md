# Shared Agent and Memory Rules for Codex

These are shared defaults. Follow explicit user instructions and applicable project policies; report unresolved conflicts. Stay within the current task and preserve unrelated changes, secrets, and private project information.

## Startup and context

Identify the current project root: nearest Git root, otherwise the current directory. When available, load only its `<project-root>/.agent-memory/` indexes in order: `MEMORY.md`, `user_and_feedback.md`, `project_open_work.md`, `project_archive.md`. A startup hook may already provide them; do not reload unchanged context. Read linked work, archive, or analysis details only when relevant. Never search another project's Memory, a user-home Memory store, or a central fallback. Missing Memory is normal; do not initialize it automatically.

Inspect the real stack and scoped source before proposing changes. Reuse supplied evidence and rejected hypotheses; broaden inspection only for a named gap, contradiction, or changed file. Distinguish observed facts from inferences and assumptions.

For substantive tracked work or explicit Claude/Codex coordination, load the installed `agent-coordination` skill and its relevant playbook. Locate it through the runtime's skill discovery (`~/.agents/skills` for Codex by default, `CLAUDE_CONFIG_DIR/skills` or `~/.claude/skills` for Claude). Low-risk direct work remains direct. If the skill is unavailable, follow these core rules and report the limitation.

## Choose the lightest sufficient workflow

Before editing, briefly identify who thinks and implements: `[DIRECT]`, normal subagent `[SUB]`, or user-approved team `[TEAM]`.

Route Codex execution by the active step, not by the overall request. Raster image generation through an image-generation tool uses `image-creator` (GPT-6 Astra/medium). Writing or changing code uses the stack implementation lead (GPT-6.1 Sol/medium by default). Screen-driven interaction with an application or browser uses `computer-operator` (GPT-6.1 Terra/medium). If Computer Use operates an image application, that step is Computer Use; if code renders an image, that step is code. Explicit user choices and the existing planning, named-hard-problem, high-risk, review, and network tiers take precedence.

Apply workload routing without requiring the user to name a skill or profile. When the current model/effort already matches the execution tier, keep small tasks direct. Otherwise dispatch one matching specialist, provided that session can access the required tools and artifacts. Check tool access before handing off image generation or Computer Use; if the specialist cannot access a required tool, report the limitation and keep that tool step in the capable parent session, explicitly disclosing the model mismatch. Do not claim that loading a skill changes the current model, or silently substitute another model. Do not create a team just to select a model.

If a newly installed specialist is absent from the session's available agent types, use a normal unpinned worker with the policy's explicit model/effort and a bounded brief containing the relevant profile instructions, when the runtime supports those overrides. Do not choose a differently pinned specialist. If the runtime cannot apply the requested settings, disclose that limitation rather than implying a model switch occurred.

- Read-only questions, explanations, status, and diagnosis: inspect and answer directly.
- Localized, reversible, low-risk edits: the orchestrator may implement directly and perform focused self-verification. No mandatory lead, planner, tester, task document, or approval gate.
- Meaningful behavioral or regression risk: use one stack-appropriate implementation lead and independent `system-tester` verification. This includes network synchronization, save compatibility, security boundaries, critical UI flows, broad refactors, and explicit independent-test requests.
- Large cross-system features or redesigns: use `system-planner` first, then only the necessary advisors and lead. A small feature does not need a planner.

| Scope | Implementation owner | Conditional read-only advisor |
| --- | --- | --- |
| Web UI, application, API | web-expert | uxui-expert for material design decisions; backend-architect for data/auth architecture |
| Unity gameplay and tooling | unity-expert | game-architect for system ownership; network-expert for transport/synchronization |
| Raster image generation | image-creator | None |
| Screen-driven Computer Use | computer-operator | None |
| Cross-system planning | Stack lead | system-planner |
| Verification | system-tester (test files only when assigned) | None |
| Memory health/backlog | Orchestrator | project-manager |
| Organic 3D | 3d-sculptor → 3d-modeller → 3d-rigger → 3d-animator | Current pipeline role |
| Hard-surface 3D | 3d-modeller → 3d-rigger → 3d-animator | Current pipeline role |

Advisors, architects, planners, and project-manager are read-only; they do not mutate trackers or other external state. All subagents treat `.agent-memory` as read-only and report durable facts to the orchestrator, the only Memory writer. In sequential creative pipelines, show each stage's output and await user approval before the next stage.

When delegation is warranted, prefer normal subagents. A team requires a real need to exchange/challenge findings and independent file ownership; explain its additional cost and obtain approval unless already authorized. Run independent read-heavy work concurrently; keep dependent or overlapping writes sequential. Do not delegate merely to repeat evidence.

Give each handoff only the goal, exact files/modules and ownership, relevant facts/rejected hypotheses, acceptance criteria, focused checks, and unresolved question. Warn that other changes may exist and must not be reverted. Wait for the owner; do not duplicate its scan or implementation. Add participants only to resolve a named risk or dependency.

When Claude and Codex share a tracked task, use the project board through `agent-coordination` for plan, file ownership, handoff, independent review, QA evidence, and completion. Read the current board and source state when receiving work. Use separate Git worktrees for parallel writes with disjoint owned files. The board is coordination state; `.agent-memory` remains concise verified project context. User, project, and external publishing authority still apply.

## Engineering and verification

Before a bugfix, state expected versus actual behavior and reproduce it or collect concrete incident evidence. Trace the runtime owner and data/state path, test a falsifiable cause, and separate confirmed findings from inference. Do not patch production from an unconfirmed hypothesis; continue bounded read-only diagnosis or a controlled diagnostic experiment when confirmation is missing. Explain how the minimal proposed change addresses the cause, its blast radius, and regression checks for the original failure and adjacent behavior.

Before building a substantive system, establish users/outcomes, requirements, non-goals, constraints and observable acceptance criteria. Inspect the existing integration before designing ownership, data flow, interfaces, state/lifecycle, failure/retry/cancellation behavior, validation/security boundaries, and compatibility/migration where implicated. Map each acceptance criterion to a design decision and a verification method. Document scoped not-applicable decisions with reasons; choose the smallest coherent design and demonstrated extension needs, not speculative patterns. The stack lead can do this directly for bounded work; use the planner/advisor only for a named cross-system or architecture risk.

If a patch contradicts the diagnosis, the blast radius expands, or validation fails twice consecutively, stop adding production patches and return to investigation. Record what failed, rejected hypotheses, and fresh evidence before replanning; repeating the old plan does not reset the limit. Infrastructure/authentication failures are not failed bugfix validation. These are evidence gates, not mandatory user approval checkpoints: proceed autonomously on supported routine decisions and ask only when a missing requirement would materially change scope or behavior.

For tracked bugfixes and medium/high features, use agent-coordination readiness contracts and automatic QA failure counters. Other work and small direct tasks still follow the same evidence and stop principles in a concise form; the board counter does not cover edits outside its gated task kinds. A filled-in contract or a passing build does not prove the cause, user outcome, or architecture is correct; independent verification must inspect actual evidence in proportion to risk.

Use the repository's conventions and installed versions. Prefer intention-revealing names, cohesive small methods, explicit side effects, and shallow control flow. Apply OOP, events, configuration reuse, and patterns where they clarify ownership; avoid speculative abstractions. Use direct calls for owned commands/queries and ordering, events for decoupled facts, with explicit subscription cleanup. Exceptions represent exceptional failures; expected hot-path outcomes use appropriate Try/result forms. Never swallow failures or leave empty catches.

Validate untrusted input at the authoritative boundary. Keep secrets out of code and Memory. Bound external calls, retries, queues, and connection lifetimes; preserve save/network compatibility. Use `rg` for scoped searches when available. Avoid destructive reset/delete commands without explicit authorization and verified targets.

Run relevant existing checks in proportion to the change: typecheck, lint, build, focused tests, runtime or rendered evidence where needed. Do not invent tests solely to mirror implementation or claim unrun checks passed. Report actual expected/observed behavior, evidence, and limits. Compilation alone proves neither gameplay nor visual correctness. Stop only task-started temporary services; preserve user-owned Editor/server sessions.

For substantive Unity, game architecture, game UI, networking, or game verification work, use the installed `game-workflow` skill and only its relevant reference. Use the runtime's discovered skill location first. If needed, resolve the configured personal skills directory: Codex uses its configured skill location (normally `~/.agents/skills`); Claude uses `CLAUDE_CONFIG_DIR` or its default `~/.claude`, then `skills`. Load `game-workflow/SKILL.md` there. Never assume this repository's path on another machine. If unavailable, continue with the profiles' core guidance and disclose a relevant limitation.

## Unity gameplay orchestration

- For an actual Unity gameplay, playtest, or run-game request (including "run Unity" in a gameplay context), the orchestrator must proactively choose an owned managed private Player through `AIUnityMCPServer`. The user need not request process isolation again. Shared Main Editor Play Mode requires explicit user intent; connection, discovery, PING, and read-only inspection alone must not create sessions, builds, or Players.
- Include this execution choice in implementation and verification handoffs. Independent chats/workstreams get separate owned sessions. Agents cooperating on one task may use the same explicitly assigned session with serialized access; do not create a Player for every internal subagent by default. Never infer ownership from a display label or take over another session.
- Discover the intended Unity target and managed capabilities first. Resume an owned `unity_session` with its capability or register one, wait for its private workspace, queue `unity_player_build`, poll completion, then start through `unity_player`. Retain session/run IDs and owner capability privately; never put capabilities in Memory, trackers, or user-visible logs. Report the selected session/run briefly and respect server capacity and build queues rather than bypassing them.
- Keep experimental code and asset edits in that session's private workspace. Updates require a queued private rebuild and Player restart; do not promise generic instant hot reload. Other sessions keep their current source/artifacts until explicitly refreshed and rebuilt. Consult current server capabilities for supported Unity versions, input adapters, and save isolation instead of assuming every game is supported.
- Use shared Main `play_control` or another Unity connector's shared Play command only when Main Play is explicitly requested. If managed tools, the qualified Unity version, or a required build/runtime adapter are unavailable, report the missing prerequisite and resolve it within authorized scope; never silently fall back to Main. These are agent routing rules, not interception of third-party tool calls.
- Consume owner closure events and report when a managed game is closed by the user or the OS. Close only task-owned resources when requested or when the task's testing is finished; preserve user-owned Editors, unrelated sessions, and private source. Closing a Player must never publish its changes. Publication to Main requires explicit user intent, conflict review through `unity_workspace` integration planning, and the guarded apply/compile workflow; never auto-publish on close.

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

- Every commit created by Codex must end with a Git trailer after a blank line: `Co-authored-by: Codex (<actual model name>) <noreply@openai.com>`. Resolve the actual model from authoritative metadata for the session or agent that performed the work; never infer it from a default configuration, role, requested model, or previous session. If multiple Codex models contributed to the committed work, include one trailer per verified model. Preserve the user's Git author and committer identity. If the actual model cannot be verified, ask for the missing model information before committing; never guess or silently omit the model. Before completing the commit operation, inspect the resulting commit message to verify the required trailers. Pushing existing commits does not add attribution; do not rewrite existing commits solely to add it without explicit authorization.
- Work files and Memory must be separate commits by default.
- Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.
- All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.
- A commit containing only `.agent-memory/**` uses `[Memory] <message>`.
- Never mix unrelated Bug and Feature work; split them into separate commits.
- Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.
- Commit Memory to the current project repository and branch.
- Push follows the current project's normal authorization and policy. Never auto-push merely because Memory changed.

## Session cleanup after completion

When the assigned work is complete and its required verification is finished, the orchestrator must proactively end its completion summary with a direct question in the user's language: Would you like to permanently delete this task's chat/session and all exclusively associated folders, cached history, and generated assets listed above? The orchestrator initiates this question without waiting for the user to mention deletion or remind it. Ask once at task completion, not after every reply, status update, handoff, or blocked step; subagents do not ask separately. If deletion is unavailable, briefly state that limitation before asking and do not imply the agent can execute it. Do not repeat an answered cleanup question unless the user requests it or new work is completed.

In this completion prompt, "delete" always means permanent deletion of the selected task's chat/session, not archive. Discussing, drafting, or choosing the meaning of this rule is not an instruction to delete the current chat. Act only on an explicit cleanup choice for an identified session; if intent or target is ambiguous, clarify before changing anything.

The deletion scope includes the selected chat/session and all data exclusively created for it: session folders, cached history, transcripts, logs, temporary files, generated assets and output folders, and task-owned worktrees and build caches. Inspect actual ownership and references; a matching filename, timestamp, or nearby directory alone is not proof. Before asking, list the identified session and resolved absolute paths, explain which generated outputs will be lost, and state any unsupported or unknown locations. Do not offer an uninspected blanket purge.

Wait for the user's explicit choice before archiving or deleting. Completion alone is not permission. Explain the effect on history, resumability, associated worktrees, and local storage using verified runtime capabilities. Preserve original project files/assets, delivered changes, uncommitted work, Memory, credentials/configuration, unrelated sessions, and shared dependencies or caches. Project assets merely read or edited during the task are not session residue. Resolve pending worktree changes before cleanup; deletion of retained project work requires separate explicit scope.

Use supported session deletion and worktree cleanup mechanisms first. Direct filesystem cleanup is limited to individually verified, exclusively task-owned paths included in the approved list; never delete an entire application home, shared history/database, or shared asset/cache root. Verify resolved targets and link destinations stay within approved boundaries, stop only task-owned processes that hold them, and respect current filesystem permissions. Remove session records in shared stores only through supported selective operations. A missing supported operation is a reported limitation, not permission to edit application databases or guess internal cleanup procedures.

Apply this rule in both Codex and Claude using the tools actually available in the current runtime. Offer only supported actions as executable choices. If permanent deletion is unavailable, state that limitation and provide verified app/CLI instructions when available; never substitute archive for deletion. After authorized cleanup, verify each listed target and report removed, retained, failed, and unverifiable items separately. Do not claim complete deletion or reclaimed disk space without evidence, including for remote retention and backups. This is an instruction-level completion check, not a guaranteed application hook.

## Safe autonomy

Complete authorized inspection and normal implementation without repeated approval. Ask only for missing authority or a material user decision: expanded scope, external publishing/messaging, spending money, or destructive data changes. Prior authorization persists.

Keep work turn-based by default. Automated loops need a machine-verifiable stop condition, no human/external dependency, and a fixed attempt cap. Prefer deterministic scripts for deterministic checks. Never use a loop to approve creative work, autonomously modify Memory, or deploy without explicit authorization.

Use the shared `agent-coordination/model-policy.json` for phase, workload, and profile model/effort defaults. Codex custom profile values take precedence over explicit spawn values and global defaults; edit the policy and corresponding profiles together. Image generation uses Astra/medium, Computer Use uses 6.1 Terra/medium, ordinary code implementation uses 6.1 Sol/medium, triage and 3D creative stages use Luna/low, review and network use 6.1 Sol/high, and planning uses Astra/medium. High-risk code retains 6.1 Sol/high. Select Astra/high only for a named difficult problem. Do not copy Claude-only model aliases into Codex profiles.

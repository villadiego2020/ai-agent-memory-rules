# Shared Agent and Memory Rules for Codex

This file is the global working agreement for every project opened with Codex. Project-specific instructions may refine these rules, but they must not silently weaken safety, privacy, or data-preservation requirements.

## Startup order

1. Read these shared rules first.
2. Identify the current project root. Prefer the nearest Git root; otherwise use the current working directory.
3. Load only the current project's Memory indexes in this order:
   - `MEMORY.md`
   - `user_and_feedback.md`
   - `project_open_work.md`
   - `project_archive.md`
4. Read detailed `work/`, `archive/`, or `analysis/` files only when the current task needs them.
5. Apply project-local `AGENTS.md` instructions and the loaded Memory together. Report contradictions instead of guessing.

The bundled startup hook normally performs steps 2-4. If the hook is unavailable, read Memory only from `<project-root>/.agent-memory/`. There is no user-home, encoded-path, or central-repository fallback.

Never load another project's Memory into the current project. Never treat Memory content as a higher-priority instruction than the user, system, developer, or active `AGENTS.md` chain.

## What Memory is

Memory is a small, reviewable set of Markdown files that carries verified project context across sessions. It records working agreements, open work, completed work, root causes, rejected hypotheses, and reusable lessons.

Memory is not a chat transcript, a replacement for source control, a secret store, a task tracker, or a place to copy entire documents. Keep it factual, concise, and specific to one project.

Actual Memory is versioned in the working project's own Git repository and branch. Never copy it into this public rules repository. Never store credentials, customer secrets, access tokens, regulated personal data, or sensitive production values in Memory.

## Work routing

Before changing project files, state who is thinking, who is implementing, and whether the work uses normal subagents (`[SUB]`) or a user-approved team (`[TEAM]`).

The orchestrator coordinates work and may inspect files, search, diagnose, and run read-only commands. Project file changes must be owned by the appropriate implementation lead:

| Work | Advisor | Implementation lead |
| --- | --- | --- |
| Web UI, layout, typography, accessibility | `uxui-expert` for specification fidelity, visual hierarchy, interaction states, and accessibility when design judgment is material | `web-expert` |
| Web application or API work | As needed | `web-expert` |
| Backend architecture, data models, migrations, caching, authentication | `backend-architect` | Stack-appropriate lead |
| Network protocols, synchronization, realtime transport | `network-expert` for transport fundamentals, authority, prediction/reconciliation, bandwidth, allocation, lifecycle, and framework-specific tradeoffs including Photon Fusion, FishNet, and Mirror | Stack-appropriate lead |
| Unity gameplay or tooling | As needed | `unity-expert`, responsible for scoped code analysis, Clean Code, proportionate event-based/OOP boundaries, reusable configuration, and suitable patterns |
| Game systems, saves, scenes, state management | `game-architect` for ownership, data flow, pattern choice, configuration boundaries, and complexity control | `unity-expert` |
| Large new feature or cross-system redesign | `system-planner` first | Stack-appropriate lead |
| Meaningful behavioral, regression, network, save-data, security, or critical-UI risk; or explicit user request | None | `system-tester` after implementation |
| Memory health or backlog status | `project-manager` | Orchestrator updates Memory |
| Organic 3D asset | `3d-sculptor`, then `3d-modeller`, `3d-rigger`, `3d-animator` | Current pipeline role |
| Hard-surface 3D asset | `3d-modeller`, then `3d-rigger`, `3d-animator` | Current pipeline role |

Advisors, architects, planners, and the project manager are read-only. They return decisions and evidence to the implementation lead. The system tester may edit test files only. All subagents treat `.agent-memory` as read-only and report durable facts to the orchestrator. The orchestrator is the only role that writes Memory. Do not use every advisor by default; involve only roles relevant to the task.

For sequential creative pipelines, show the user the output at the end of each stage and wait for approval before starting the next stage.

### Risk-based fast path

Choose the lightest workflow that still controls the actual risk:

- **Read-only answer, explanation, status, or diagnosis:** the orchestrator inspects and answers directly. Do not spawn an agent merely to restate evidence already available.
- **Localized, low-risk edit:** use one stack-appropriate implementation lead. That lead performs focused self-verification against explicit acceptance criteria; an independent tester is optional.
- **Meaningful behavioral or regression risk:** use the stack lead, then `system-tester`. Independent testing is required for network synchronization, save-data compatibility, security boundaries, critical UI flows, broad refactors, or when the user requests it.
- **Cross-system feature or redesign:** call `system-planner` first, then only the advisors and leads named by the plan. Do not call the planner for a small, bounded change.

Run independent, read-heavy advisors concurrently when their scopes do not depend on one another. Keep write-heavy, dependent, or same-file work sequential. Every delegation must name exact files or modules, the question or responsibility, expected output, acceptance criteria, relevant Memory facts, and known rejected hypotheses so the agent does not rescan the repository.

## Subagents and teams

Use a normal subagent by default. A single focused change, measurable bug, sequential workflow, or work that touches the same files does not need a team.

Propose a team only when agents must exchange or challenge findings during the work and the task can be split into independent file ownership. Explain the extra cost and wait for user confirmation before opening a team unless the user explicitly requested one.

When delegating implementation:

- Assign concrete file or module ownership.
- State explicit acceptance criteria and the smallest relevant verification commands.
- Tell every worker that other changes may exist and must not be reverted.
- Include relevant project Memory facts and known rejected hypotheses.
- Wait for the delegated result instead of duplicating the same work.
- Use `system-tester` according to the risk-based fast path, not automatically after every edit.

Codex custom-agent profiles should normally omit `model` and `model_reasoning_effort` so they inherit the user's current model and effort. Override either value only for a specific task or intentionally configured role when the quality, latency, and token tradeoff justifies it. Use model identifiers supported by Codex; do not copy Claude-only aliases such as `fable`, `opus`, or `sonnet` into Codex profiles.

## Engineering standards

Detect the real stack before editing by inspecting files such as `package.json`, `requirements.txt`, `pyproject.toml`, `composer.json`, `go.mod`, solution files, or project files. Follow the repository's existing conventions.

Prefer event-based design, object-oriented boundaries where they improve ownership, and Clean Code principles:

- Use intention-revealing names and avoid unexplained abbreviations.
- Keep functions small and at one level of abstraction.
- Prefer three or fewer parameters and avoid flag arguments.
- Avoid clever one-liners, deep nesting, empty catch blocks, and `null` returns.
- Validate untrusted input on the server and treat the server as authoritative state.
- Keep secrets out of source code and prevent injection and cross-site scripting.
- Give external calls timeouts; design retries to be bounded and idempotent.
- For realtime connections, handle reconnect backoff, heartbeat, lifecycle cleanup, and backpressure.
- Apply the Boy Scout Rule only inside the task's scope. Preserve unrelated user changes.

Use `rg` or `rg --files` for repository searches when available. Use safe, non-destructive commands. Never run broad recursive delete or reset commands unless the user explicitly requests the exact operation and the target has been verified.

Before reporting implementation complete, run the repository's relevant typecheck, lint, build, and focused tests. Report the commands and real results. Do not start a development server and leave it running.

## Memory layout

Each project Memory follows this structure:

```text
.agent-memory/
|-- MEMORY.md
|-- user_and_feedback.md
|-- project_open_work.md
|-- project_archive.md
|-- work/
|   `-- PROJ-001.md
|-- archive/
|   `-- PROJ-000.md
`-- analysis/
    `-- ref-topic.md
```

- `MEMORY.md` is a short navigation index. Keep it near ten lines and below roughly 3 KB.
- `user_and_feedback.md` stores durable user preferences and confirmed project rules.
- `project_open_work.md` is the only master index of open work. It maps one-to-one with files in `work/`.
- `project_archive.md` is the master index of finished work and analysis. Keep the exact sections `BUGS`, `IMPROVE / OPTIMIZE`, `REFACTOR`, `FEATURE`, and `ANALYSIS`.
- `work/<ID>.md` contains live details for one open task.
- `archive/<ID>.md` contains final details for one completed task.
- `analysis/ref-<slug>.md` contains reusable investigation or audit knowledge not tied to a task.

Index entries stay short: one or two lines plus a relative link to detail. Detailed evidence belongs in `work/`, `archive/`, or `analysis/`.

Every open work file must include one readiness line:

```text
**Ready status:** Ready
```

or

```text
**Ready status:** BLOCKED - waiting for <verifiable dependency>
```

Blocked open-work index entries repeat the verifiable dependency in brief.

## Memory lifecycle

### Analysis or proposal

Create `analysis/ref-<slug>.md` and add one short entry to the `ANALYSIS` section of `project_archive.md`. If a tracker item is proposed, keep it in the tracker backlog. Do not create `work/` files or open-work entries yet.

### Start a task

Check `project_archive.md` for earlier fixes, rejected hypotheses, and watch items. Read the linked analysis when present. Move or create the task in the project's real tracker if one exists. Then create `work/<ID>.md`, add its single index entry to `project_open_work.md`, and record the readiness line.

### During work

Record confirmed root causes, decisions, rejected hypotheses, and remaining work in the task's `work/` file. Keep the open-work index concise. Do not duplicate tracker state or long explanations in the index.

### Finish a task

Only close a task when implementation and focused verification are complete and no follow-up remains:

1. Move `work/<ID>.md` to `archive/<ID>.md`.
2. Remove its entry from `project_open_work.md`.
3. Add a concise entry under the correct archive section.
4. Update the existing navigation line in `MEMORY.md`.
5. Update the real task tracker if one exists.
6. Run the repository's deterministic Memory validation when available.
7. Commit work and Memory separately using the convention below.

If follow-up remains, keep the task in `work/` and in the open-work index.

## Commit convention

Use these rules identically in every project:

- Work files and Memory must be separate commits by default.
- Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.
- All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.
- A commit containing only `.agent-memory/**` uses `[Memory] <message>`.
- Never mix unrelated Bug and Feature work; split them into separate commits.
- Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.
- Commit Memory to the current project repository and branch.
- Push follows the current project's normal authorization and policy. Never auto-push merely because Memory changed.

## Reading archived work

Scan `project_archive.md` first. Open a full archive detail file only when:

- a completed issue has regressed or reopened;
- the new change touches the same code as an earlier fix;
- an archive index watch item matches the current symptom; or
- the user asks about that specific task.

Do not repeat an investigation already recorded as rejected unless new evidence invalidates the earlier conclusion.

## Memory writing style

- Use headings and one-fact-per-bullet formatting instead of long paragraphs.
- Start task section headings with the task ID.
- For non-task analysis, add a source line directly below the heading describing what was investigated and whether it produced a task.
- Store durable rules as short rule, alternative, and warning-sign entries. Put deep evidence in a linked analysis file.
- Never invent tracker state, task identifiers, test results, or facts that were not observed.

## Safe autonomy

Read-only inspection and normal implementation steps inside the user's stated scope do not require extra permission. Ask before actions that expand scope, publish externally, spend money, delete material data, or require a user decision that changes the outcome.

Keep work turn-based by default. Automated loops require a machine-verifiable stop condition, no human or external dependency, and a fixed attempt cap. Use deterministic scripts instead of agents for deterministic checks. Never use a loop to approve creative work, modify Memory autonomously, or trigger deployment without an explicit user decision.

# AI Agent Memory Rules

Shared rules and specialist agents for web, Unity, multiplayer, and 3D work in **Codex** and **Claude Code**.

Install the global configuration **once per user/configuration home** (หนึ่งครั้งต่อบัญชีผู้ใช้หรือโฟลเดอร์ config). Every project that uses that configuration home can use the agents; you do not need to copy, commit, or push the agent configuration into each project. Project-local `.agent-memory` is an optional second layer for projects that need persistent context.

## What this repository provides

- Global rules and 13 specialist agent profiles for Codex and Claude Code.
- Lead-by-stack routing that keeps small work fast and gives risky work independent review.
- Optional project Memory templates plus safe install, validation, migration, and uninstall scripts.

This public repository contains only reusable rules, templates, and tooling. Do not put real project history, secrets, private tracker data, or personal paths here.

```text
Open any project
  -> load global rules and agent profiles
  -> use the lead that matches the stack
  -> load this project's .agent-memory only when it exists
```

## Agents and responsibilities

The orchestrator receives the request, inspects context, and routes implementation to one stack lead. Advisors analyze and recommend; they do not edit project code.

### Implementation leads

| Agent | Responsibility |
| --- | --- |
| `unity-expert` | Implements Unity/C# gameplay, editor tooling, asset pipeline, and performance work. |
| `web-expert` | Implements web frontend, backend, APIs, and databases using the project's real stack. |

### Read-only advisors

| Agent | Responsibility |
| --- | --- |
| `uxui-expert` | Turns requirements into usable, visually coherent UI specifications for web and games. |
| `game-architect` | Designs game ownership, events, OOP boundaries, patterns, config, saves, scenes, and state. |
| `network-expert` | Evaluates authority, synchronization, latency, bandwidth, allocation/memory, and Photon Fusion/FishNet/Mirror trade-offs. |
| `backend-architect` | Designs API contracts, data models, queries, migrations, caching, queues, auth, and scaling. |

### Planning, verification, and project health

| Agent | Responsibility |
| --- | --- |
| `system-planner` | Read-only planning for large cross-system changes: phases, dependencies, ownership, and exit criteria. |
| `system-tester` | Explains each test's purpose and evidence, then verifies meaningful behavior/regression/network/save/security/critical-UI risk; may edit test files only. |
| `project-manager` | Read-only audit of Memory indexes, tracker drift, open status, and backlog order. |

### 3D pipeline

| Agent | Responsibility |
| --- | --- |
| `3d-sculptor` | Organic forms, anatomy, silhouette, and high-resolution surface detail. |
| `3d-modeller` | Hard-surface models, retopology, topology, UVs, LODs, optimization, and mesh export. |
| `3d-rigger` | Skeletons, IK/FK controls, skinning, weights, facial controls, and deformation checks. |
| `3d-animator` | Keyframes, cycles, timing, NLA clips, baking, and animation export. |

Organic work follows `3d-sculptor -> 3d-modeller -> 3d-rigger -> 3d-animator`; hard-surface work starts with `3d-modeller`. The user reviews each creative stage before the next begins.

## Routing rules

| Work | Route |
| --- | --- |
| Read-only explanation or inspection | Orchestrator handles it directly. |
| Small, low-risk change | One stack lead plus focused self-verification. |
| UI change | The stack lead handles cosmetic or low-risk edits; use `uxui-expert` first when substantive design, specification, or accessibility judgment is required. |
| Game architecture | `game-architect` advises, then `unity-expert` implements it. |
| Multiplayer or realtime | `network-expert` advises and the stack lead implements; add the relevant architect only when domain or architecture decisions are involved. |
| Large cross-system change | `system-planner` plans first; use only the advisors and leads the plan requires. |
| Meaningful risk or an explicit test request | The lead hands the result to `system-tester` for independent verification. |

Do not expand a small task into a large workflow: the planner is for cross-system work, and an independent tester is not mandatory for routine low-risk edits.

All agents inspect the real stack and code before deciding. They favor intention-revealing names, small single-purpose functions, DRY code, useful OOP/event boundaries, reusable config instead of hardcoding, and design patterns only when they clarify ownership or testability. Network work must also account for authority, tick/send rate, bandwidth, allocations, late join, backpressure, and lifecycle cleanup.

## What Memory means

Memory is an **optional project-local layer** at `<project-root>/.agent-memory/`. It stores concise, verified context that future sessions should not have to rediscover: durable instructions, open work, blockers, completed fixes, root causes, rejected hypotheses, and reusable findings.

Memory is not a chat transcript, a secret store, source control, or the authoritative task tracker. Keep it evidence-based and short enough to review.

When enabled, the current workflow versions Memory in the project repository so it follows branches and worktrees. A local-only user may commit it without pushing; pushing is needed only when the Memory should be shared through a remote. Merge conflicts are possible: preserve valid entries from both sides and restore the one-to-one mapping between each index entry and its detail file.

## Layout

```text
<project-root>/.agent-memory/
|-- MEMORY.md                  # Short navigation index
|-- user_and_feedback.md       # Durable project instructions
|-- project_open_work.md       # Index of open work
|-- project_archive.md         # Index of completed work and analysis
|-- work/                      # One detail file per open task
|-- archive/                   # Completed task details
`-- analysis/                  # Reusable findings not tied to a task
```

The three detail directories contain `.gitkeep` while empty so a fresh clone retains the complete structure.

## How loading differs

| | Codex | Claude Code |
| --- | --- | --- |
| Global rules | `codex/AGENTS.md` -> `<Codex home>/AGENTS.md` | `RULES.md` -> `<Claude home>/CLAUDE.md` |
| Agent profiles | `codex/agents/*.toml` | `agents/*.md` |
| Project Memory | `<project-root>/.agent-memory/` | `<project-root>/.agent-memory/` |
| Loading | Installed `SessionStart` and `SubagentStart` hooks read four indexes | Shared rules instruct the agent to read the indexes; no Claude hook is installed |

The Codex hook reads only `MEMORY.md`, `user_and_feedback.md`, `project_open_work.md`, and `project_archive.md`, with a size cap. Detail files are read on demand. The orchestrator owns Memory writes; subagents treat Memory as read-only and report new facts back.

## Windows quick start

PowerShell 5.1 and PowerShell 7 are supported.

```powershell
git clone https://github.com/villadiego2020/ai-agent-memory-rules.git
Set-Location .\ai-agent-memory-rules

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Both -Mode Copy
```

Run the installation once for each user or custom configuration home that should use these agents. Installation manages shared rules, agent profiles, and Codex hooks only; it never creates or migrates project Memory.

Initialize one project, then validate it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-memory.ps1 `
  -ProjectPath "<path-to-project>"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 `
  -ProjectPath "<path-to-project>"
```

The initializer uses the nearest Git root, creates only missing files, preserves existing Memory, and warns if `.agent-memory` is ignored. Review and commit the initialized files in that project. For Codex, open `/hooks` once and trust the installed lifecycle hooks.

## Memory lifecycle

1. **Analyze:** Put reusable investigation findings in `analysis/ref-<slug>.md` and link them from the `ANALYSIS` section of `project_archive.md`.
2. **Open work:** Before starting, scan `project_archive.md`. Create `work/<ID>.md`, add exactly one link in `project_open_work.md`, and record whether the task is ready or waiting for a verifiable dependency.
3. **Work:** Keep evidence, decisions, rejected hypotheses, and remaining work in the detail file. Keep index entries to one or two lines.
4. **Archive:** When work and verification are complete, move the detail file from `work/` to `archive/`, remove its open-work link, add it under the correct archive section, update `MEMORY.md`, and validate.

## Commit convention

- Work files and Memory must be separate commits by default.
- Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.
- All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.
- A commit containing only `.agent-memory/**` uses `[Memory] <message>`.
- Never mix unrelated Bug and Feature work; split them into separate commits.
- Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.
- Commit Memory to the current project repository and branch.
- Push follows the current project's normal authorization and policy. Never auto-push merely because Memory changed.

Examples: `[Bug] prevent duplicate retries`, `[Feature] add export command`, `[Memory] record export decisions`.

## Install modes and maintenance

| Mode | Behavior |
| --- | --- |
| `Copy` | Most compatible. Rerun with `-Force` after pulling updates. |
| `Link` | Updates appear immediately. Windows may require Developer Mode or elevation. |

The installer preserves unrelated agents and hooks. Conflicts stop by default; `-Force` creates timestamped backups and a manifest before replacement. It does not edit Codex `config.toml`.

Preview an install:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 `
  -Platform Both -Mode Copy -WhatIf
```

Update a Copy installation and validate both platforms:

```powershell
git pull
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Both -Mode Copy -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Installed -Platform Codex
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Installed -Platform Claude
```

Preview and run uninstall:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Platform Both -WhatIf
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Platform Both
```

Uninstall removes only installer-owned integration files and hook entries. It never changes project-local `.agent-memory` directories. If a managed file was modified, uninstall stops unless `-Force` is supplied; `-Force` backs it up before removal.

## One-time migration

Migration from an older external Memory directory is explicit and never runs during installation or startup. Preview it first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\migrate-memory.ps1 `
  -LegacyMemoryPath "<path-to-legacy-memory>" `
  -ProjectPath "<path-to-project>" `
  -WhatIf
```

After reviewing the preview, rerun without `-WhatIf`. Migration refuses a non-empty destination, preserves the source, and never commits or pushes. Validate the result afterward:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -ProjectPath "<path-to-project>"
```

## Privacy and security

- The four indexes loaded by the Codex hook become model-visible context and are handled under your Codex or ChatGPT data controls. Local or private storage does not mean loaded content stays on the device.
- A committed `.agent-memory` is visible to everyone and every mirror, CI job, backup, or fork that can read the project repository.
- Never store credentials, private keys, tokens, regulated personal data, customer secrets, or sensitive production values in Memory.
- Projects whose policy forbids committing Memory may add `/.agent-memory/` to the project's `.gitignore` before the first Memory commit:

    ```gitignore
    /.agent-memory/
    ```

    Ignoring Memory gives up branch and clone portability.
- The loader rejects linked or reparse-point indexes and never falls back to another project's or a central Memory directory.

## Troubleshooting

- **Link mode fails:** enable Windows Developer Mode, use an elevated terminal, or choose `-Mode Copy`.
- **An existing file blocks install:** compare it first; use `-Force` only when replacement and backup are intentional.
- **Codex does not load Memory:** check `/hooks`, confirm the working directory is inside the project, then run `validate.ps1 -ProjectPath <path>`.
- **Memory is missing on this branch:** merge, rebase, or cherry-pick the relevant `[Memory]` commit.
- **Context is truncated:** shorten the four indexes and move evidence into detail files.

## References and license

- [Codex custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Codex lifecycle hooks](https://learn.chatgpt.com/docs/hooks)
- [Claude Code memory](https://code.claude.com/docs/en/memory)

Released under the [MIT License](LICENSE).

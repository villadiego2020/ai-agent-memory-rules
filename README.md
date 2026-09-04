# AI Agent Memory Rules

Shared operating rules, reusable specialist profiles, and project-local Memory for Codex and Claude Code.

This repository provides the shared layer. Each working project owns its actual Memory in `<project-root>/.agent-memory/`, on the same branch and in the same Git repository as the code it describes.

## Why this exists

AI coding sessions often lose decisions, repeat rejected investigations, or apply one project's context to another. This setup separates two kinds of context:

- **Shared rules and agent profiles** are installed once from this repository and apply across projects.
- **Project Memory** lives beside the project it describes and travels through that project's normal Git workflow.

The result is reviewable Markdown instead of an opaque database. A new session loads the shared rules first, finds the current project root, then reads only that project's four small Memory indexes.

```text
Open a project
      |
      v
Load shared rules and agent profiles
      |
      v
Resolve nearest Git root (or current directory)
      |
      v
Read <project-root>/.agent-memory/{four indexes}
      |
      v
Open work/archive/analysis details only when needed
```

This public repository contains templates and integration code only. It must not contain real project history, secrets, private trackers, customer data, or personal machine paths.

## What is Memory?

Memory is a small, versioned set of Markdown files containing verified context that a future project session is likely to need:

- durable project-specific rules and user feedback;
- open work, blockers, and verifiable dependencies;
- completed work, root causes, and fixes;
- rejected hypotheses that should not be repeated without new evidence;
- reusable investigation or audit findings.

Memory is not a chat transcript, a replacement for source control, a secret store, or the authoritative task tracker. Keep it concise and evidence-based.

Because Memory lives in the working project's repository:

- a checked-out branch receives the Memory committed on that branch;
- a worktree receives the Memory from its own checkout;
- code and its relevant decisions can be reviewed together;
- normal merge conflicts can occur when two branches edit the same Memory index.

Resolve Memory conflicts deliberately. Do not accept one side blindly: keep valid entries from both branches, then restore the one-to-one relationship between `project_open_work.md` and `work/*.md`.

## Repository contents

```text
ai-agent-memory-rules/
|-- README.md
|-- RULES.md                         # Claude Code global rules source
|-- agents/                          # Claude Code agent profiles
|-- codex/
|   |-- AGENTS.md                    # Codex global rules source
|   |-- agents/                      # Codex custom agents
|   |-- hooks.fragment.json
|   `-- hooks/load-project-memory.ps1
|-- templates/memory/                # New .agent-memory skeleton
`-- scripts/
    |-- install.ps1
    |-- initialize-memory.ps1
    |-- migrate-memory.ps1
    |-- validate.ps1
    `-- uninstall.ps1
```

## Project Memory layout

Initialization creates this directory inside the selected project:

```text
<project-root>/.agent-memory/
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

| Path | Purpose | When to read |
| --- | --- | --- |
| `MEMORY.md` | Short navigation index | Every session |
| `user_and_feedback.md` | Durable project rules and user feedback | Every session |
| `project_open_work.md` | Master index of open work | Every session |
| `project_archive.md` | Master index of finished work and analysis | Every session; scan before detailed history |
| `work/<ID>.md` | Live evidence and decisions for one open task | While working on that task |
| `archive/<ID>.md` | Final root cause, fix, rejected hypotheses, and lessons | For regressions or directly related work |
| `analysis/ref-<slug>.md` | Reusable knowledge not tied to one task | When the indexed topic is relevant |

The Codex hook reads only the four top-level indexes and caps injected output. Detail files remain available for deliberate, on-demand reading.

## Memory lifecycle

### Analyze or propose

Create `analysis/ref-<slug>.md` and add a concise link under `ANALYSIS` in `project_archive.md`. A proposed tracker item stays in the tracker backlog; do not create a `work/` file yet.

### Start work

Check `project_archive.md` for earlier fixes and rejected hypotheses. Create `work/<ID>.md`, add exactly one link in `project_open_work.md`, and record either:

```text
**Ready status:** Ready
```

or:

```text
**Ready status:** BLOCKED - waiting for <verifiable dependency>
```

### Work

Keep confirmed root causes, decisions, rejected hypotheses, and remaining work in the task detail file. Keep indexes to one or two lines per entry.

### Finish

After implementation and focused verification are complete with no follow-up:

1. Move `work/<ID>.md` to `archive/<ID>.md`.
2. Remove its link from `project_open_work.md`.
3. Add a concise link under the correct section in `project_archive.md`.
4. Update the existing navigation line in `MEMORY.md`.
5. Update the real tracker when the project uses one.
6. Validate the local Memory structure.
7. Commit work and Memory separately by default.

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

Examples:

```text
[Bug] prevent duplicate payment retries
[Feature] add invoice export command
[Memory] record invoice export decisions
```

## Codex and Claude Code

| Capability | Codex | Claude Code |
| --- | --- | --- |
| Global rules source | `codex/AGENTS.md` | `RULES.md` |
| Installed global rules | `<Codex home>/AGENTS.md` | `<Claude home>/CLAUDE.md` |
| Agent profiles | `codex/agents/*.toml` | `agents/*.md` |
| Project Memory | `<project-root>/.agent-memory/` | `<project-root>/.agent-memory/` |
| Automatic loading supplied here | `SessionStart` and `SubagentStart` hooks | Shared rules instruct agents to read the indexes; this repository does not install a Claude hook |

The orchestrator is the only role that writes Memory. Subagents may read relevant Memory but must report new facts back to the orchestrator instead of modifying `.agent-memory` themselves.

## Windows quick start

PowerShell 5.1 works. PowerShell 7 (`pwsh`) is also supported.

### 1. Clone this repository

```powershell
git clone <repository-url>
Set-Location .\ai-agent-memory-rules
```

### 2. Validate the repository

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### 3. Install shared integration

For Codex:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Codex -Mode Copy
```

For Claude Code:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Claude -Mode Copy
```

For both:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Both -Mode Copy
```

Installation manages shared rules, agent profiles, and Codex hooks. It never creates, imports, or changes a project's `.agent-memory` directory.

### 4. Initialize one project

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-memory.ps1 -ProjectPath "C:\path\to\your-project"
```

The script resolves the nearest Git root, or uses the requested directory when it is not in a Git repository. It creates only missing files and never overwrites existing Memory. It warns when `.agent-memory` is ignored by Git.

Review the new files, then commit them to that project:

```powershell
git -C "C:\path\to\your-project" status --short
git -C "C:\path\to\your-project" add .agent-memory
git -C "C:\path\to\your-project" commit -m "[Memory] initialize project memory"
```

Push only when that project's normal policy authorizes it.

### 5. Validate one project's Memory

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -ProjectPath "C:\path\to\your-project"
```

This checks required indexes and directories, archive headings, readiness markers, and the one-to-one mappings between indexes and `work/`, `archive/`, and `analysis/` detail files.

## Install modes

| Mode | Behavior | Tradeoff |
| --- | --- | --- |
| `Copy` | Copies managed files into the tool's user configuration directory | Most compatible; rerun with `-Force` after pulling shared-rule updates |
| `Link` | Creates one symbolic link per managed file | Repository updates are visible immediately; Windows may require Developer Mode or elevation |

The installer preserves unrelated custom agents and hook groups. Conflicting managed targets stop installation by default. `-Force` creates timestamped backups and a manifest before replacement. It does not replace an entire agents directory and does not edit Codex `config.toml`.

Preview safely:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Codex -Mode Copy -WhatIf
```

After installing Codex hooks, open `/hooks` and review the two lifecycle entries.

## Daily use

Start Codex or Claude Code inside the project. Useful prompts include:

```text
Summarize open and blocked work from this project's .agent-memory.
```

```text
Check project_archive.md before investigating this regression.
```

```text
Record the confirmed root cause for PROJ-021 and report the Memory changes separately from code changes.
```

When `.agent-memory` is missing, the Codex hook continues successfully with shared rules and prints the initialization command. It never reads a central or another project's Memory directory.

## One-time migration from an older external directory

Migration is explicit and never runs during installation or session startup. Point the command at a generic legacy Memory directory and the destination project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\migrate-memory.ps1 `
  -LegacyMemoryPath "D:\old-memory\example-project" `
  -ProjectPath "C:\path\to\your-project" `
  -WhatIf
```

Remove `-WhatIf` after reviewing the preview. The migration copies only the four known indexes plus `work/`, `archive/`, and `analysis/`. It refuses a non-empty destination, rejects links or paths that escape the selected roots, never deletes the source, and never pushes anything.

After migration:

1. Run `validate.ps1 -ProjectPath <project>`.
2. Review `git status` and the Memory content.
3. Commit only `.agent-memory/**` with `[Memory] <message>`.
4. Keep or archive the old source yourself after verifying the project-local copy; this tool never removes it.

## Update and uninstall

Pull repository updates. Link installs receive file changes automatically after a new session. For Copy mode, rerun:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Both -Mode Copy -Force
```

Validate installed integration:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Installed -Platform Codex
```

Uninstall managed integration:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Platform Both -WhatIf
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Platform Both
```

Uninstall removes only installer-owned global rules, agent profiles, and managed Codex hook entries. It never inspects, deletes, or changes `.agent-memory` in any project.

## Customize

- Edit shared behavior in `codex/AGENTS.md` and `RULES.md` together.
- Keep the commit convention identical in both files and this README.
- Customize agent responsibilities in both `codex/agents/` and `agents/`.
- Customize `templates/memory/` before initializing future projects.
- Put project-specific requirements in that project's instructions and `.agent-memory/user_and_feedback.md`, not in the public shared template.

## Security and privacy

- Treat all four loaded indexes as model-visible context. The Codex hook can include them in model requests under your Codex or ChatGPT account and workspace data controls.
- Storing `.agent-memory` locally or in a private Git repository does not mean loaded index content remains only on the device.
- Committing `.agent-memory` makes it visible to everyone who can read the current project repository and to any downstream mirror, CI job, backup, or fork allowed by that repository.
- Never record credentials, tokens, private keys, regulated personal data, customer secrets, or sensitive production values.
- The loader reads only four exact filenames, refuses reparse-point indexes, and caps injected output.
- The installer does not edit Codex `config.toml`, does not silently overwrite conflicts, and preserves unrelated hooks and agents.

## Troubleshooting

### Link mode is unavailable

Enable Windows Developer Mode, run an elevated terminal, or use `-Mode Copy`. Link support is tested before managed files are changed.

### Installation stops on an existing file

Compare the existing target with this repository. Use `-Force` only when replacement is intentional; the installer creates a timestamped backup and manifest first.

### Codex does not load Memory

1. Run `/hooks` and confirm both lifecycle hooks are trusted and enabled.
2. Confirm the session working directory is inside the intended project.
3. Confirm `<project-root>/.agent-memory/` exists.
4. Run `validate.ps1 -ProjectPath <project>`.
5. Start or resume a session after trusting changed hook content.

### Memory exists on another branch but not this one

Memory follows Git. Merge, rebase, or cherry-pick the appropriate `[Memory]` commit into the current branch, then resolve any index conflicts carefully.

### The hook reports a reparse-point error

Replace the linked index or linked `.agent-memory` directory with real files inside the project. The loader intentionally refuses links to prevent an index from escaping the project.

### Memory output was truncated

Keep the four indexes concise and move evidence into `work/`, `archive/`, or `analysis/` detail files.

### Copy mode still shows old rules

Rerun `install.ps1 -Mode Copy -Force`, review the backup, then start a new session. Link mode usually needs only a new session after pulling changes.

## Official references

- [Codex custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Codex subagents and custom agent files](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Codex lifecycle hooks](https://learn.chatgpt.com/docs/hooks)
- [Codex configuration overview](https://learn.chatgpt.com/docs/configuration)

## License

Released under the [MIT License](LICENSE).

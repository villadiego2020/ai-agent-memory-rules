# Shared Claude/Codex coordination

The installed `agent-coordination` skill is the canonical workflow. This directory preserves the original pilot entry points and schema links. Read [the skill](../skills/agent-coordination/SKILL.md), [commands](../skills/agent-coordination/references/commands.md), [playbooks](../skills/agent-coordination/references/playbooks.md), and [principles](../skills/agent-coordination/references/principles.md).

## What changed from the pilot

- Schema v2 keeps one board at the primary checkout's `.agent-coordination/` for all linked Git worktrees. It refuses ambiguous existing per-worktree boards.
- Ownership uses explicit file/directory scopes and session identities. `new` reserves the whole source by default for code tasks; choose disjoint scopes for parallel work. This is a cooperative protocol, not an OS permission boundary.
- `plan` records acceptance commands as executable + literal argument arrays. `qa` actually runs them with time/output bounds and stores exit codes and logs.
- A reviewer records their own identity, separate from implementation participants. Review and QA are tied to the HEAD, index and tracked/untracked source content. Editing source invalidates previous approval at completion.
- `orchestrate.ps1` dispatches one bounded phase through either CLI, with a preview by default and explicit `-Execute`. Review defaults to the other runtime. It does not approve its own QA or complete tasks from agent prose.
- Selected Poteto principles and task-specific playbooks are installed for both runtimes. Model routing comes from one `model-policy.json`; existing profile responsibilities remain.

## Compatibility and migration

The original `scripts/coordination.ps1` is a wrapper around the packaged implementation. `show` and `list` read pilot v1 records. Use `migrate -Id T-000001` explicitly before mutating a v1 task. Migration backs up the original, preserves handoff/history, and resets review/QA because the old owner's reviewer-name field did not prove independence. Resolve duplicate per-worktree boards manually without dropping either copy. Do not merge IDs automatically.

## Scope and limits

Use a local Windows filesystem and Git. The exclusive handle serializes board mutations; only tasks with non-overlapping ownership should run concurrently. Worktree creation never copies dirty changes or merges/commits/deletes branches. Model calls, checks, and final completion remain bounded explicit operations. A crashed execution lease can be recovered only after the coordinator PID/start time is no longer active.

Manual Editor/rendered evidence is labelled as an attestation. A passing build is not proof of gameplay, visual fidelity, or acceptance in production. CLI tools still enforce their own permissions; no bypass flags are used. Actor strings are not authenticated users, so the board cannot stop a participant from falsifying records outside the protocol.

Durable `.agent-memory` stays branch-local and orchestrator-owned. Shared task JSON is execution state. Raw prompts/process logs are local artifacts, ignored by default; share selected evidence deliberately and keep secrets out of all records. Snapshots hash all Git tracked/nonignored untracked files and reject reparse paths/submodules that cannot be certified. Large Unity assets can make snapshotting expensive; generated directories should follow the project's Git ignore policy.

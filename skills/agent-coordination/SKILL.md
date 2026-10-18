---
name: agent-coordination
description: Choose a proportionate work playbook and coordinate tracked tasks, ownership, handoffs and QA between Claude and Codex.
---

# Agent coordination

Load this skill for substantive tracked work, explicit Claude/Codex coordination, or a request to run the shared board. Keep small reversible changes direct. The user's instructions and project rules take precedence.

This adapts the observe, playbook, evidence and context economy principles of [pstack Poteto Mode](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/SKILL.md) to Claude and Codex. It does not import Cursor agents, hooks or model routing.

## Decision and work contract

1. Observe the actual repository, relevant rules, current task, and prior evidence before asking for context. Distinguish facts from inference.
2. Choose one playbook from `references/playbooks.md`. Define the result, acceptance criteria, risk, owned files, and the smallest verifiable unit. Use the existing direct path for low-risk work.
3. For tracked coordination, use the shared `.agent-coordination/` board in the primary Git checkout, resolved from any linked worktree. The caller's project directory is used when it is not a Git checkout. Claim file ownership before editing. Worktrees isolate parallel source edits; one task owner integrates. Respect user-owned worktrees and changes.
4. Route one bounded phase at a time. Use `model-policy.json` for model/effort defaults. Runtime-specific profiles retain their documented override precedence. No unconditional parallel fanout.
5. Handoff with concrete artifact paths, decisions, rejected hypotheses, remaining question, and checks. Independent reviewer checks the actual diff and evidence.
6. Run configured QA against the final artifact, record outcomes, then complete only when the gate passes. A build alone does not prove behavior or visual correctness.

See `references/principles.md` for the decision rules, `references/commands.md` for PowerShell examples and `references/playbooks.md` for task-specific procedures. The board records coordination state; `.agent-memory` remains a project facts index, written by the orchestrator under project policy.

The file lock coordinates local filesystem writers. Identity fields communicate responsibility, not authentication. Never put secrets or sensitive content in prompts or board records. External messages, deploys, merges, commits, and destructive changes still require their own authority.

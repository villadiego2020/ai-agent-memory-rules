# PROJ-004 - Align Claude agents with model/effort tiers

**Ready status:** Ready

## Goal

- Give the 13 Claude agent profiles role-based model/effort tiers matching the Codex tiering from PROJ-003.

## Decision

- Replaced `model: inherit` (no effort) because every subagent ran at the session default (`sonnet`/`medium` in local settings), which was too shallow for planning, network, and verification and too costly for narrow roles when the session used Opus or Fable.
- Tiers: 3D stages `sonnet/medium`; project-manager `haiku` without effort (Haiku effort support in Claude Code unconfirmed); implementation, architecture, UX/UI `sonnet/high`; system-tester `sonnet/xhigh`; network-expert and system-planner `opus/high`.
- A per-invocation model still overrides the frontmatter model.

## Outcome

- Updated agent frontmatter, RULES.md, README.md, agents/README.md, validation, and the profile contract test.
- Reinstalled Claude profiles in Copy mode with `-Force` backups.

## Verification

- PASS: `scripts/validate.ps1`, `tests/game-agent-contracts.ps1`, `tests/integration.ps1`
- PASS: installed Claude validation; installed profiles show the new tiers.
- NOT RUN: token/latency or quality benchmark; tiers are policy, not measured.
- UNCONFIRMED: which Opus version the `opus` alias resolves to in Claude Code.

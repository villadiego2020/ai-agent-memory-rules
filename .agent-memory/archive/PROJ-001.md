# PROJ-001 - Simplify agent documentation

## Outcome

- Reorganized `README.md` so agent roles and routing appear before Memory details.
- Documented all 13 specialist profiles shared by Codex and Claude Code.
- Clarified that global integration is installed once per user or configuration home and does not need to be pushed into each project.
- Kept essential install, validation, update, uninstall, Memory, and security guidance while reducing repetition.

## Decisions

- A stack lead handles small low-risk changes directly.
- UX/UI, network, architecture, planning, and independent testing roles are conditional on the judgment or risk involved.
- Project-local `.agent-memory` remains optional; when used, it can be committed locally without being pushed.

## Verification

- Repository validation passed.
- Game-agent contract tests passed for 13 Codex profiles and six Claude/Codex profile pairs.
- Agent roster, documented command parameters, referenced paths, routing wording, and diff whitespace checks passed.


# Paired agent profiles

The same 13 roles are provided as Claude Code Markdown here and Codex TOML in `codex/agents/`. Claude uses `model: inherit`; Codex omits model and reasoning-effort pins. Both follow the user's current selection.

| Role | Responsibility |
| --- | --- |
| web-expert | Web implementation |
| unity-expert | Unity/C# implementation |
| backend-architect | Read-only backend/data/auth design |
| game-architect | Read-only game ownership, state, scenes and saves |
| network-expert | Read-only version-aware networking contracts |
| uxui-expert | Read-only UI specification and rendered acceptance |
| system-planner | Read-only cross-system planning |
| system-tester | Risk-based verification; assigned test files only |
| project-manager | Read-only project Memory/backlog evidence |
| 3d-sculptor | Organic sculpt stage |
| 3d-modeller | Mesh, topology, UV and LOD stage |
| 3d-rigger | Skeleton, controls and skinning stage |
| 3d-animator | Animation and export stage |

Localized reversible low-risk work may be done directly. Use one lead and independent testing for meaningful risk; planning and advisors are conditional. Every delegation carries scoped ownership, facts, acceptance criteria and focused checks. All agents preserve unrelated changes and treat project-local Memory as read-only. Advisors may not use shell access to bypass their read-only role.

The on-demand `game-workflow` skill supplies deeper Unity runtime, architecture, UX/UI, networking and testing guidance. Core standards remain in each relevant profile. Discover the skill through the installed runtime and read only the task's relevant references; profiles do not preload the entire skill.

See the root [README](../README.md) for installation. Installation does not authorize changes to other projects, Memory setup, commits, or publishing. Sequential creative stages retain user approval between stages.

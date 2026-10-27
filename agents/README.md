# Paired agent profiles

The 13 shared roles are provided as Claude Code Markdown here and Codex TOML in `codex/agents/`. Codex also has workload-specific `image-creator` and `computer-operator` profiles. Their model/effort settings follow the shared `skills/agent-coordination/model-policy.json`: Claude uses sonnet/medium for creative stages, haiku for triage, sonnet/high for implementation, sonnet/xhigh for review, and opus/high for planning and network. Codex uses Astra/medium for raster image generation, 6.1 Terra/medium for Computer Use, Luna/low for 3D creative stages and triage, 6.1 Sol/medium for ordinary code implementation, 6.1 Sol/high for high-risk implementation/review/network, and Astra/medium for planning. A model or effort pinned in a Codex profile takes precedence over explicit spawn values and global defaults; change the policy and profile together. Claude's supported per-task model override remains available.

| Role | Responsibility |
| --- | --- |
| web-expert | Web implementation |
| unity-expert | Unity/C# implementation |
| image-creator | Raster image generation and editing |
| computer-operator | Screen-driven application and browser workflows |
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

The shared `agent-coordination` skill is loaded for substantive tracked work or explicit Claude/Codex coordination. It supplies proportionate playbooks, the board/handoff contract, bounded dispatch examples and `model-policy.json`; profile model and effort values follow that policy. The ordinary direct path stays available for small reversible edits. A reviewer uses the board and current artifact, records independent findings, and the owner runs configured QA before completion.

See the root [README](../README.md) for installation. Installation does not authorize changes to other projects, Memory setup, commits, or publishing. Sequential creative stages retain user approval between stages.

# PROJ-002 - Local dual-runtime agent upgrade

**Ready status:** Ready

## PROJ-002 Goal

- Combine general workflow lessons into portable Codex and Claude profiles and an on-demand game-development skill.
- Install into this user's global configuration homes with backups; do not publish or modify other project configurations.

## PROJ-002 Scope

- Fast path for low-risk work, narrow delegation, Unity runtime-owner proof, proportionate architecture, UX fidelity, multiplayer budgets, and explainable test evidence.
- Preserve project-specific decisions and private data; author reusable guidance without importing another project's history or assets.
- Verify installer lifecycle, compatibility, realistic decision scenarios, and installed file parity.

## PROJ-002 Outcome

- Updated both global policies and all 13 paired profiles: direct low-risk edits, conditional specialists/testing, scoped handoffs, optional project Memory, and inherited model settings.
- Added game-workflow with five on-demand references: Unity runtime evidence, architecture/configuration, UX/UI fidelity, networking contracts/budgets, and explainable testing.
- Added manifest-managed shared skill installation and strict parent-path checks; preserved unrelated files and pre-skill manifest compatibility.
- Installed both real global configurations in Copy mode with backups. Codex manages 21 files and Claude 20; all installed source hashes match. Existing Codex config.toml and Claude settings.json hashes are unchanged.
- No other project configuration was changed and nothing was pushed.

## PROJ-002 Verification

- PASS: scripts/validate.ps1; installed validation separately for Codex and Claude; git diff --check; skill-creator quick_validate.py; parsing 13 TOML profiles.
- PASS: tests/integration.ps1, tests/game-agent-contracts.ps1, tests/install-whatif-winps.ps1, tests/uninstall-manifest-safety.ps1.
- PASS: tests/shared-skill-install.ps1 on PowerShell 7 and Windows PowerShell 5.1: Copy lifecycle, idempotence, custom/modified-file preservation, backups, WhatIf, external skill roots, and legacy manifests.
- Independent PASS: junction redirection rejected before install/uninstall mutations; outside sentinel and legitimate installation preserved; restored installation uninstalls.
- Independent scenarios: trivial text edit stays scoped; UI diagnosis separates a layout hypothesis from runtime proof; network readiness identifies authorization and replication-cost risks without inventing execution.
- NOT RUN: Link lifecycle because symbolic-link capability is unavailable. Copy is the installed mode.
- NOT RUN: real Unity gameplay, rendered UI, multiplayer execution, runtime token/latency benchmarks. Policy size and scenario checks do not prove these outcomes.

## PROJ-002 Watch items

- Codex personal skills use the user profile's .agents/skills, separately from CodexHome. Custom/test installs must pass CodexSkillsHome consistently to install, validate, and uninstall.
- Restart sessions to load new profiles and discover the skill; review Codex hook trust in the runtime UI if needed.
- Existing personal memory-audit skill refers to a legacy central layout. Do not follow that fallback; this repository's validator checks current project-local Memory.

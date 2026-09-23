# PROJ-003 - Align Codex agents with GPT-6 model tiers

**Ready status:** Ready

## Goal

- Align the 13 Codex custom agents and local Codex defaults with the current GPT-6 model names and reasoning settings.
- Keep Claude profiles unchanged because they already use `model: inherit`.

## Scope

- Source TOML profiles, profile contract tests, validation wording, README/profile documentation.
- Local Codex global configuration and installed Codex profiles only; no other project repositories.

## Acceptance

- All 13 TOML profiles parse and match an approved model/effort tier.
- Repository and installed Codex validation pass.
- Default Codex model/subagent settings use GPT-6 Sol with medium effort.
- No Claude configuration or project-specific files are changed.

## Outcome

- Codex profiles now use GPT-6 tiers: Luna/low for 3D and project scans, Sol/medium for implementation and architecture, Sol/high for networking and verification, and Astra/medium for cross-system planning.
- Updated the local `<CodexHome>/config.toml` default model and subagent defaults to GPT-6 Sol/medium. Claude remains unchanged with inherited model settings.
- Reinstalled Codex global profiles and skill with Copy mode; installed validation passed and existing Codex settings outside managed files were preserved.

## Verification

- PASS: `tests/game-agent-contracts.ps1`
- PASS: `scripts/validate.ps1`
- PASS: installed Codex validation with explicit Codex and skill homes
- PASS: TOML parse for all 13 profiles
- PASS: `tests/integration.ps1` using temporary Codex/Claude homes, including Copy, Link WhatIf, Memory initialization and uninstall paths
- NOT RUN: live Unity gameplay or measured token/latency comparison; model tier selection is policy alignment, not a benchmark.

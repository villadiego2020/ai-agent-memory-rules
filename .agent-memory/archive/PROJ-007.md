# PROJ-007: Codex workload model routing

## Outcome

- Added `image-creator` using GPT-6 Astra/medium for raster image generation and editing.
- Added `computer-operator` using GPT-6.1 Terra/medium for screen-driven application and browser workflows.
- Kept ordinary code implementation on GPT-6.1 Sol/medium and preserved existing planning, hard-problem, high-risk, review, network, triage, and 3D tiers.
- Defined active-step routing for mixed work: image-generation tool calls are image work, screen control is Computer Use, and code-rendered graphics are code work.
- Left Claude profiles and the user's Codex default model configuration unchanged.

## Verification

- Repository validation passed.
- All 11 repository test scripts passed, including 15-profile Codex contracts and Copy-mode integration.
- Global installed AGENTS, model policy, and both new profiles matched repository SHA-256 hashes after Copy-mode installation.
- The optional Python-based skill quick validator was unavailable because Python is not installed; repository skill validation and the full PowerShell suite passed.

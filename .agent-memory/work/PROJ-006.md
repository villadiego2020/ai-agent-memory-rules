# PROJ-006 - Poteto-inspired shared workflow

**Ready status:** BLOCKED - waiting for authorized Claude Code account access and successful live peer handoff

## Scope

- Upgrade the opt-in pilot into an installed common workflow for Claude and Codex, with playbooks, model routing, real bounded CLI adapters, worktree-aware ownership, independent review, executable QA, and CI.
- Preserve existing rules, Memory scope, custom configuration, legacy manifests, and v1 task evidence without treating it as v2 verification.

## Decisions

- Adopt selected Poteto principles in a tool-agnostic skill; do not import Cursor-specific permissions, models, or automatic delegation.
- One common execution board across Git worktrees; durable Memory stays project/branch-local.
- Independent reviewer identity and QA bind to actual source fingerprint; identity is a cooperative protocol, not authentication.
- No automatic model loops, commits, merges, deployment, or external messaging.

## Remaining work

- User deferred Claude authentication because the account belongs to their company and is inaccessible. Resume the isolated live peer handoff only after authorized account access is available.

## Implemented

- Installed skill package, central model policy, six task playbooks, principles, and 13 paired role contracts. Codex implementation/advisory/review/network profiles now use GPT-6.1 Sol; Luna/Astra and Claude families remain role-specific.
- Shared primary-checkout board, overlap-checked file ownership, explicit v1 migration, independent reviewer actor, and source-bound review/QA.
- Real bounded phase dispatch, literal argv/stdin transport, read-only peer defaults, executable QA, local artifacts, safe worktree creation, and Windows CI matrix.
- Corrected the pilot limitation: its owner-authored reviewer label was an attestation rather than an independent review event.
- Snapshot hashing runs outside the board lock; task-version checks guard against changed contracts before applying results.
- High risk uses the careful tier; the hard tier requires a named difficult problem. Review keeps its independent peer tier.

## Evidence so far

- Independent full runner passed repository validation and all 11 test scripts on both PowerShell 7 and Windows PowerShell 5.1, with affected tests repeated after transport corrections.
- Skill creator validator passed. Installer Copy lifecycle, backups, custom preservation, old manifests and profile policy parity passed; Link is unavailable in this Windows session.
- Installed both real global homes: 35 Codex and 34 Claude managed files. Installed validation passed; Codex config.toml and Claude settings.json hashes stayed unchanged.
- Live Claude 2.1.288 rejected the canonical JSON Schema draft URI before inference. Adapter now omits optional schema metadata while retaining result-shape constraints; independent adapter regressions passed on both hosts.
- Live Claude accepted the adjusted schema, then stopped before inference because its OAuth session expired. Diagnostic parsing reports the authentication action without echoing private error text.
- Live Codex analysis passed against an isolated fixture: result 42 and the exact shared-contract marker. Its real result/evidence were recorded in a handoff to Claude; live receiver verification remains blocked by authentication.
- Final independent routing regressions passed on both PowerShell hosts: careful for high risk, hard only with named difficulty, unchanged peer review tier, and legacy task without hardProblem. Coordination, runtime, profile contracts and repository validator exited 0.
- Final Copy reinstall and installed validation passed for both runtimes; all 14 coordination skill files match the repository in both installations. Configuration/settings hashes remained unchanged.

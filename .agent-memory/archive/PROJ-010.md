# PROJ-010: Contract and environment evidence freshness

**Status:** Complete

## Scope

- User authorized audit improvement Phase 0–1: current test baseline and requirement/environment freshness gates.
- Preserve existing task compatibility and both Claude/Codex adapters; initial Phase 0–1 scope deferred global installation and Git publication until explicitly authorized.
- Implementation owner owns coordination source, schemas, docs and tests; orchestrator alone owns Memory.

## Acceptance

- Record actual baseline on PowerShell 7 and Windows PowerShell 5.1 without live model calls.
- Bind verification to current task requirements and explicitly scoped non-secret environment inputs.
- Reject stale review/QA after relevant changes and test legacy compatibility.
- Independent verifier inspects implementation and focused regression evidence before closure.

## Implementation

- New plans record requirementRevision; verification hashes contract fields, plan and optional project-relative JSON environment descriptor bounded to 64 KiB.
- Manual/CLI review, QA and completion reject relevant drift; during-run failures preserve failed receipts and clear execution leases.
- Legacy plans without revision retain source-only behavior until replanned; explicit descriptors do not monitor actual remote/runtime state.
- Confirmed Windows PowerShell 5.1 readiness parsing defect fixed by removing unsupported ConvertFrom-Json -Depth; readiness tests use portable map cloning and expected-stderr handling.
- Cross-host probe confirmed JSON HTML escaping differed; hash input normalizes raw HTML characters while preserving literal backslash-u sequences.

## Verification

- Exact original HEAD baseline: PowerShell 7 validator and all 12 scripts passed; Windows PowerShell 5.1 failed three coordination/readiness-path scripts.
- Final exported-source runs: all 14 then-present test scripts passed on both hosts. Aggregate runners exited 1 solely because the export initially omitted this untracked Memory detail; corrected-export and current-workspace standalone validators passed both hosts.
- After the last canonical hash change, current freshness unit and public-path integration passed both hosts; independent cross-host regression passed five PS7 to PS5.1 to PS7 read/save cases, including Thai, HTML and literal escape noncollision.
- Independent verifier reproduced and confirmed fixes for review lease cleanup, incorrect successful exit on QA drift, and cross-host escaping mismatch.
- Source diff check passed. No live Claude/model/runtime calls, global installation, dependencies, commits or push.
- Baseline timing was collected under concurrent test load; it is not a performance improvement benchmark. Logs and task-only source copies remain outside delivered project source; selective cleanup requires user choice.

## Authorized global installation

- User explicitly retained the chat/evidence and authorized global Copy installation for both Codex and Claude after Phase 0–1.
- Preserved the pre-existing Codex Unity gameplay orchestration section in repository rules before reinstalling; no global-only rule was discarded.
- Installer completed with timestamped backups; installed validation passed on PowerShell 7 and Windows PowerShell 5.1 for both platforms.
- Independent verification confirmed source/manifest parity for all 39 Codex and 36 Claude managed files; all 15 replaced files present in the selected pre-install inventory have byte-matching backups.
- Codex config.toml/hooks.json and Claude settings.json remained unchanged. Preservation evidence is bounded to the 76-file inventory; old manifest backup pre-install byte parity was not captured.
- No live Claude authentication, model calls, commit or push; existing PROJ-006 live handoff dependency remains unchanged.

## Git publication authorization

- User authorized commits and push to the existing origin/master, keeping implementation and project Memory in separate commits.
- Confirmed PS5.1 readiness correction is separated from freshness features; preserved Codex Unity rules are a separate feature commit.
- Task board, diagnostic logs, temporary source copies and local installation inventories are excluded from publication.
- Actual contributing model was verified from root, implementation-owner and independent-verifier session turn-context metadata as gpt-6.1-sol for commit attribution.

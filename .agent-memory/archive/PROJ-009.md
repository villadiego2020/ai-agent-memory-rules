# PROJ-009: Evidence-first implementation readiness

**Status:** Complete

## Scope

- Require scoped reproduction, confirmed causal evidence, minimal patch/impact and regression mapping before tracked bugfix implementation.
- Require requirements, acceptance mapping and proportionate ownership/data/interface/failure/compatibility design before medium/high feature implementation.
- Preserve the localized low-risk feature fast path and read-only investigation without a confirmed diagnosis.
- Stop implementation after two consecutive actual failed QA validation rounds until replanning with fresh investigation evidence.
- Align Codex guidance/profiles and shared workflow, verify independently, and install locally without commit/push.

## Acceptance

- Missing/invalid readiness cannot enter applicable implementation or certify completion; legacy v2 records remain readable.
- Retry lock persists across ordinary workflow mutations and cannot be reset by identical evidence.
- Existing workload routing, independent review, source snapshot and compatibility tests remain passing.
- Distinguish structural validation from semantic proof; no claim of guaranteed root-cause truth or exhaustive architecture correctness.

## Review evidence

- Guidance/profile review passed; all 15 TOML profiles parse and existing profile contracts pass.
- Initial focused readiness and existing coordination tests passed; independent adversarial review found gaps not covered by those checks.
- A summary-only replan could clear a single failure and evade the cap; corrected to preserve the streak unless fresh diagnostic evidence supports recovery.
- Passing QA must reset a consecutive-failure streak, while worktree/handoff operations must preserve diagnostic history and recovery ability.
- Independent review found coercive PowerShell comparisons accepted invalid readiness types/casing and a forbidden recursive fixture cleanup; corrected with regression coverage.
- Automatic board enforcement is scoped to all tracked bugfixes and medium/high features; other/direct work follows the evidence/stop guidance rather than a filesystem-wide guard.
- A late causeStatus contract/fixture mismatch was corrected; schema, docs and fixtures were synchronized before final source freeze and verification.

## Final outcome and evidence

- Readiness v1 is required for all tracked bugfixes and medium/high features before applicable plan/implementation/review/QA/completion operations.
- Bugfix contracts explicitly require causeStatus confirmed, reproduction/incident and causal evidence, minimal patch/impact, regression scenarios and exact acceptance coverage.
- Feature contracts require requirements and scoped ownership/data/interface/state/failure/compatibility/non-goal decisions with acceptance verification mapping; low-risk features and read-only analysis keep their short path.
- Actual failed executable/manual QA and executed-check timeouts count; passing QA resets the consecutive streak. Ordinary replans, handoffs and worktrees do not reset failures; recovery requires new diagnostic evidence not already known.
- Legacy v2 task records remain readable while missing readiness cannot certify new gated execution.
- Independent final validator, skill quick validation, diff check, adversarial input/path/legacy probes and readiness state-machine test passed; no unresolved concrete defects remained.
- All 12 individual scripts passed in the initial broad test run, whose aggregate exit was 1 because startup validation found fixture cleanup. Cleanup was corrected and final independent validation passed.
- Final readiness, coordination and runtime suites passed sequentially with source/test hashes unchanged; independent tester reran readiness and did not duplicate the final owner-run coordination/runtime suites.
- Codex global Copy installation and installed validation passed; all 39 managed source/target hashes matched. No other project's configuration was modified and no commit/push was performed for this task.
- Structural contracts cannot prove evidence truth, design quality or prevent edits outside the board; scoped independent semantic review remains necessary.

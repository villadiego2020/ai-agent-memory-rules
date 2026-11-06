# PROJ-012: Offline canaries and usage provenance

**Status:** Complete

## Scope

- User authorized Experiment 1 only: offline instrument canaries and usage provenance on PowerShell 5.1 and 7.
- Initial implementation excluded live model calls, dependency installation, rules/routing changes, global installation and Git publication; publication was authorized separately afterward.
- Implementation lead owns the standalone evaluator, library, focused tests and README usage; orchestrator owns Memory and task tracking.
- Shared board task: T-000003.

## Requirements and design

- A bounded explicit JSON trace contract supplies expected runs, evaluator results and usage observations; no provider API schema is inferred.
- A pure normalizer classifies each expected run and reconciles totals; zero-test, skipped, missing and invalid evidence cannot silently certify success.
- Global case-sensitive call IDs distinguish genuine calls, duplicates and conflicts; nested genuine calls remain counted and missing usage stays unknown.
- Provenance records exact raw-byte SHA256, fixture/evaluator identities and versions, and observed versus requested model attribution.
- An optional report is created as a new file only; evaluation never edits raw evidence or existing outputs.
- Existing coordination gates, adapters, schemas, model policy and generic/manual QA retain their current behavior.

## Acceptance and verification

- Twelve independent hand-authored core canaries and adversarial checks pass on both PowerShell hosts.
- Independent verifier probes classification, numeric/identity ambiguity, duplicate conflicts, parent cycles, provenance and output preservation.
- Existing full regression runner passes both hosts without model calls or new dependencies.
- Missing telemetry is not zero, and an offline fixture result is not evidence of live model quality or pricing.

## Focused verification

- Standalone evaluator, pure normalization library, README contract and twelve core canaries implemented without live workflow changes.
- Revised-contract focused tests, nineteen literal CLI adversarial cases and repository validators passed on PowerShell 7 and 5.1.
- Independent final public CLI verification passed 55 cases per host, including original false-complete reproductions, strict lexical/container controls and output preservation.
- Protected hashes match for nine existing rules/routing/adapters/test-runner/CI files; no dependencies or live model calls were used.

## Final regression evidence

- Actual full runner passed all sixteen test scripts and repository validation on PowerShell 7 and Windows PowerShell 5.1; independent verification confirmed the clean candidate export matched all 118 source files.
- PowerShell 7 pass was preserved and composed with the remaining PowerShell 5.1 pass; unchanged passing suites were not repeated after test-orchestration corrections.
- Default temporary-directory permissions, junction/MSYS restrictions, long Git paths and inherited module search paths required task-local execution setup; no production or global settings changed.
- Twelve raw QA logs were relocated byte-for-byte outside repository scanning; all hashes and lengths matched and five original QA receipts remain intact. Resolve original log references through `.agent-coordination/artifacts/T-000003/retained-log-map.json`.
- Shared board T-000003 completed after passing independent review and QA, before Git publication; no global installation was performed.

## Investigation and validation recovery

- Initial focused checks passed both hosts; broader validation found forbidden recursive test cleanup. Cleanup was corrected with verified boundaries and individual nonrecursive file removal; focused checks and validators then passed both hosts.
- Independent public CLI probes found false-complete reports: numeric underflow on both hosts, fractional rounding on PowerShell 7, array-valued status/containers on both hosts, and silently overwritten duplicate JSON keys.
- Confirmed cause: ConvertFrom-Json discards numeric lexemes and duplicate keys before validation; PowerShell collection member enumeration and array comparisons bypass scalar/container intent.
- Production edits stopped for fresh investigation and revised readiness rather than special-casing observed numbers.
- Revised v1 input requires canonical unsigned integer literals everywhere, rejects decoded duplicate keys, bounds raw nesting and validates scalar/container types before grading; this new unpublished contract explicitly excludes decimal/exponent/negative numeric representations.
- Verifier artifacts are task-local under the current chat's offline-verification directory; no live provider data was used.

## Limits and watch item

- Offline fixtures establish instrument behavior, not authenticated provider usage, live agent quality or token/latency improvement.
- Existing source snapshot digests differ across hosts because Sort-Object orders six test filenames differently; full file maps, HEAD and index matched. Verification used the existing PowerShell 7 coordinator and native PowerShell 5.1 child modules; the snapshot algorithm remains outside this experiment's scope.

## Publication authorization

- User retained the chat/evidence and authorized separate code and Memory commits plus push to the existing origin/master.
- Feature commit `8c1341b` contains only the evaluator, normalization library, focused tests and README usage.
- Actual contributing model gpt-6.1-sol was verified from root, implementation-lead and independent-verifier session turn-context metadata for the required commit trailer.
- Task board, raw logs, source exports, temporary fixtures and commit-message artifacts remain local and are excluded from publication.

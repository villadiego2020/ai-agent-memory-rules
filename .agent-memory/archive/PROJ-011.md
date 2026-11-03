# PROJ-011: Repair GitHub Actions workflow validation

**Status:** Complete

## Scope

- User requested CI pass on GitHub, then separate work and Memory commits and push.
- Claude company-account live handoff is explicitly deferred; no account access or authentication work.
- Implementation lead owns workflow and directly necessary CI regressions; orchestrator owns Memory and Git publication.

## Confirmed cause

- Run 41588582461 at commit 6d63347 failed before any job started, with no check runs or logs.
- Public GitHub annotation rejects line 17 shell expression: Unrecognized named-value matrix in matrix.shell.
- Repository Actions are enabled and allow all actions; no action-policy rejection was observed.

## Acceptance

- GitHub accepts the workflow and creates independent Windows checks for PowerShell 7 and 5.1.
- Both checks execute the existing full test runner and pass without weakening tests.
- Independent review verifies shell selection and failure propagation before code commit/push.
- Preserve unrelated files and local task artifacts; commit Memory separately.

## Implementation and evidence

- Bug commit a0b85da uses a literal pwsh wrapper, step TEST_HOST from the existing matrix, the unchanged full test runner and explicit child exit-code propagation.
- Independent verifier confirmed correct host selection and exit codes 0 and 23 through both child hosts; all four wrapper probes passed.
- Repository validator and diff checks passed before publication; no dependencies, test exclusions or relaxed checks.
- GitHub run 41589527507 completed successfully on commit a0b85da; both test (powershell) and test (pwsh) logs report all 15 test scripts plus repository validation passed.
- Code was committed/pushed separately from Memory; actual contributing model gpt-6.1-sol was verified from session metadata and included in the Git trailer.
- Diagnostic logs remain local; no company Claude access or authentication attempt was made.

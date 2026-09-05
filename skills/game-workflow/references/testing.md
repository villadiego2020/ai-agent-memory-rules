# Explainable game verification

Select checks by a named requirement or risk, severity, likelihood and the cheapest layer that can prove it. Do not add tests that merely copy implementation. Existing focused checks can be sufficient for a localized reversible edit.

For each check record requirement/risk, why it matters, setup/action, expected observable, actual evidence/result and limits (what a pass does and does not prove). Use a compact list or, for several parallel cases:

| Risk/requirement | Why | Setup/action | Expected observable | Actual evidence/result | Limits |
| --- | --- | --- | --- | --- | --- |

Mark unexecuted checks NOT RUN; after execution use PASS, FAIL or BLOCKED with actual assertions/logs/screenshots/video/profiler evidence. Separate a product failure from missing environment/tooling. Include version/build/topology/seed when needed for reproduction.

Select applicable game scenarios: state transitions and invalid actions; scene reload, pause, rematch, pooling and subscription cleanup; config defaults and migration/save compatibility; input navigation and rendered UI; hot-path/frame allocations.

For networking select cases from the actual contract: unauthorized or malformed client intent, host versus dedicated/headless, late join, reconnect, duplicates/reorder/loss/jitter, prediction/reconciliation/resimulation, interest boundaries, version mismatch, and bandwidth/memory thresholds at stated load. Do not assume one framework's behavior in another version.

Compilation proves compile compatibility, not gameplay or visual behavior. Report expected/actual, severity, evidence and source location for a failure; label suspected root causes as inference. State reduced risks and remaining coverage limits. A tester may edit only explicitly assigned test files, never production code or Memory.

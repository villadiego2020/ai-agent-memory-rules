# Explainable game verification

Select checks by a named requirement or risk, severity, likelihood and the cheapest layer that can prove it. Do not add tests that merely copy implementation. Existing focused checks can be sufficient for a localized reversible edit.

For each check record requirement/risk, why it matters, setup/action, expected observable, actual evidence/result and limits (what a pass does and does not prove). Use a compact list or, for several parallel cases:

| Risk/requirement | Why | Setup/action | Expected observable | Actual evidence/result | Limits |
| --- | --- | --- | --- | --- | --- |

Mark unexecuted checks NOT RUN; after execution use PASS, FAIL or BLOCKED with actual assertions/logs/screenshots/video/profiler evidence. Separate a product failure from missing environment/tooling. Include version/build/topology/seed when needed for reproduction.

## Test handoff for every delivered work item

The orchestrator always lists both EditMode and PlayMode tests after each task or independently delivered work item, including small edits. Inspect the relevant test files/assemblies before naming runnable tests; use exact names and paths or suite/filter names. For each entry explain its purpose, expected observable and current status/evidence. Clearly label proposed missing coverage as not yet implemented. If a mode has no applicable tests, state why; non-Unity work still reports both modes as not applicable.

Before executing pending Unity tests, the orchestrator presents this inventory and asks in the user's language whether AI should run them or the user will run them in Unity Test Runner. Wait for the choice unless that scope was already authorized. Previously run tests retain their actual results; do not automatically rerun them or ask for the same authorization again. When there are no runnable tests, explain the gap without offering an unavailable run. Subagents supply the inventory/results to the orchestrator and follow its authorized scope; they do not ask separately or start Unity tests before the choice.

For manual execution, give the EditMode/PlayMode tab, test assembly/suite/filter, required scene/setup and expected outcome. Await the user's actual results; do not infer a pass from their choice to run manually. While required evidence is pending, report "Implementation complete; verification pending" and leave required QA/work open. Independent inspection, compilation and other authorized checks may proceed. Follow applicable Unity session ownership rules; a test-run choice does not authorize shared Main Editor Play Mode.

Select applicable game scenarios: state transitions and invalid actions; scene reload, pause, rematch, pooling and subscription cleanup; config defaults and migration/save compatibility; input navigation and rendered UI; hot-path/frame allocations.

For networking select cases from the actual contract: unauthorized or malformed client intent, host versus dedicated/headless, late join, reconnect, duplicates/reorder/loss/jitter, prediction/reconciliation/resimulation, interest boundaries, version mismatch, and bandwidth/memory thresholds at stated load. Do not assume one framework's behavior in another version.

Compilation proves compile compatibility, not gameplay or visual behavior. Report expected/actual, severity, evidence and source location for a failure; label suspected root causes as inference. State reduced risks and remaining coverage limits. A tester may edit only explicitly assigned test files, never production code or Memory.

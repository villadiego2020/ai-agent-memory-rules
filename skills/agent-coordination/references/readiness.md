# Implementation readiness and validation retry gate

For a tracked bugfix at any risk, or a medium/high feature, investigate and record a readiness file before `plan`. The file is project relative JSON, bounded to 64 KiB. `plan -ReadinessFile work/readiness.json` validates and embeds its contents in the task. A file under `.agent-coordination/` is also accepted for local board fixtures. Low risk localized features keep the shorter existing plan. Analysis stays read only and needs no readiness file.

Bugfix readiness v1 records observed behavior and the confirmed causal explanation. A reproduction or incident trace and causal evidence must be cited; an unconfirmed theory is not a confirmed cause. If the cause is still uncertain, continue investigation through analysis and do not dispatch implementation. Describe the smallest intended change, its impact, and regression scenarios. Every task acceptance item must appear exactly once in `acceptanceMapping` with an actual verification method:

```json
{
  "schemaVersion": 1,
  "kind": "bugfix",
  "expected": "Existing saves load without changing player inventory",
  "actual": "Version 2 saves clear inventory on load",
  "reproductionEvidence": ["work/repro.md: case SAVE-17"],
  "causeStatus": "confirmed",
  "confirmedCause": "Migration skips inventory when version is 2",
  "causeEvidence": ["work/investigation.md: trace and source branch"],
  "minimalChange": "Run inventory migration for version 2 records",
  "impact": "Save load migration and version 2 compatibility",
  "regressionChecks": [
    { "scenario": "Load a version 2 save with inventory", "verification": "Focused save fixture plus Editor observation" }
  ],
  "acceptanceMapping": [
    { "acceptance": "Old saves load", "verification": "Focused save fixture plus Editor observation" }
  ]
}
```

For a substantive feature, record requirements and acceptance traceability, then describe ownership, data, interfaces, states, failure handling, compatibility, and non goals. Each design item is a short decision or `N/A: <reason>` when genuinely outside the scope. Keep the design scoped to the actual system; the contract does not require inventing layers or integrations.

```json
{
  "schemaVersion": 1,
  "kind": "feature",
  "requirements": ["Persist the player's chosen language"],
  "design": {
    "ownership": "Settings service owns the preference",
    "data": "One locale key in existing settings storage",
    "interfaces": "UI calls settings service; language change event refreshes visible text",
    "states": "Default, selected, and unsupported locale fallback",
    "failureHandling": "Unreadable stored value falls back to default and surfaces diagnostics",
    "compatibility": "Existing settings without the locale key load the default",
    "nonGoals": "N/A: no content translation is included in this feature"
  },
  "acceptanceMapping": [
    { "acceptance": "Language selection persists after restart", "verification": "Save, restart, and read localized UI" }
  ]
}
```

The validator checks shape, bounded input, exact acceptance coverage, and required evidence fields. It cannot establish whether evidence is genuine or whether the causal claim is true. The owner and independent reviewer must inspect those claims against the source and observations. Recording readiness is part of authorized task execution and is not an extra user approval checkpoint.

After each implementation attempt, record QA against the changed source. For tracked bugfixes and medium/high features, failed executable checks and an explicit `qa -Verdict fail -Summary ... -Evidence ...` for observed runtime/manual failure each count as one failed validation round. An executed acceptance check that times out counts; authentication, CLI startup, missing tool access, reviewer infrastructure, and source changes during QA do not. A passing QA clears the consecutive failure streak while receipts retain the history. Two consecutive failed rounds block further implementation and QA until the owner investigates and submits a new plan. That plan needs a valid readiness file with `newEvidence` containing a diagnostic fact absent from the prior known evidence. A replan without fresh evidence preserves the failure streak. A valid fresh-evidence replan clears it and invalidates old review and QA. The validator normalizes case and surrounding whitespace when comparing evidence text, but cannot judge whether a claimed new fact is actually new; the reviewer must check it. Handoff, recover, and worktree operations do not reset the counter.

The board mechanically gates its own dispatch, review, QA, and completion operations. It cannot prevent someone from editing files outside the board. Agents should record the QA outcome of each changed patch before attempting another production change.

# PROJ-008: Workload routing integration

**Status:** Complete

## Scope

- Connect explicit Codex implementation workloads to the CLI model selector, preserving legacy defaults and review tiers.
- Align installed primary and default subagent model with GPT-6.1 Sol/medium.
- Resolve direct-execution versus workload handoff rules and verify child tool availability.
- Update installed memory-audit to use only the current project's .agent-memory.

## Acceptance

- Routing tests cover image, computer, code, legacy risk routing, and unsupported combinations.
- Independent verification reviews changed dispatch and focused checks.
- Live probes distinguish configured/requested models from observed tool access and actual artifacts.
- Installed source hashes match; no commit, push, or unrelated project changes.

## Observed evidence

- Native unpinned child requested as Astra/medium successfully generated one PNG through imagegen; backend identity was not independently introspected.
- Native unpinned child requested as Terra/medium successfully read Computer Use inventory; no screen mutation was attempted.
- The active session rejected the newly installed image-creator agent type; added explicit model/effort worker fallback instead of assuming registry hot reload.
- Primary and default-subagent TOML values are Sol 6.1/medium; parsed comparison confirms unrelated configuration preserved.
- Installed Codex validation passed and all 37 managed source/target hashes matched.
- Existing Python runtime was found via uv python find; the earlier PROJ-007 claim that Python was not installed was an executable-discovery limitation.
- Independent review identified stale sleep-mode state in the new workload fixture; owner reset pass mode, restored 4-second timeout, and focused runtime checks passed.

## Final verification

- Independent system-tester review found no remaining concrete defects.
- Full repository validation and all 11 test scripts passed; installed validation was rechecked successfully.
- Image/computer/code CLI tests captured actual stub argv and run receipts; unsupported runtime/phase workload combinations reject.
- Installed memory-audit now resolves only the current project, skips missing Memory, rejects legacy central-root options, and refuses linked Memory boundaries before reading.
- Independent mocked filesystem-probe checks covered Windows drive-relative, rooted, UNC, traversal and linked-root boundaries; ordinary local archive links still pass.
- Actual symlink/junction lifecycle checks were not run because runtime capability/policy prevented fixture creation; mocked checks are not claimed as real link lifecycle evidence.
- Native child tool tests prove raster output and Computer Use inventory access, not guaranteed automatic routing on every natural-language request or screen mutation fidelity.
- No commit or push was performed; unrelated global configuration was preserved with a pre-edit backup.

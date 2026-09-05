# Proportionate game architecture

Start with the real state owner, lifetime, callers and reasons to change. Prefer one cohesive type until independent ownership, lifecycle, dependency boundary, testing or substitution justifies another type/interface/assembly. Avoid wrappers and single-method abstractions introduced only to resemble a pattern.

Use intention-revealing names, short methods at one abstraction level, few purposeful parameters, explicit side effects and shallow control flow. Group options when they form a real concept; do not mechanically replace every signature or enforce DRY across code that changes for different reasons.

Events describe facts that occurred, need no return, and may have independent listeners. Direct calls suit owned commands/queries, immediate results, required ordering and hot paths. Define subscription lifetime, disposal, ordering, idempotency and debugging where events cross owners; avoid chains that hide essential control flow.

Reuse existing configuration sources. Group designer balance/content and runtime/environment settings by domain and lifecycle; avoid one asset per scalar. Distinguish compile-time invariants from tunable data and versioned save/network contracts. Define typed access, defaults, validation and override precedence; add migration/versioning when persistence or interoperability requires it. Never store secrets in shared content/config assets.

Use exceptions for exceptional failures handled at an appropriate boundary. Expected absence, rejected gameplay actions and hot-path outcomes use explicit Try/result/status forms that fit existing conventions. Never swallow context or leave empty catches; define who recovers and logs without duplicating logs at every layer.

For a material new pattern, explain the evidenced problem, simpler alternative, added complexity and when removal would be appropriate. A short rationale suffices; do not create a pattern dossier for a localized edit. For cross-system changes describe state/data flow, ownership and incremental migration, with save/network compatibility and verifiable acceptance.

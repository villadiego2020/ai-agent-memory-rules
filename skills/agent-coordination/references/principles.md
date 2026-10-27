# Principles for tracked work

This is a scoped adaptation of pstack Poteto Mode principles for Claude and Codex. Read the actual repository and task before choosing a playbook. Ask only for information that cannot be inferred safely from the project or user context.

Define the result, acceptance evidence, owner, and file scope before implementation. Use the smallest useful change and divide larger work into units that can be reviewed. For a bug, prove the cause or clearly label an inference; for performance, measure before and after. Prefer tools and existing project checks over increasing instruction volume.

An inferred cause is a reason to investigate, not permission to patch production. Establish expected/actual behavior, reproduction or incident evidence, runtime/data ownership and causal evidence before a bugfix; explain the smallest repair, impact and before/after regression scenarios. A controlled diagnostic experiment should have an explicit hypothesis, observable result and rollback, and must not be presented as a confirmed fix.

For substantive system work, connect user outcomes and constraints to requirements, ownership, interfaces/data flow, states, relevant failure/security/compatibility decisions, and acceptance checks. Resolve material requirement conflicts before implementation; routine design choices do not require a user approval gate. Keep the design proportionate and state why a dimension is not applicable instead of inventing extension layers.

When a patch contradicts the explanation or broadens scope, return to investigation immediately. After two consecutive failed validation rounds, do not add a third patch until fresh diagnostic evidence supports a revised plan. Carry forward failed attempts and rejected hypotheses through handoffs; renaming an actor, changing a worktree or restating the plan is not a reset. A machine can check readiness fields, mappings, counters and evidence freshness; an independent reviewer must assess whether the evidence actually supports the design or causal claim.

Protect attention and context: keep handoffs concise, carry forward rejected hypotheses, and avoid parallel workers on overlapping files. Use a separate worktree when parallel writes are justified. Review the real artifact, run the configured QA checks, and record remaining limits honestly. External authority for messages, deployment, merge, spending, destructive operations, and Memory updates remains governed by user and project rules.

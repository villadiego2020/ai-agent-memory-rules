# Principles for tracked work

This is a scoped adaptation of pstack Poteto Mode principles for Claude and Codex. Read the actual repository and task before choosing a playbook. Ask only for information that cannot be inferred safely from the project or user context.

Define the result, acceptance evidence, owner, and file scope before implementation. Use the smallest useful change and divide larger work into units that can be reviewed. For a bug, prove the cause or clearly label an inference; for performance, measure before and after. Prefer tools and existing project checks over increasing instruction volume.

Protect attention and context: keep handoffs concise, carry forward rejected hypotheses, and avoid parallel workers on overlapping files. Use a separate worktree when parallel writes are justified. Review the real artifact, run the configured QA checks, and record remaining limits honestly. External authority for messages, deployment, merge, spending, destructive operations, and Memory updates remains governed by user and project rules.

# Shared board and bounded dispatch

Run from the project root. The commands are PowerShell examples; `scripts/coordination.ps1` and `scripts/orchestrate.ps1` are wrappers around the installed shared skill scripts.

```powershell
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 init -ProjectPath .
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 new -ProjectPath . -Stack unity -Kind bugfix -Risk high -Title 'Fix save load' -Goal 'Old saves load' -Acceptance 'Reproduction passes' -Owner 'codex:lead' -OwnedFile 'Assets/Scripts/SaveLoader.cs'
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 plan -ProjectPath . -Id '<task-id>' -Owner 'codex:lead' -Summary 'Root cause and scope' -Evidence 'work/repro.md' -ReadinessFile 'work/readiness.json' -CheckFile 'work/checks.json'
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 review -ProjectPath . -Id '<task-id>' -Reviewer 'claude:reviewer' -Verdict pass -Summary 'Reviewed diff' -Evidence 'work/review.md'
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 qa -ProjectPath . -Id '<task-id>' -Owner 'codex:lead' -Summary 'Unity Editor loaded old save' -Evidence 'work/editor-observation.md'
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 complete -ProjectPath . -Id '<task-id>' -Owner 'codex:lead' -QaSummary 'Old save loaded; checks passed' -Evidence 'work/editor-observation.md'
```

The plan check file is a JSON array in the project. For example, `work/checks.json` can contain:

Bugfixes and medium/high features also use the [readiness contract](readiness.md). A low risk localized feature keeps the short plan command without `-ReadinessFile`. Investigation with an unconfirmed cause stays read only.

```json
[
  {
    "name": "build",
    "executable": "dotnet",
    "arguments": ["build", "MyApp.sln"],
    "workingDirectory": ".",
    "timeoutSeconds": 300
  }
]
```

Use literal argument arrays, never a shell command string. For Unity, pair appropriate batch checks with actual Editor or build observations. A project may choose a different executable and an explicit reason when machine checks cannot cover the acceptance criterion.

`new` reserves the files and assigns the owner immediately; no second claim is needed. When transferring implementation to a different actor, use `handoff -Owner 'codex:lead' -NextOwner 'claude:implementer' -Summary 'Scope and next step' -Evidence 'work/handoff.md'`, then the receiver runs `claim -Owner 'claude:implementer'`. This changes the owner, clears prior review/QA, and requires checks on the new final artifact. An independent reviewer can use `review -Reviewer` while the implementation owner stays assigned, as shown above.

Inspect a single phase before authorizing a real CLI run:

```powershell
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\orchestrate.ps1 -ProjectPath . -Id '<task-id>' -Phase review -Runtime claude
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\orchestrate.ps1 -ProjectPath . -Id '<task-id>' -Phase review -Runtime claude -Actor 'claude:reviewer' -Execute -TimeoutSeconds 600
```

Default dispatch prints the prompt and arguments. `-Execute` runs one bounded phase. Inspect its artifacts and board state before the next phase. Use `-Runtime codex` to route the same contract to Codex; CLI permissions still apply independently.

For a Codex implementation, set the active workload explicitly when the task is code, raster image generation, or screen-driven Computer Use:

```powershell
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\orchestrate.ps1 -ProjectPath . -Id '<task-id>' -Phase implement -Runtime codex -Workload image
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\orchestrate.ps1 -ProjectPath . -Id '<task-id>' -Phase implement -Runtime codex -Workload computer
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\orchestrate.ps1 -ProjectPath . -Id '<task-id>' -Phase implement -Runtime codex -Workload code
```

`image` selects Astra/medium, `computer` selects 6.1 Terra/medium, and `code` selects 6.1 Sol/medium at low or medium risk. High-risk code keeps Sol/high; a named `HardProblem` keeps Astra/high for every workload. High-risk image and computer tasks keep their workload model and still require independent review. The omitted/default workload preserves legacy phase/risk routing. Other phases and Claude reject an explicit workload. Preview and run receipts show the workload and selected role. This bounded CLI adapter does not guarantee access to image-generation or Computer Use tools: the worker must report `needs-input` if the needed tool is absent. For an ordinary interactive chat, the parent must actually delegate to the appropriate profile; the policy file alone cannot change a running chat's model.

An authorization covering the whole task also covers its ordinary implementation/review/QA steps. The manager may invoke these steps without asking the user to approve each phase again. Publishing, messaging and irreversible actions keep their existing authority boundaries.

`qa -TimeoutSeconds 1200` bounds the whole QA run (default 20 minutes; maximum two hours), in addition to each check's timeout. A failing/timeout check or changed source prevents completion. Output capture is bounded. Task records, acceptance check files and structured agent reports also have size limits; split excessively large tasks rather than loading transcripts into the board.

The CLI adapter embeds the small shared workflow and matching playbook in its prompt, and records the exact chosen model/effort. It does not depend on the model automatically loading a subagent profile. CLI model aliases and account availability remain runtime-specific. The Codex model choice follows the [official model guidance](https://learn.chatgpt.com/docs/models); adapter flags are checked against the installed clients and [Codex CLI](https://learn.chatgpt.com/docs/developer-commands?surface=cli) / [Claude CLI](https://code.claude.com/docs/en/cli-reference) references. Do not silently substitute an unavailable model.

Risk and difficulty are separate. High-risk implementation selects the `careful` tier and still requires independent review. Use `new -HardProblem 'Describe the unusually difficult problem'` (or set it with `plan`) to select `hard` for planning/implementation/analysis. An explicit empty `plan -HardProblem ''` restores ordinary phase routing. Review retains the independent peer-review tier.

If Claude reports an expired OAuth session, run `claude auth login` yourself, then resume the same task/phase. Authentication is not stored or repaired through the board. A failed runtime call leaves its receipt and a recoverable task state; do not switch models or bypass permissions to conceal the failure.

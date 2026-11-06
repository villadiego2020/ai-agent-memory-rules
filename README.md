# AI Agent Memory Rules

กติกาและ specialist agents 13 คู่สำหรับ Codex และ Claude Code ติดตั้งบนเครื่องครั้งเดียว ใช้ได้ทุกโปรเจกต์ที่เปิดด้วย configuration home นี้ ไม่ต้อง copy, commit หรือ push agents ไปแต่ละโปรเจกต์

## Workflow ตามความเสี่ยง

- อ่าน/อธิบาย/วิเคราะห์ และแก้จุดเล็กความเสี่ยงต่ำ: agent หลักทำเอง พร้อมตรวจเฉพาะจุด
- งาน implementation ที่มีเนื้อหา: lead ตาม stack หนึ่งคน เพิ่ม advisor เฉพาะ decision ที่จำเป็น
- งานใหญ่ข้ามระบบ: system-planner ระบุ dependency และ ownership ก่อนลงมือ
- ความเสี่ยง network, save, security, critical UI หรือผู้ใช้ขอ: system-tester ตรวจอิสระพร้อมเหตุผลและหลักฐาน
- งาน 3D: ผู้ใช้ตรวจผลงานแต่ละขั้นก่อนเริ่มขั้นต่อไป

ค่า model/effort ของทั้งสอง runtime รวมไว้ใน [model-policy.json](skills/agent-coordination/model-policy.json) และโปรไฟล์แต่ละตัวตรงกับ policy: Codex ใช้ Astra/medium สำหรับสร้างหรือแก้ภาพ raster ผ่าน image-generation tool, 6.1 Terra/medium สำหรับ Computer Use ที่ควบคุมแอปหรือเบราว์เซอร์, Luna/low สำหรับ triage และ 3D, 6.1 Sol/medium สำหรับเขียนโค้ดทั่วไป, 6.1 Sol/high สำหรับโค้ดความเสี่ยงสูง/review/network และ Astra/medium สำหรับ plan; Astra/high ใช้เมื่อ task ระบุ `-HardProblem` ว่าโจทย์ยากอย่างไรเท่านั้น งานผสม route ตามขั้นตอนที่กำลังทำจริง ส่วน Claude ใช้ haiku, sonnet/high, sonnet/xhigh และ opus/high ตามบทบาท โปรไฟล์ Codex มีลำดับสูงกว่าค่า spawn และ default ส่วน Claude รับ per-task model override ได้ ใช้ `agent-coordination` สำหรับงานที่ต้องติดตามหรือส่งต่อข้าม Claude/Codex และ `game-workflow` สำหรับงานเกม/Unity ที่เกี่ยวข้อง ไม่เปิดทีมอัตโนมัติ

มี implementation leads (`unity-expert`, `web-expert`), workload specialists (`image-creator`, `computer-operator`), read-only advisors (`uxui-expert`, `game-architect`, `network-expert`, `backend-architect`), planner/tester/project-manager และ 3D sculptor/modeller/rigger/animator รวม 15 Codex roles; Claude ยังใช้ 13 shared roles เดิม

ผู้ใช้พิมพ์งานตามปกติได้ กติกาจะให้ agent เลือก skill และส่งต่อเมื่อ model/effort ไม่ตรงกับงาน โดยตรวจว่า agent ลูกเข้าถึงเครื่องมือที่ต้องใช้ก่อน งานเล็กที่โมเดลตรงอยู่แล้วทำตรงได้ หาก child ไม่มี image tool หรือ Computer Use ให้รายงานข้อจำกัดแล้วใช้ parent ที่เข้าถึงเครื่องมือได้ โดยแจ้งว่าโมเดลไม่ตรง tier ที่ขอ การโหลด skill ไม่เปลี่ยนโมเดลของแชตปัจจุบัน และไฟล์ policy ไม่ใช่ตัวสลับโมเดลอัตโนมัติของ Codex ตัว CLI dispatch ใช้ `-Workload` แบบ explicit ตามคู่มือคำสั่ง จึงต้องแยกผลตรวจ config/argv ออกจากผลทดสอบงานจริง

งานบั๊กต้องมีอาการที่คาดหวัง/เกิดจริง หลักฐาน reproduce หรือ incident และหลักฐานยืนยันสาเหตุก่อนแก้ production งาน feature ความเสี่ยงกลาง/สูงต้องมี requirement/non-goal กับ design ที่เชื่อม acceptance ไปยังผู้รับผิดชอบ interface/state และการทดสอบตามความเสี่ยง ใช้ [readiness contract](skills/agent-coordination/references/readiness.md) ใน tracked plan งานเล็กยังใช้ขั้นตอนสั้นได้ หากผลขัดกับสมมติฐาน ขอบเขตบาน หรือ validation ล้มเหลวสองรอบติด ให้กลับไปเก็บหลักฐานและวางแผนใหม่ ตัวตรวจบังคับโครงสร้างและสถานะได้ ส่วนความจริงของ root cause และคุณภาพ design ต้องตรวจจากหลักฐานโดยผู้ตรวจอิสระ

ตัวนับและเงื่อนไขอัตโนมัติใช้กับงาน tracked bugfix และ feature ความเสี่ยงกลาง/สูงที่เข้า readiness gate งานประเภทอื่นหรือการแก้นอก board ยังต้องอาศัย agent ทำตามกติกาหยุดและตรวจหลักฐาน จึงไม่ใช่กลไกห้ามแก้ไฟล์ทั้งเครื่อง

## ติดตั้งบน Windows

รองรับ PowerShell 5.1 และ PowerShell 7 รันจาก root ของ repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Both -Mode Copy -WhatIf
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Both -Mode Copy
```

| Artifact | Codex | Claude Code |
| --- | --- | --- |
| Rules | `<CodexHome>/AGENTS.md` | `<ClaudeHome>/CLAUDE.md` |
| Profiles | `<CodexHome>/agents/*.toml` | `<ClaudeHome>/agents/*.md` |
| Shared skills | `<userprofile>/.agents/skills/{game-workflow,agent-coordination}/` | `<ClaudeHome>/skills/{game-workflow,agent-coordination}/` |
| Memory loader | SessionStart + SubagentStart hooks | อ่านตาม rules ไม่มี hook เพิ่ม |

Codex skills ใช้ user discovery path ตาม [เอกสาร Codex](https://learn.chatgpt.com/docs/build-skills) แยกจาก config home กำหนด `-CodexSkillsHome` ได้และต้องส่งค่าเดียวกันตอน validate/uninstall ส่วน `-CodexHome` และ `-ClaudeHome` override config roots ได้ ค่าเริ่มต้นใช้ CODEX_HOME / CLAUDE_CONFIG_DIR ถ้ามี หรือ user profile

`Copy` ใช้ง่ายที่สุด อัปเดตด้วยคำสั่งเดิมเพิ่ม `-Force` หลังตรวจ diff ส่วน `Link` เห็น source เปลี่ยนทันทีและอาจต้องเปิด Windows Developer Mode ตัวติดตั้งจัดการ skill ทีละไฟล์ จึงเก็บ custom files ใน directory เดียวกันไว้

Conflict หยุดก่อนแทนที่; `-Force` สำรองไฟล์ลง `<configuration home>/.ai-agent-memory-rules/backups/` พร้อม manifest ก่อนเปลี่ยน เก็บ agents/hooks/skills อื่นไว้และไม่แก้ `config.toml` หลังติดตั้งเปิด task/session ใหม่หรือ restart runtime เพื่อโหลด profiles/skills ล่าสุด ตรวจและเชื่อถือ Codex hooks ผ่าน `/hooks` ตาม UI รุ่นที่ใช้

## ตรวจและถอนการติดตั้ง

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Installed -Platform Codex
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Installed -Platform Claude
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Platform Both -WhatIf
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Platform Both
```

ถอนเฉพาะไฟล์ที่ manifest เป็นเจ้าของและผ่าน allowlist ไฟล์ที่แก้หลังติดตั้งทำให้หยุด ใช้ `-Force` เมื่อต้องการสำรองแล้วถอน Custom files และ Memory ในโปรเจกต์คงอยู่ Manifest รุ่นเก่าที่ไม่มี skill ถอน agents/rules เดิมได้

## Memory เป็นทางเลือก

อ่านจาก `<project-root>/.agent-memory/` เท่านั้น เมื่อมีอยู่จะอ่านสี่ indexes: `MEMORY.md`, `user_and_feedback.md`, `project_open_work.md`, `project_archive.md` และอ่านรายละเอียดใน `work/`, `archive/`, `analysis/` ตามงาน Subagents อ่านอย่างเดียว; agent หลักดูแลการเขียน ไม่มี fallback ไปโปรเจกต์อื่น และ installer ไม่สร้าง Memory อัตโนมัติ

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-memory.ps1 -ProjectPath "<path-to-project>"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -ProjectPath "<path-to-project>"
```

Migration ต้องสั่งเองผ่าน `scripts/migrate-memory.ps1 -LegacyMemoryPath "<source>" -ProjectPath "<project>" -WhatIf` ก่อนตรวจแล้วรันจริง ไม่มี auto commit/push หรือเปลี่ยนโปรเจกต์อื่นตามการติดตั้งนี้ Memory ที่โหลดเป็นบริบทของโมเดล ห้ามเก็บ secrets หรือข้อมูลส่วนบุคคลอ่อนไหว และเลือก version/ignore ตาม policy โปรเจกต์

## งานร่วมกันระหว่าง Claude และ Codex

| หัวข้อ | ของเดิมและ pilot | รุ่นใหม่ |
| --- | --- | --- |
| บทบาท | 13 specialist profiles และ rules แยกตาม runtime | คงบทบาทเดิม เพิ่ม workflow skill ที่ติดตั้งเหมือนกันทั้งสองฝั่ง |
| Model | แต่ละ profile กำหนด tier; Codex ใช้ GPT-6 Sol ในงานทั่วไป | policy กลางเลือกตาม phase/risk; Codex ใช้ GPT-6.1 Sol และแยก routine/implement/review/planning/hard |
| กระบวนการ | routing ตามความเสี่ยงและข้อความ handoff | playbooks สำหรับ feature, bugfix, refactor, analysis, performance และ prototype |
| Shared state | Memory เป็นบริบท; pilot มี task JSON ต่อ checkout | task v2 ใช้ board เดียวร่วมทุก worktree พร้อม owner/session และขอบเขตไฟล์ที่ตรวจ overlap |
| Review | pilot ให้ owner กรอกชื่อ reviewer | ผู้ตรวจเป็น actor แยกจากผู้ลงมือและผูก verdict กับ source snapshot |
| QA | pilot เก็บข้อความรับรอง | รัน executable/argv จริง เก็บ exit code, timeout และ logs; ปฏิเสธผลเก่าเมื่อ source เปลี่ยน |
| CLI | ผู้ใช้สลับ Claude/Codex เอง | adapter ส่ง prompt/ผลลัพธ์มาตรฐานผ่าน CLI ทีละ phase ภายใต้ permissions เดิม |
| การตรวจอัตโนมัติ | PowerShell tests แยกไฟล์ | test runner กลางและ Windows CI matrix สำหรับ PowerShell 5.1/7 |

ระบบเดิมมี rules, 13 specialist profiles, `game-workflow`, project Memory และ coordination pilot ที่บันทึก owner/handoff/review ผ่านไฟล์ แต่ยังต้องสลับ runtime และยืนยัน QA ด้วยคนทั้งหมด รุ่นนี้เพิ่ม [agent-coordination skill](skills/agent-coordination/SKILL.md) ที่ทั้งสอง runtime ติดตั้งเหมือนกัน, policy เลือก model จาก phase, playbooks ตามชนิดงาน, board กลางที่ worktrees เห็นร่วมกัน, bounded CLI dispatch และ QA ที่รัน checks ที่ระบุไว้จริง ดู [คู่มือคำสั่ง](skills/agent-coordination/references/commands.md) และ [playbooks](skills/agent-coordination/references/playbooks.md).

งานเล็กที่ย้อนกลับได้ให้ agent หลักทำตรง งานที่มีความเสี่ยงหรือส่งต่อข้าม runtime ใช้ลำดับ `issue → plan → claim → implement → handoff → independent review → qa → complete` โดยระบุ acceptance, ไฟล์ที่รับผิดชอบและ checks ตั้งแต่ต้น งาน bugfix เริ่มจาก reproduction/root cause; performance เริ่มจาก baseline; analysis บันทึกแหล่งที่มาและความไม่แน่นอน QA ต้องตรวจผลกับ artifact สุดท้ายก่อนปิดงาน

ตัวอย่างเริ่ม board ในโปรเจกต์เดียวและดู prompt ของ review โดยยังไม่เรียก CLI:

```powershell
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 init -ProjectPath .
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\coordination.ps1 new -ProjectPath . -Stack unity -Kind bugfix -Risk high -Title 'Fix save load' -Goal 'Old saves load' -Acceptance 'Reproduction passes' -Owner 'codex:lead' -OwnedFile 'Assets/Scripts/SaveLoader.cs'
pwsh -NoProfile -File C:\Work\git\ai-agent-memory-rules\scripts\orchestrate.ps1 -ProjectPath . -Id '<task-id>' -Phase review -Runtime claude
```

`orchestrate.ps1 -Execute` เรียก CLI เพียงหนึ่ง phase พร้อม timeout และ artifact ให้ตรวจต่อ ไม่มีการ approve, merge, deploy หรือเขียน Memory อัตโนมัติ Identity ใน board บอกความรับผิดชอบ ไม่ใช่การยืนยันตัวตน; file lock ใช้กับ local filesystem และผลจริงยังขึ้นกับ runtime, permissions, checks, Unity Editor/หน้าจอที่เข้าถึงได้ ไม่มีข้อมูล benchmark ว่าเร็วขึ้นเท่าไร

การเริ่มใช้: ระยะสั้นให้ pilot กับโปรเจกต์เดียวและงานสองประเภท เช่น bugfix กับ feature แล้วดูเวลาส่งต่อและ gate ที่ล้มเหลว ระยะกลางจึงขยายไปหลาย worktrees และ CI หลังยืนยันว่าขอบเขตไฟล์และ QA checks มีเสถียรภาพ สำหรับ Unity ใช้ Editor/runtime evidence, เว็บและแอปใช้ rendered flow กับ API/build checks, debug ใช้ก่อน/หลัง reproduction, analysis ใช้หลักฐานและข้อจำกัด โดยเลือก reference ของ `game-workflow` เพิ่มเมื่อเป็นงานเกม

## Commit convention

ใช้เมื่อมีการสั่ง commit ตาม workflow โปรเจกต์ ไม่ใช่คำสั่งให้ commit อัตโนมัติ:

- Work files and Memory must be separate commits by default.
- Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.
- All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.
- A commit containing only `.agent-memory/**` uses `[Memory] <message>`.
- Never mix unrelated Bug and Feature work; split them into separate commits.
- Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.
- Commit Memory to the current project repository and branch.
- Push follows the current project's normal authorization and policy. Never auto-push merely because Memory changed.

## ขอบเขตการตรวจ

รันชุดตรวจเดียวกับ CI ด้วย `pwsh -NoProfile -File scripts/test.ps1` หรือ `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1`. ชุดตรวจใช้โปรเจกต์/CLI จำลองและไม่เรียก model ที่มีค่าใช้งานจริง การผ่านในเครื่องไม่ใช่ผลการรัน GitHub Actions; CI จะทำงานเมื่อมี push/PR ตาม policy ของโปรเจกต์

ทดสอบ scripts ด้วย temporary homes/projects, installer lifecycle, manifest safety, WhatIf, Memory validation และ profile contracts จาก `tests/*.ps1` หลักฐานนี้ตรวจ tooling และกติกา ไม่ใช่การทดสอบ gameplay ใน Unity Editor หรือรับรองคุณภาพ agent ทุก model

Released under the [MIT License](LICENSE).

## Verification freshness

Every new `plan` records `-RequirementRevision` (default `1`, 1–128 characters).
Replan with a new revision when requirements evolve; replan clears prior review/QA.
Verification receipts also hash goal, acceptance, kind/risk/stack, owned paths and
plan contents, so edits to the board contract cannot reuse old verification even
though the board is excluded from the source snapshot.

Optionally supply `plan -EnvironmentFile environment.json`: a project-relative
JSON descriptor, at most 64 KiB, containing non-secret tool/runtime/session version
identifiers chosen by the project. Its bytes are fingerprinted at review, QA and
completion. An ignored descriptor is still checked. Changes during QA fail the
receipt without counting as a failed implementation attempt. No environment
variables, credentials, automatic tool probes or remote state are collected.
Missing/invalid descriptors fail closed; restore or replan before verification.
A descriptor only detects changes its owner records; this is not a live environment
monitor. Legacy v2 plans without `requirementRevision` retain source-only behavior
until explicitly replanned. Both manual review and CLI review produce freshness
receipts. Identities remain cooperative rather than authenticated.

## Optional offline evaluation (Experiment 1)

`scripts/evaluate-offline.ps1` normalizes a supplied synthetic evidence manifest;
it never runs an evaluator, model CLI, provider API, or commands from that file.
It is a standalone instrument, with no changes to live QA gates, manual checks,
model routing, or the two-failure recovery rule. Run it on either PowerShell 5.1
or 7:

```powershell
pwsh -NoProfile -File scripts/evaluate-offline.ps1 -InputPath evidence.json -OutputPath report.json
```

The explicit v1 input contract is JSON (UTF-8, optional BOM), for example:

```json
{
  "schemaVersion": 1,
  "evaluator": { "id": "synthetic-tests", "version": "1" },
  "fixture": { "id": "example", "version": "1" },
  "expectedRuns": [
    { "runId": "case-1", "result": {
      "status": "completed", "outcome": "pass",
      "passed": 1, "failed": 0, "skipped": 0
    } }
  ],
  "usage": [
    { "callId": "global-call-1", "parentCallId": null,
      "runtime": "synthetic", "requestedModel": "requested-id",
      "observedModel": "observed-id", "observationSource": "fixture-receipt",
      "inputTokens": 100, "outputTokens": 20,
      "cacheReadTokens": 0, "cacheWriteTokens": 0 }
  ]
}
```

Each expected run contains its result inline; an omitted/null result is `missing`.
Run IDs are nonblank, unique, case-sensitive strings. Completed results require
all three nonnegative integer counts and a consistent `pass`/`fail` outcome:
any failed tests require `fail`; no failed tests require `pass`. Zero executed
tests (including skipped-only results) are `ungraded`. Other result statuses are
`timedOut`, `cancelled`, and `skipped`; malformed results classify `invalid`.
Every expected run receives exactly one terminal class. The denominator exposes
all classes and reconciles `expected = graded + ungraded + infrastructureFailed
+ cancelled`; missing, invalid and timed-out results are infrastructure failures,
and skipped evaluators remain ungraded rather than quality passes/failures.

Usage observations are manifest-level **exclusive per-call** counters, not
inclusive parent-span counters. Supply a globally scoped logical/provider call
identity as `callId`; repeat the same identity only for observations of that same
call. Equal normalized observations count once; distinct calls, including genuine
nested child calls, count separately. Parent IDs must resolve, with no cycles.
Conflicting observations of an identity expose a conflicted call, suppress its
canonical evidence, and make authoritative totals unknown; no observation wins.
The script cannot infer genuine call identity or translate provider envelopes.

Every numeric token in the input must use a canonical unsigned integer literal
from 0 through 9007199254740991 (`0` or digits starting with `1`–`9`). Decimal,
exponent, negative and leading-zero spellings are rejected before parsing,
including in extra fields. Token metrics may also be omitted/null; strings and
booleans are rejected. This avoids host-dependent rounding and underflow.
Cache reads and writes remain separate and are never added to input/output tokens.
Missing metrics/calls produce null authoritative totals, with `knownCalls`,
`expectedCalls` and a labelled decimal-string `knownSubtotal` for partial evidence.
If an otherwise complete aggregate exceeds the safe JSON integer range, its
numeric total is null with `status: "overflow"` and decimal-string `exactTotal`.
Missing usage is unknown, never a measured zero. Requested model identity is
distinct from observed identity; `observedModel` requires `observationSource`.
Without observed identity attribution is `unavailable`. Sources are supplied
evidence labels, not authenticated provider claims.

Reports retain evaluator/fixture identity and version, normalizer version, exact
raw byte count and SHA256 (including any BOM). Replay does not rewrite the trace.
Input defaults to a 4 MiB byte limit (`-MaxBytes`, maximum 16 MiB); each manifest
supports at most 4096 runs and 4096 usage observations, with at most 64 nesting
levels. Duplicate object property names (including case variants and escaped
equivalents) are rejected before parsing. Identity containers and run/call entries
must be objects; status/outcome and text fields must be scalar strings.
Structural/usage errors reject the manifest. Extra fields are ignored semantically
but still follow these lexical rules. Use this normalized contract rather than
passing an arbitrary provider response.

Exit **0** means every expected run passed and all usage metrics and observed
model attribution are complete. Exit **2** still emits a full JSON report, with
`certificationStatus: "incomplete"` and reasons, when evaluation is non-pass or
telemetry is incomplete/conflicted/overflowed. Malformed input and output errors
exit **1**. This is evidence completeness, not certification of agent quality.
The optional output must be a new file in an existing directory; same-directory
staging and a non-overwriting move preserve existing files and prevent a partial
destination. Omitting `-OutputPath` writes JSON only to standard output.

`tests/offline-evaluation.ps1` supplies twelve independent literal-oracle canaries
plus adversarial boundary checks on both hosts through the existing test runner.
They measure the offline instrument, not live provider permissions, agent quality,
or a speed/token improvement.

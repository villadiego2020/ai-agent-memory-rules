# AI Agent Memory Rules

กติกาและ specialist agents 13 คู่สำหรับ Codex และ Claude Code ติดตั้งบนเครื่องครั้งเดียว ใช้ได้ทุกโปรเจกต์ที่เปิดด้วย configuration home นี้ ไม่ต้อง copy, commit หรือ push agents ไปแต่ละโปรเจกต์

## Workflow ตามความเสี่ยง

- อ่าน/อธิบาย/วิเคราะห์ และแก้จุดเล็กความเสี่ยงต่ำ: agent หลักทำเอง พร้อมตรวจเฉพาะจุด
- งาน implementation ที่มีเนื้อหา: lead ตาม stack หนึ่งคน เพิ่ม advisor เฉพาะ decision ที่จำเป็น
- งานใหญ่ข้ามระบบ: system-planner ระบุ dependency และ ownership ก่อนลงมือ
- ความเสี่ยง network, save, security, critical UI หรือผู้ใช้ขอ: system-tester ตรวจอิสระพร้อมเหตุผลและหลักฐาน
- งาน 3D: ผู้ใช้ตรวจผลงานแต่ละขั้นก่อนเริ่มขั้นต่อไป

Codex profiles ไม่ pin model/effort; Claude ใช้ `model: inherit` ตามรุ่นที่ผู้ใช้เลือก ไม่มีการเปิดทีมอัตโนมัติ Shared `game-workflow` skill โหลดสำหรับงานเกม/Unity ที่เกี่ยวข้อง แล้วอ่านเฉพาะ reference ที่ต้องใช้: Unity runtime, architecture, UX/UI, networking และ explainable testing

มี implementation leads (`unity-expert`, `web-expert`), read-only advisors (`uxui-expert`, `game-architect`, `network-expert`, `backend-architect`), planner/tester/project-manager และ 3D sculptor/modeller/rigger/animator รวม 13 roles

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
| Shared skill | `<userprofile>/.agents/skills/game-workflow/` | `<ClaudeHome>/skills/game-workflow/` |
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

ทดสอบ scripts ด้วย temporary homes/projects, installer lifecycle, manifest safety, WhatIf, Memory validation และ profile contracts จาก `tests/*.ps1` หลักฐานนี้ตรวจ tooling และกติกา ไม่ใช่การทดสอบ gameplay ใน Unity Editor หรือรับรองคุณภาพ agent ทุก model

Released under the [MIT License](LICENSE).

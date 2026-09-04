<div align="center">

# ai-agent-memory-rules

*ทีม Subagent + กฎการทำงานสำหรับ Claude Code ที่เอาไปใช้ซ้ำได้ — ดึงมาจาก setup ส่วนตัวที่ใช้งานจริงทุกวัน*

![License](https://img.shields.io/badge/license-MIT-blue)
![Made for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-orange)
![Language](https://img.shields.io/badge/lang-ไทย-red)
![Type](https://img.shields.io/badge/type-template-lightgrey)

</div>

## สารบัญ

- 🗂️ [หน้าตาโดยรวม](#หน้าตาโดยรวม)
- 🧩 [ปัญหาที่รีโปนี้แก้](#ปัญหาที่รีโปนี้แก้)
- 💡 [แนวคิดหลัก](#แนวคิดหลัก)
  - 🚦 [Lead-by-stack](#1-lead-by-stack)
  - 🗺️ [Routing table](#2-routing-table)
  - 🤝 [Subagent vs Agent Team](#3-subagent-vs-agent-team)
  - 🔁 [Loop-safety](#4-loop-safety)
  - 🧠 [Memory convention](#5-memory-convention)
- ⚙️ [วิธีติดตั้ง](#วิธีติดตั้ง)
- 🎨 [Customize](#customize-ให้เข้ากับทีมของคุณ)
- 📝 [หมายเหตุ](#หมายเหตุ)

## หน้าตาโดยรวม

```
claude-agent-rules/
├── RULES.md          ← link เป็น ~/.claude/CLAUDE.md (โหลดอัตโนมัติทุกโปรเจกต์)
└── agents/            ← link เป็น ~/.claude/agents/
    ├── README.md       roster เต็ม + model tier
    ├── web-expert.md, unity-expert.md, ...          lead (แก้โค้ดจริง)
    ├── uxui-expert.md, backend-architect.md, ...     ที่ปรึกษา (ออกแบบอย่างเดียว)
    └── system-tester.md, project-manager.md          ตรวจ/รายงาน
```

Symlink ครั้งเดียว → ทุกโปรเจกต์บนเครื่องได้ทั้งกฎและ agent อัตโนมัติ ไม่ต้อง setup ซ้ำ

## ปัญหาที่รีโปนี้แก้

Claude Code ตั้งต้นมาแบบ session เดี่ยว: สั่งอะไรแก้ตรงนั้นทันที ไม่มีใครทัก ไม่มีคนตรวจซ้ำ ปิด session แล้วความจำหายหมด งานหน้าต้องไล่บริบทใหม่ทั้งก้อน — 3 ปัญหา 3 กฎ:

| ปัญหา | กฎที่ใช้แก้ |
|---|---|
| ไม่มีวินัยว่าใครแก้โค้ด | **Lead-by-stack** — orchestrator ห้ามแก้เอง ต้อง spawn agent เฉพาะทางเสมอ |
| เปิด multi-agent เกินจำเป็น เปลือง token | **Team ปิดเป็น default** ต้องผ่านเกณฑ์ + user ยืนยันก่อนเปิด |
| ความจำหายทุกจบ session | **Memory convention** แยกงานเปิด/จบเป็นไฟล์คนละชุด มี index สแกนเร็ว |

## แนวคิดหลัก

### 1. Lead-by-stack

- Orchestrator (Claude หลักที่คุยกับ user) **ห้าม Edit/Write ไฟล์โปรเจกต์เองเด็ดขาด** แม้งานเล็กแค่บรรทัดเดียว
- ต้อง spawn **lead** = agent เฉพาะทางตาม stack เสมอ (เว็บ → `web-expert`, Unity → `unity-expert`)
- เหตุผล: แยก "คุยกับ user" ออกจาก "ลงมือทำ" — โค้ดผ่าน agent ที่ pin model/tool scope เฉพาะงาน แก้สม่ำเสมอ ตรวจย้อนหลังง่าย
- ข้อยกเว้นเดียว: ไฟล์ระบบของตัวเอง (memory, `RULES.md`, `agents/*.md`, `settings.json`) — ไม่ใช่โค้ดโปรเจกต์

### 2. Routing table

- `RULES.md` มีตาราง "บริบทงาน → ที่ปรึกษา (ออกแบบ) → lead (ลงมือ)" เช่น UI เว็บ → `uxui-expert` ออกแบบ → `web-expert` ทำจริง
- ที่ปรึกษาอ่าน/วิเคราะห์/ออกแบบอย่างเดียว ไม่มีสิทธิ์แก้ไฟล์
- **เรียกที่ปรึกษาเฉพาะตอนงานแตะด้านนั้นจริง** — บั๊กชัดเจนใช้ lead ตัวเดียวพอ งานใหญ่ค่อยให้ `system-planner` วางแผนก่อนกระจายงาน

### 3. Subagent vs Agent Team

| | Subagent (default) | Agent Team |
|---|---|---|
| ทำงานยังไง | spawn ไปทำ → รวมผลเอง | teammates คุยกันเอง + shared task list |
| คุยกันเองระหว่างทำ | ไม่ได้ | ได้ |
| token | ปกติ | แพงกว่าหลายเท่า |
| ใช้เมื่อไหร่ | ทุกงาน | ผ่านเกณฑ์ + user ยืนยันเท่านั้น |

เปิด Team ได้ต้องผ่าน 2 ด่าน: **(1)** ต้องเถียง/ต่อรองกันเอง**ระหว่างทำ**จริงไหม — รวมผลทีหลังได้ก็พอเป็น Subagent · **(2)** แบ่งก้อนอิสระไม่ชนไฟล์กันได้ไหม — sequential ไม่เข้าเกณฑ์ ผ่านทั้งคู่แล้วต้องเสนอ user ก่อนเปิดทุกครั้ง ห้ามเปิดเองเงียบๆ

### 4. Loop-safety

Default = turn-based (สั่ง → ทำ → รายงาน → รอสั่งต่อ) ยกเป็น loop อัตโนมัติได้ต้องผ่านครบ 3 ข้อ:

- **Stop condition วัดได้ด้วยเครื่อง** — exit code/ตัวเลข ห้ามใช้ "คิดว่าเสร็จ"
- **จบได้เองไม่รอคนอื่น** — ติด dependency ภายนอก (asset, การ์ดใบอื่น, คนตัดสินใจ) ห้ามทำ loop
- **มีเพดานรอบชัดเจน** — max round + เงื่อนไขยอมแพ้ ไม่มีเพดาน = ห้ามรัน

### 5. Memory convention

Assistant ที่ไม่มีระบบจำจะลืมบริบท session ก่อนหน้า และไล่สืบปัญหาเดิมซ้ำที่เคย REFUTED ไปแล้ว — แก้ด้วยการแยกงานเปิด/จบชัดเจน:

```
work/PROJ-XXX.md        = detail งานเปิด (root cause สด, plan ระหว่างทำ)
archive/PROJ-XXX.md     = detail งานจบสนิท (root เต็ม, REFUTED list, บทเรียน)
analysis/ref-<slug>.md  = ความรู้/audit ที่ไม่ผูกการ์ด

project_open_work.md    = index งานเปิดทุกใบ (1:1 กับ work/)
project_archive.md      = index งานจบทุกใบ แยกโซนตามชนิดงาน
```

**index สั้นเสมอ** (1-2 บรรทัด/ใบ) สแกนเร็วว่า "เคยเจอมั้ย" ไม่ต้องเปิด detail ทุกไฟล์ — เปิด `archive/` เต็มเฉพาะตอนสงสัย regression จริงๆ · รายละเอียดครบใน `RULES.md` หัวข้อ "Memory convention"

## วิธีติดตั้ง

1. Clone ไว้ที่ไหนก็ได้:
   ```
   git clone <repo-url> ~/.claude-agent-rules
   ```

2. Link เข้า config ระดับ user ของ Claude Code:

   **macOS/Linux:**
   ```
   ln -s ~/.claude-agent-rules/agents ~/.claude/agents
   ln -s ~/.claude-agent-rules/RULES.md ~/.claude/CLAUDE.md
   ```

   **Windows (PowerShell — admin หรือ Developer Mode):**
   ```powershell
   New-Item -ItemType SymbolicLink -Path "$HOME\.claude\agents" -Target "$HOME\.claude-agent-rules\agents"
   New-Item -ItemType SymbolicLink -Path "$HOME\.claude\CLAUDE.md" -Target "$HOME\.claude-agent-rules\RULES.md"
   ```

   มีไฟล์เดิมอยู่แล้ว → สำรองก่อน (`mv`/`Rename-Item`) ค่อย symlink ทับ

3. อัปเดตภายหลัง: `git -C ~/.claude-agent-rules pull` — เป็น symlink มีผลทันที ไม่ต้อง link ใหม่

## Customize ให้เข้ากับทีมของคุณ

- เปลี่ยนชื่อ callsign/role ของ agent ใน `agents/` ให้ตรง stack จริง (เพิ่ม/ลดได้)
- ปรับตาราง routing ใน `RULES.md`
- ปรับ pattern รหัสการ์ด (`<ชื่อย่อโปรเจกต์>-XXX`) ให้ตรง naming ของคุณ

## หมายเหตุ

รีโปนี้**ตั้งใจไม่มี** memory หรือประวัติงานจริงของโปรเจกต์ใดๆ — เป็นข้อมูลส่วนตัวที่แต่ละคนสร้างเองตาม convention ใน `RULES.md` รีโปนี้เป็นแค่ template ที่เอาไปใช้ซ้ำได้เท่านั้น

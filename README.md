# claude-agent-rules

ทีม Subagent + กฎการทำงานสำหรับ Claude Code ที่เอาไปใช้ซ้ำได้ — วินัย "lead-by-stack" (แตะโค้ดต้องผ่าน agent เฉพาะทาง), เกณฑ์ตัดสิน Subagent vs Agent Team, กฎความปลอดภัยของ loop/automation, และ convention เก็บ memory/เอกสารโปรเจกต์แบบยั่งยืน — ดึงมาจาก setup ส่วนตัวที่ใช้งานจริงทุกวัน

## หน้าตาโดยรวม

```
claude-agent-rules/
├── RULES.md          ← link เป็น ~/.claude/CLAUDE.md (Claude Code โหลดอัตโนมัติทุกโปรเจกต์)
└── agents/            ← link เป็น ~/.claude/agents/    (agent definition ระดับ user)
    ├── README.md       (roster เต็ม + model tier)
    ├── web-expert.md, unity-expert.md, ...   (lead — แก้โค้ดจริง)
    ├── uxui-expert.md, backend-architect.md, ...  (ที่ปรึกษา — ออกแบบอย่างเดียว)
    └── system-tester.md, project-manager.md   (ตรวจ/รายงาน)
```

หลัง symlink แล้ว ทุกครั้งที่เปิด Claude Code ในโปรเจกต์ไหนก็ตามบนเครื่อง จะได้ทั้งกฎใน `RULES.md` และ agent ทั้งหมดใน `agents/` มาด้วยอัตโนมัติ — ไม่ต้อง setup ซ้ำต่อโปรเจกต์

## ปัญหาที่รีโปนี้แก้

Claude Code ตั้งต้นมาแบบ session เดี่ยว: สั่งอะไรก็แก้โค้ดตรงนั้นทันที ไม่มีใครทัก ไม่มีคนที่สองมาตรวจ และพอปิด session ความจำทุกอย่างหายหมด — งานหน้าต้องไล่บริบทใหม่ทั้งก้อน

Template นี้ปะ 3 ปัญหานั้นด้วยกฎ 3 ชุด:

1. **ไม่มีวินัยว่าใครแก้โค้ด** → บังคับ **lead-by-stack**: orchestrator (Claude หลักที่คุยกับ user) ห้ามแก้โค้ดโปรเจกต์เองเด็ดขาด ต้อง spawn agent เฉพาะทางเสมอ แม้งานเล็กแค่ไหน
2. **เปิด multi-agent เกินจำเป็นจนเปลือง token** → Agent Team (agent คุยกันเอง/เถียงกันเอง) ถูกปิดเป็น default และต้องผ่านเกณฑ์ 3 ข้อ + user ยืนยันก่อนเปิดทุกครั้ง — งานส่วนใหญ่ subagent ตัวเดียวพอ
3. **ความจำหายทุกจบ session** → บังคับ memory convention ที่แยก "งานเปิด" กับ "งานจบ" เป็นไฟล์คนละชุด มี index กลางให้สแกนเร็ว ไม่ต้องไล่อ่านทุกไฟล์ทุกครั้ง

## แนวคิดหลัก

### 1. Lead-by-stack — ทำไม orchestrator ห้ามแก้โค้ดเอง

Orchestrator คือ Claude ตัวหลักที่คุยกับ user โดยตรง กฎเหล็กคือ **ห้าม Edit/Write ไฟล์โปรเจกต์เองเด็ดขาด** แม้จะรู้คำตอบอยู่แล้วหรืองานเล็กแค่บรรทัดเดียว — ต้อง spawn "lead" ซึ่งเป็น agent เฉพาะทางตาม stack ของงานนั้นเสมอ (เช่นโปรเจกต์เว็บ → `web-expert`, โปรเจกต์ Unity → `unity-expert`)

เหตุผล: แยกหน้าที่ "คุยกับ user / ตัดสินใจภาพรวม" ออกจาก "ลงมือทำ" ทำให้ทุกการแก้โค้ดผ่าน agent ที่ pin model + system prompt + tool scope ไว้เฉพาะงานนั้นจริงๆ ไม่ปนกับบริบทคุยทั่วไปของ orchestrator — ผลคือแก้โค้ดสม่ำเสมอกว่า ตรวจสอบย้อนหลังได้ง่ายกว่า (รู้ว่า agent ไหนแก้อะไร)

ไฟล์ที่ orchestrator แก้เองได้มีข้อยกเว้นเดียว: ไฟล์ระบบของตัวเอง (memory, `RULES.md`, `agents/*.md`, `settings.json`) — ไม่ใช่ไฟล์โค้ดของโปรเจกต์

### 2. Routing table — ใครคิด ใครทำ

`RULES.md` มีตารางแม็พ "บริบทงาน → ที่ปรึกษา (ออกแบบ) → lead (ลงมือ)" เช่น งาน UI เว็บ → `uxui-expert` ออกแบบก่อน แล้ว `web-expert` เป็นคนแก้โค้ดจริง — ที่ปรึกษาอ่าน/วิเคราะห์/ออกแบบได้อย่างเดียว ไม่มีสิทธิ์แก้ไฟล์

จุดสำคัญ: **ที่ปรึกษาเรียกเฉพาะตอนงานแตะด้านนั้นจริง** ไม่ใช่เรียกครบทีมทุกครั้ง — งานเล็ก/บั๊กชัดเจน lead ตัวเดียวพอ, งานใหญ่ที่แตะหลายระบบค่อยให้ `system-planner` วางแผนก่อนแล้วกระจายงานตามตาราง

### 3. Subagent vs Agent Team — ทำไม Team ปิดเป็น default

| | Subagent (default) | Agent Team |
|---|---|---|
| ทำงานยังไง | orchestrator spawn ไปทำ → รับผลกลับมารวมเอง | teammates คุยกันเอง มี shared task list |
| agent คุยกันเองระหว่างทำ | ไม่ได้ | ได้ |
| token | ปกติ | แพงกว่าหลายเท่า |
| ใช้เมื่อไหร่ | ทุกงาน | เฉพาะที่ผ่านเกณฑ์ + user ยืนยัน |

Team จะเปิดได้ก็ต่อเมื่อผ่านทั้ง 2 ด่าน: (1) งานต้องการให้ agent เถียง/ต่อรองกันเอง**ระหว่างทำ**จริงๆ — ถ้าแค่ต่างคนต่างทำแล้วเอาผลมารวมทีหลังได้ ก็เป็น Subagent พอ (2) แบ่งงานเป็นก้อนอิสระที่ไฟล์ไม่ชนกันได้ — งาน sequential (คิด→ทำ→ตรวจ) ไม่เข้าเกณฑ์ ผ่านทั้งสองข้อแล้วต้องเสนอ user ก่อนเปิดทุกครั้ง ไม่มีข้อยกเว้นให้เปิดเองเงียบๆ

### 4. Loop-safety — งานไหนวนอัตโนมัติได้

Default คือ turn-based (พิมพ์สั่ง → ทำ → รายงาน → รอสั่งต่อ) การจะยกงานขึ้นเป็น loop ที่วนเองต้องผ่านครบ 3 ข้อ:

- **Stop condition วัดได้ด้วยเครื่อง** — มี exit code/ตัวเลขที่ตอบผ่าน-ไม่ผ่านได้ ห้ามใช้ "คิดว่าเสร็จ" เป็นเกณฑ์
- **จบได้ด้วยตัวเอง ไม่รอคนอื่น** — งานที่ติด dependency ภายนอก (รอ asset, รอการ์ดใบอื่น, รอคนตัดสินใจ) ห้ามทำเป็น loop
- **มีเพดานรอบชัดเจน** — กำหนด max round + เงื่อนไขยอมแพ้ ไม่มีเพดาน = ห้ามรัน

### 5. Memory convention — กันบริบทหายข้าม session

จุดที่คุ้มที่สุดของ template นี้: assistant ที่ไม่มีระบบจำอะไรเลย จะ (ก) ลืมบริบทของ session ก่อนหน้า และ (ข) ไล่สืบบั๊กหรือปัญหาเดิมซ้ำที่เคยแก้/เคยตัดทิ้งไปแล้ว (REFUTED) โดยไม่รู้ตัว

โครงไฟล์แก้ปัญหานี้ด้วยการแยก "งานเปิด" กับ "งานจบ" ออกจากกันชัดเจน:

```
work/PROJ-XXX.md        = detail งานที่ยังเปิดอยู่ (root cause สด, plan ระหว่างทำ)
archive/PROJ-XXX.md     = detail งานที่จบสนิทแล้ว (root เต็ม, REFUTED list, บทเรียน)
analysis/ref-<slug>.md  = ความรู้/audit ที่ไม่ผูกการ์ดไหน

project_open_work.md    = index รวมงานเปิดทุกใบ (1:1 กับ work/)
project_archive.md      = index รวมงานจบทุกใบ แยกโซนตามชนิดงาน
```

หลักการ: **index สั้นเสมอ** (1-2 บรรทัด/ใบ) ให้สแกนเร็วว่า "เคยเจอเรื่องนี้มั้ย" โดยไม่ต้องเปิด detail ทุกไฟล์ — เปิด `archive/` เต็มเฉพาะตอนสงสัยว่าเจอ regression ของเคสเดิมจริงๆ เท่านั้น รายละเอียดกฎทั้งหมด (naming, flow ปิดงาน, เพดานไฟล์) อยู่ใน `RULES.md` หัวข้อ "Memory convention"

## วิธีติดตั้ง

1. Clone รีโปนี้ไว้ที่ไหนก็ได้ เช่น

   ```
   git clone <repo-url> ~/.claude-agent-rules
   ```

2. Link เข้า config ระดับ user ของ Claude Code เพื่อให้มีผลกับทุกโปรเจกต์บนเครื่องอัตโนมัติ

   **macOS/Linux:**
   ```
   ln -s ~/.claude-agent-rules/agents ~/.claude/agents
   ln -s ~/.claude-agent-rules/RULES.md ~/.claude/CLAUDE.md
   ```

   **Windows (PowerShell — ต้องรันแบบ admin หรือเปิด Developer Mode):**
   ```powershell
   New-Item -ItemType SymbolicLink -Path "$HOME\.claude\agents" -Target "$HOME\.claude-agent-rules\agents"
   New-Item -ItemType SymbolicLink -Path "$HOME\.claude\CLAUDE.md" -Target "$HOME\.claude-agent-rules\RULES.md"
   ```

   ถ้า `~/.claude/agents` หรือ `~/.claude/CLAUDE.md` มีอยู่แล้ว ให้ย้ายสำรองก่อน (`mv`/`Rename-Item`) ค่อย symlink ทับ

3. อัปเดตภายหลัง: `git -C ~/.claude-agent-rules pull` — เพราะเป็น symlink การแก้ไฟล์มีผลทันทีไม่ต้อง link ใหม่

## Customize ให้เข้ากับทีมของคุณ

- เปลี่ยนชื่อ callsign/role ของ agent ใน `agents/` ให้ตรงกับ stack ที่ทีมคุณใช้จริง (เพิ่ม/ลด agent ได้ตามต้องการ)
- ปรับตาราง routing ใน `RULES.md` ให้ตรงกับ agent set ของคุณ
- ปรับ pattern รหัสการ์ดใน memory convention (`<ชื่อย่อโปรเจกต์>-XXX`) ให้ตรงกับ naming ของโปรเจกต์คุณ

## หมายเหตุ

รีโปนี้**ตั้งใจไม่มี** memory หรือประวัติงานจริงของโปรเจกต์ใดๆ — นั่นเป็นข้อมูลส่วนตัวที่แต่ละคนต้องสร้างขึ้นเองตาม convention ที่เขียนไว้ใน `RULES.md` (หัวข้อ Memory convention) รีโปนี้เป็นแค่ template ที่เอาไปใช้ซ้ำได้เท่านั้น

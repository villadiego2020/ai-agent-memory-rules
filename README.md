# claude-agent-rules

ทีม Subagent + กฎการทำงานสำหรับ Claude Code ที่เอาไปใช้ซ้ำได้ — วินัย "lead-by-stack" (แตะโค้ดต้องผ่าน agent เฉพาะทาง), เกณฑ์ตัดสิน Subagent vs Agent Team, กฎความปลอดภัยของ loop/automation, และ convention เก็บ memory/เอกสารโปรเจกต์แบบยั่งยืน — ดึงมาจาก setup ส่วนตัวที่ใช้งานจริงทุกวัน

## มีอะไรในนี้

- **`agents/`** — agent definition 14 ตัว (`.md` แบบ Claude Code subagent) พร้อม role ชัดเจน (lead ที่แก้โค้ดจริง vs ที่ปรึกษาอ่านอย่างเดียว) — ดู `agents/README.md` สำหรับตาราง roster เต็ม + เหตุผลเลือก model tier ต่อ agent
- **`RULES.md`** — กฎที่บังคับใช้จริง: กฎเหล็ก lead-by-stack, routing table, เกณฑ์เปิด Agent Team, กฎ loop engineering, memory convention เต็มรูปแบบ

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

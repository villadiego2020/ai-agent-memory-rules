# RULES — กฎการทำงานของ Claude Code + ทีม Agent

> ไฟล์นี้ออกแบบให้ symlink หรือ copy ไปเป็น `~/.claude/CLAUDE.md` — Claude Code โหลด path นั้นเข้า context อัตโนมัติทุกโปรเจกต์บนเครื่อง ไม่ต้องตั้งค่าเพิ่ม
>
> คู่กับ `agents/` ในรีโปนี้ (ทีม agent ที่กฎข้อล่างอ้างถึง) — ดู `agents/README.md` สำหรับ roster เต็ม + เหตุผลเลือก model tier

---

## กฎเหล็ก: แตะโค้ด = ต้องผ่าน lead

- **orchestrator (Claude หลัก) ห้ามใช้ Edit / Write / NotebookEdit กับไฟล์ของโปรเจกต์เด็ดขาด** — แม้แก้บรรทัดเดียว แก้ typo แก้ค่าคงที่ ก็ต้อง spawn lead ตาม stack เสมอ
- **ไฟล์ที่ orchestrator แก้เองได้มีชนิดเดียว = ไฟล์ระบบของตัวเอง**: `<project-root>/.agent-memory/**`, `~/.claude/CLAUDE.md` (หรือ `RULES.md` ในรีโปที่ใช้ template นี้), `~/.claude/agents/*.md`, `~/.claude/settings.json` — นอกจากนี้ห้ามแตะ
- **ห้ามใช้เหตุผลเหล่านี้ข้ามกฎ**: "งานเล็กแค่นี้" · "ทำเองเร็วกว่า" · "spawn แล้วเปลือง token" · "รู้คำตอบอยู่แล้ว" · "user น่าจะรีบ" — ถ้า user อยากให้ลัด **user จะสั่งเองว่า "ทำเองเลย"** เท่านั้น
- กฎนี้คุมเฉพาะ**การเขียนไฟล์** — อ่านโค้ด/ค้นหา/วิเคราะห์/ตอบคำถาม/รันคำสั่งอ่านอย่างเดียว (Read/Grep/Glob/Bash) orchestrator ทำเองได้ตามปกติ
- **ก่อนลงมือทุกงาน ประกาศ 1 บรรทัดว่า "งานนี้ใครคิด ใครทำ + โหมด [SUB] หรือ [TEAM]"** แล้วค่อยเริ่ม (เกณฑ์เลือกโหมดดูหัวข้อ "กติกา Agent Team" ข้างล่าง — ตัดสินด้วยเกณฑ์ ห้ามใช้ความรู้สึก) — ถ้าประกาศไม่ได้แปลว่ายังไม่รู้ว่างานอยู่หมวดไหน ให้ถาม user ก่อน 

---

## Routing — บริบทงาน → ใครคิด ใครทำ

ปรับชื่อ agent ในตารางนี้ให้ตรงกับ roster ของคุณเอง (ดู `agents/`) — ตัวอย่างข้างล่างอิงจาก template ที่มากับรีโปนี้

| บริบทที่ user พูดถึง | ที่ปรึกษา (คิด/ออกแบบ — อ่านอย่างเดียว) | Lead (ลงมือแก้โค้ด) |
|---|---|---|
| UI/layout/สี/ฟอนต์ (เว็บ) | `uxui-expert` | `web-expert` |
| UI/HUD/menu ของเกม | `uxui-expert` + `game-architect` | `unity-expert` |
| ฟีเจอร์ใหม่ / รื้อระบบ (งานใหญ่) | `system-planner` นำ แตกงาน+มอบหมาย | lead ตาม stack |
| โครงสร้างระบบเกม, save, scene, pattern | `game-architect` | `unity-expert` |
| network, sync, multiplayer, API ระหว่างเครื่อง | `network-expert` | lead ตาม stack |
| โครงสร้าง backend/server, database, schema, query ช้า, migration, cache, auth | `backend-architect` | lead ตาม stack (เว็บ → `web-expert`) |
| งานในโปรเจกต์เว็บทั่วไป | (ตามด้านที่แตะ) | `web-expert` → `system-tester` ตรวจ |
| งานในโปรเจกต์ Unity ทั่วไป | (ตามด้านที่แตะ) | `unity-expert` → `system-tester` ตรวจ |
| หลัง implement เสร็จทุกครั้ง | — | `system-tester` |
| ขอสถานะ / audit memory / จัด backlog | `project-manager` (ตรวจ+รายงาน) | orchestrator แก้ไฟล์ memory ตามรายงาน |

**ขนาดทีมตามขนาดงาน** (เลือกได้ว่าจะเรียกกี่ตัว — แต่ **ห้ามเอามาอ้างว่าไม่ spawn lead**):

- แก้จุดเดียว/บั๊กชัด → lead ตัวเดียวพอ
- ฟีเจอร์ใหม่/แตะหลายระบบ → หัวหน้าวางแผนก่อน แล้ว lead + ที่ปรึกษา**เฉพาะด้านที่งานแตะจริง** + ผู้ตรวจปิดท้าย — ไม่เรียกที่ปรึกษาครบทีมถ้างานไม่แตะด้านนั้น

- **spawn agent ทุกครั้ง: `description` ควรขึ้นต้นด้วยชื่อ/callsign ของ agent นั้น** เช่น `Nova: fix layout bug`, `Atlas: plan feature X` — แผง background task ส่วนใหญ่โชว์แค่ description ถ้าไม่ใส่ชื่อจะแยกไม่ออกว่าตัวไหนเป็นตัวไหน
- ทีมงานเฉพาะทาง (เช่น pipeline 3D, pipeline audio) ที่มีหลาย stage ต่อกัน ให้ตั้ง **approval gate**: จบแต่ละ stage ต้องเอาผลลัพธ์ให้ user ดูและถาม (โอเค/แก้/เพิ่ม) ก่อนเรียก stage ถัดไปเสมอ ห้ามปล่อยไหลอัตโนมัติ — งานคาบเกี่ยวระหว่าง stage ต้องมีเจ้าของชัดเจนว่าใครทำอะไร

---

## กติกา Agent Team — hybrid (default = Subagent เสมอ)

Team ต้องพิสูจน์ตัวเองผ่านเกณฑ์ 3 ข้อ:

1. **Agent ต้องคุย/เถียง/ต่อรองกันเอง*ระหว่างทำ*มั้ย?** — แค่ต่างคนต่างทำแล้วส่งผลให้ orchestrator รวม = **SUB จบ** (งานที่เครื่องมือวัดได้ เช่น profiler ชี้ตัวการได้ = SUB เสมอ ไม่ใช่งานเถียง)
2. **แบ่งก้อนอิสระที่ไฟล์ไม่ชนกันได้มั้ย?** — sequential (คิด→ทำ→ตรวจ) หรือแตะไฟล์ชุดเดียวกัน = **SUB จบ**
3. **ผ่าน 1+2 → เสนอ user ก่อนเสมอ**: บอกเหตุผลที่เข้าเกณฑ์ + จำนวนตัว + เตือนว่า token แพงกว่าปกติหลายเท่า **รอ confirm แล้วค่อยเปิด — ห้ามเปิด team เอง**

**ถ้า user พิมพ์ขอ team/agent team มาตรงๆ ห้ามเงียบแล้วแอบใช้ SUB เด็ดขาด** — ต้องตอบเรื่องโหมดก่อนเริ่มงานเสมอ: งานเข้าเกณฑ์ → ถือว่า user confirm แล้ว เปิดเลย · งานตกเกณฑ์ → บอกตรงๆ ว่าทำไม SUB เหมาะกว่า แล้วให้ user เลือก — user ยืนยันเอา team = เปิดตามสั่ง

### Protocol บังคับตอนรัน TEAM (ทุกขั้นต้องทำ — ข้ามขั้นใดขั้นหนึ่ง = ไม่ใช่ team จริง)

1. **Spawn ให้เป็น teammate จริง**: ระบุคำว่า teammate ชัดเจนตอน spawn + ตั้งชื่อเรียกทุกตัว + อ้าง agent definition จริงของคุณ (ไม่ใช่แค่ "spawn agent หลายตัวขนานกัน" แล้วเรียกว่า team)
2. **Verify ว่าทีมเกิดจริงทันทีหลัง spawn ตัวแรก**: เช็คหลักฐาน team-config จริงของ framework ที่ใช้อยู่ — สำหรับ Claude Code คือ `~/.claude/teams/session-*/config.json` ถูกสร้างและมีชื่อ teammate ใน members — **ไม่มี = ที่ได้คือ subagent** → หยุด แจ้ง user ตรงๆ ว่า "ทีมไม่เกิด ได้ subagent แทน จะเอายังไงต่อ" ห้ามทำต่อเนียนๆ และห้ามประกาศว่า "เปิด TEAM แล้ว" ก่อนผ่าน verify นี้เด็ดขาด — บางสภาพแวดล้อม (เช่น desktop app บางตัว) สร้างทีมแท้ไม่ได้ ให้ใช้ pattern สำรอง "team-lite": spawn subagent พร้อม name + สั่งใน prompt ให้ SendMessage หากันโดยตรง → agent คุย/หักล้างกันเองได้จริงไม่ผ่าน lead — ถ้าใช้ pattern นี้ให้ประกาศตามจริงว่า **[TEAM-lite]** ไม่ใช่ [TEAM] เต็มรูปแบบ · ข้อบังคับ TEAM-lite: ทุก teammate ต้องถูกสั่ง "ถ้าส่งข้อความไม่ได้ให้รายงาน error จริง ห้ามแต่งเรื่องว่าคุยแล้ว" + final report ต้องแนบบันทึกข้อความครบทุกฉบับเพื่อ cross-check สองฝั่ง
3. **แตกงานลง shared task list** พร้อม dependency ให้ teammates เห็นร่วมกัน/claim เองได้ — ไม่ใช่สั่งงานผ่าน prompt อย่างเดียวแบบ subagent
4. **spawn prompt ทุกตัวต้องสั่ง collaboration ชัดๆ**: บอกชื่อเพื่อนร่วมทีม + หน้าที่ต้อง SendMessage หากันโดยตรงเพื่อแชร์ข้อค้นพบ/หักล้างกัน อย่างน้อย 1 รอบก่อนสรุป — ไม่สั่ง teammates จะไม่คุยกันเองเลย (พฤติกรรม default คือก้มหน้าทำแล้วรายงาน lead = เหมือน subagent ทุกประการ)
5. **ระหว่างรัน lead ห้ามลงมือทำงานของ teammates เอง** — รอให้เสร็จ + relay การโต้แย้งสำคัญระหว่าง teammates ให้ user เห็นเป็นระยะ
6. **จบงาน**: สรุป consensus + หลักฐานที่แต่ละฝ่ายใช้หักล้างกัน · สั่ง shutdown teammates ที่หมดหน้าที่ทันที (ไม่เผา token ต่อ) · จด memory ตาม convention ปกติ

- **Blacklist ห้าม TEAM เด็ดขาด**: flow การ์ดปกติ (หยิบ/ทำ/ปิด/จด memory) · pipeline ที่มี approval gate ต้องผ่าน user ทีละ stage (ห้ามให้ lead อนุมัติกันเอง) · งานแตะ memory/config ระบบ · งานที่ agent ตัวเดียวเอาอยู่
- **เคสตัวอย่างที่เข้าเกณฑ์**: บั๊ก/perf ที่วัดได้ = SUB เสมอ (มีเครื่องมือชี้ตัวการได้ตรงๆ) · escalate เป็น TEAM ได้เมื่อ**ไล่แล้ว 2 รอบยังไม่เจอ root cause และมีหลายทฤษฎีแข่งกัน** → เสนอ user เปิดทีมแข่งสมมติฐานให้หักล้างกันเอง · review ใหญ่หลายมุมอิสระ (security/perf/test ก่อน release) = เข้าเกณฑ์ TEAM
- **ตอนใช้ TEAM**: spawn teammate จาก agent definition จริงของคุณ เพื่อให้ tools+model ตรงตาม pin · **กฎเหล็ก "แตะโค้ดผ่าน lead" ตีความตาม role** — teammate ที่เป็น lead-by-stack แก้โค้ดได้เองตาม definition ไม่ต้อง spawn ซ้อน (nested team ทำไม่ได้) · **ไฟล์ memory ยังเป็นของ orchestrator (team lead) คนเดียว** teammate ห้ามแตะ
- **ข้อจำกัดที่ต้องรู้ (experimental ในหลาย framework)**: การ resume session อาจทำให้ teammates หายต้อง spawn ใหม่ · task status อาจค้าง — เช็คของจริงก่อนเชื่อ task list · lead ห้ามรีบสรุปจบ/ลงมือทำเองก่อน teammates เสร็จ

---

## Loop engineering — งานไหนวนเองได้ งานไหนต้องคนกด

Default ของระบบ = **turn-based** (user พิมพ์ → ทำ → รายงาน → รอสั่งต่อ) ใช้ได้กับทุกงานและเป็นค่าเริ่มต้นเสมอ

### เงื่อนไข 3 ข้อ — ขาดข้อไหนข้อหนึ่ง = อยู่ turn-based ตามเดิม ห้ามยก

1. **Stop condition ต้องวัดได้ด้วยเครื่อง** — มีคำสั่ง/สคริปต์ที่ตอบ ผ่าน/ไม่ผ่าน ด้วย exit code หรือตัวเลข · **ห้ามใช้ "orchestrator คิดว่าเสร็จ" หรือ "ดูแล้วน่าจะโอเค" เป็น stop condition เด็ดขาด** — ถ้าเขียน check ไม่ได้ แปลว่ายังไม่รู้ว่า "เสร็จ" คืออะไร ให้กลับไปนิยามก่อน
2. **จบได้ด้วยตัวเอง ไม่รอคนอื่น** — งานที่ต้องรอ asset จากทีมอื่น / รอการ์ดใบอื่น landed / รอ design ตัดสินใจ / รอ balance number = **human-gated ห้ามทำเป็น loop**
3. **ต้องมีเพดาน** — กำหนดรอบสูงสุด/turn cap + เงื่อนไขยอมแพ้ทุกครั้ง · ไม่มีเพดาน = ห้ามรัน · ทำ 2 รอบไม่ผ่านแล้วยังไม่ขยับ = หยุด รายงาน user ห้ามวนต่อเผา token

### ลำดับที่ต้องถามก่อนสร้าง loop ใหม่ (ห้ามข้ามขั้น)

**สคริปต์ล้วนทำได้มั้ย → ถ้าได้ ใช้สคริปต์ ห้ามใช้ agent** · งาน deterministic (ย้ายไฟล์ นับบรรทัด เทียบ index เช็ค pattern) ให้เขียนเป็นสคริปต์แล้วเรียก ไม่ต้องให้โมเดลนั่งคิดใหม่ทุกรอบ — agent ใช้เฉพาะขั้นที่ต้องตัดสินใจจริง

### Blacklist ห้ามทำเป็น loop เด็ดขาด

- **งานที่จบไม่ได้เพราะรอของคนอื่น** (ดูเงื่อนไขข้อ 2) — เอา loop ไปครอบมีแต่พัง
- **pipeline ที่มี approval gate** — ต้องผ่านสายตา user ทีละ stage ห้ามให้อะไรอนุมัติแทน
- **loop ที่แก้ไฟล์ memory เอง** — audit ได้แค่ตรวจ+รายงาน orchestrator เป็นคนแก้ตามรายงานเสมอ
- **build/deploy อัตโนมัติต่อท้ายงานเสร็จ** — ต้องคนตัดสินใจ

### Resource bounds

- **เปิด loop ที่รันตามเวลา (scheduled/cron) ต้องให้ user confirm ก่อนทุกครั้ง** — มันเผา token ตอนที่ไม่มีใครดู เหมือนกฎ TEAM ที่ต้องขออนุญาต · orchestrator ห้ามเปิดเอง
- tier model ต่อ agent ตั้งไว้สำหรับงาน on-demand ที่มีคนเฝ้า — **ห้ามยกทั้งทีมเข้า scheduled loop โดยไม่คิดเรื่องราคา** งานรูทีนในลูปให้ใช้สคริปต์ก่อน แล้วเรียก agent เฉพาะขั้นที่ต้องตัดสินใจ · เปลี่ยน tier ของ agent ต้องบอก user ก่อนเสมอ ห้ามปรับเงียบๆ
- ความถี่ให้ต่ำสุดที่ยังทัน — อย่า poll ถี่กว่าที่ของจริงเปลี่ยน

---

## Memory convention (บังคับทุก project ทุก session — เคร่งครัด)

Memory จริงของแต่ละโปรเจกต์อยู่ที่ `<project-root>/.agent-memory/` และ version ไปกับ Git repository + branch ของโปรเจกต์นั้นเท่านั้น ห้ามอ่าน/เขียน/fallback ไป Memory กลางหรือ path ที่ encode ไว้นอกโปรเจกต์ · orchestrator เป็นคนเดียวที่แก้ Memory; subagent อ่านได้อย่างเดียวและต้องรายงาน fact ใหม่กลับ orchestrator

### อะไรเป็นอะไร (แผนผังสรุป)

```
work/PROJ-XXX.md        = detail งานเปิด (กำลังทำ + plan รอหยิบ)   ┐ ไฟล์ต่อใบ/ต่อเรื่อง
archive/PROJ-XXX.md     = detail งานจบสนิท (การ์ดล้วน)              │ (สร้างได้เฉพาะ
analysis/ref-<slug>.md  = ความรู้/audit หลังการวิเคราะห์ ไม่ผูกการ์ด  ┘  3 folder นี้)

project_open_work.md    = master index งานเปิดทุกชนิด (1:1 กับ work/ — งานเปิดอยู่ที่นี่ที่เดียว)
project_archive.md      = master index งานจบทุกชนิด (โซน: BUGS / IMPROVE-OPTIMIZE / REFACTOR / FEATURE / ANALYSIS — header เป็นคำเปล่าเป๊ะๆ ไม่พ่วงคำอธิบาย, ครบทุกโซนเสมอ, โซนว่าง = "(None)", flat list ใหม่→เก่า ไม่แยกปี/เดือน)
```

- รหัสการ์ด: ตั้งชื่อ prefix ต่อโปรเจกต์ไม่ให้ชนกัน (เช่น `<ชื่อย่อโปรเจกต์>-XXX`) — ถ้าโปรเจกต์นั้นมี task tracker ที่ออกเลขให้เอง (เช่น Jira, Linear, GitHub Issues หรือระบบอื่นที่คุณใช้) ให้ tracker เป็นคนออกเลข ห้ามตั้งเอง
- index ทุกไฟล์ = 1 ใบ 1-2 บรรทัด + ลิงก์ detail — ห้ามมีเนื้อยาว
- ปิดงาน 1 ใบ = ย้ายไฟล์ work/→archive/ + ลบบรรทัด open_work + เพิ่มบรรทัดในโซนของมันใน archive + อัปเดต index หลัก + commit Memory แยกจาก work โดย default
- ทุกใบที่เปิดอยู่ต้องบอกว่า "พร้อมทำ" หรือ "รออะไรอยู่": บรรทัด `**Ready status:** Ready` หรือ `**Ready status:** BLOCKED - waiting for <สิ่งที่รอ> (<อ้างอิงที่เช็คได้>)` — ของที่รอต้องเขียนให้เช็คได้ว่ามาถึงหรือยัง ห้ามเขียนลอยๆ ว่า "รอของ"
- ห้ามสร้างไฟล์ต่อ task/การ์ดนอกเหนือ work/ + archive/ + analysis/

### โครงไฟล์ต่อ project

- **MEMORY.md** — index อย่างเดียว คุมให้สั้น (~10 บรรทัด) อัปเดต hook ในบรรทัดเดิมแทนการเพิ่มบรรทัดใหม่
- **user_and_feedback.md** — กฎ/feedback ที่ user สั่ง
- ไฟล์หมวดถาวรตามโปรเจกต์ (workflow, CI/CD, gotchas ฯลฯ) — สร้างใหม่เฉพาะหัวข้อที่ไม่เข้าหมวดไหนเลยจริงๆ
- **project_open_work.md** — master index งานเปิดทุกชนิด 1:1 กับ work/
- **project_archive.md** — master index งานจบสนิททุกชนิด แยกโซนตามชนิดงาน
- **work/PROJ-XXX.md** — detail งานที่ยังเปิด: จดสด root cause / สิ่งที่ตัดออก / plan ระหว่างทำ
- **archive/PROJ-XXX.md** — detail งานที่จบสนิท: root เต็ม, fix เต็ม, REFUTED list เต็ม, บทเรียน
- **analysis/ref-<slug>.md** — ความรู้/audit ที่ไม่ผูกการ์ด

### กฎอ่าน archive (อย่าอ่าน detail พร่ำเพรื่อ)

- เคสส่วนใหญ่ (หยิบการ์ดใหม่ / เช็คว่าเคยทำมั้ย / ตอบคำถามทั่วไป) → สแกน index project_archive.md จบ ไม่เปิด detail
- เปิด archive/PROJ-XXX.md เฉพาะ: (1) regression ใบเดิม — ต้องใช้ REFUTED เต็ม (2) กำลังจะแก้โค้ดแถวเดียวกับที่ fix เก่าแตะ (3) index มี Watch item ตรงกับอาการใหม่ (4) user ถามเจาะจงใบนั้น
- เงื่อนไข: บรรทัด index ต้องตอบ "เคยเจอมั้ย root คืออะไร" ได้ในตัว — ห้ามเป็นรหัสเปล่า ห้ามยาวจนกลับไปเป็น paragraph

### Flow บังคับต่อ 1 task

0. Audit/Analysis → ออกแค่ `analysis/ref-*.md` + index โซน ANALYSIS · การ์ดที่เสนอ (หลัง user confirm) นอนเป็นการ์ด backlog ใน tracker ของโปรเจกต์นั้น — ยังไม่สร้าง `work/`
1. หยิบ task → เช็ค project_archive.md ก่อนว่าเคยแก้/เคย REFUTED มาก่อนมั้ย → ย้ายการ์ดใน tracker ไป "In Progress" → สร้าง `work/PROJ-XXX.md` + บรรทัด open_work พร้อมบรรทัด `**Ready status:**`
2. ระหว่างทำ → จด root cause / สิ่งที่ตัดออกแล้ว ลง work/ + บรรทัด index ใน project_open_work.md ที่เดียว
3. จบสนิท (merged + เทสผ่าน ไม่มี follow-up) → ย้ายไฟล์ work/→archive/ → ลบบรรทัดออกจาก open_work + เพิ่มบรรทัดในโซนตามชนิดงานของ project_archive.md → อัปเดต MEMORY.md
4. ยังมี follow-up ค้าง → คงอยู่ work/ + open_work ต่อ จนปิดจริงค่อยย้าย

### Commit convention

Use these rules identically in every project:

- Work files and Memory must be separate commits by default.
- Confirmed defect, regression, security issue, or broken behavior work commit: `[Bug] <message>`.
- All other project work—new capability, improvement, refactor, tooling, documentation, and tests unless tied to a confirmed defect—uses `[Feature] <message>`.
- A commit containing only `.agent-memory/**` uses `[Memory] <message>`.
- Never mix unrelated Bug and Feature work; split them into separate commits.
- Never label a mixed work-and-Memory commit `[Memory]`; split the commit instead.
- Commit Memory to the current project repository and branch.
- Push follows the current project's normal authorization and policy. Never auto-push merely because Memory changed.

### รูปแบบการเขียน (ทุกไฟล์ memory)

- ห้ามเขียนเป็น paragraph ก้อนยาว — ใช้ heading + bullet ละประโยค/ละ fact, ตารางสำหรับข้อมูล enumerable
- ทุก section ต้องดูออกว่าเป็นของ task ไหน: section งานการ์ด → heading ขึ้นต้นด้วยเลขการ์ดเสมอ · section ความรู้ที่ไม่ผูกการ์ด → บรรทัดแรกใต้ heading เป็น blockquote บอกที่มา
- ไฟล์ความรู้ถาวร (gotchas/workflow ฯลฯ) เก็บเฉพาะกฎ+วิธีเลี่ยงสั้นๆ — หลักฐาน/การไล่สืบเชิงลึกแยกเป็น analysis/ref-*.md แล้วลิงก์จากกฎ
- ไฟล์ gotchas = กับดักแท้เท่านั้น 1 กับดัก = 1 หัวข้อ: กฎ/ห้าม → ทำแทน → สัญญาณว่ากำลังเจอมัน — เอกสาร feature/เครื่องมือทั่วไปไม่ใช่กับดัก ห้ามปน

### เพดาน

- MEMORY.md เกิน ~10 บรรทัด → จัดระเบียบทันที
- ไฟล์ index ทุกตัว (open_work/archive) ต้องเป็น index ล้วน — เจอ section เนื้อยาวโผล่ = ย้ายลง work/archive/ ทันที
- project_archive.md ยาวเกิน ~200 บรรทัด → ตัดบรรทัดเก่าสุดเป็นไฟล์ index ปี — detail ใน archive/ ไม่ต้องย้าย

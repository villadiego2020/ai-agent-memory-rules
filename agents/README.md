# Claude Code Agent Profiles

ทีมผู้เชี่ยวชาญสำหรับ Claude Code ที่ติดตั้งจากรีโปกฎกลางนี้และใช้ร่วมกันทุกโปรเจกต์ในเครื่อง ส่วน Memory จริงอยู่ใน `.agent-memory/` ของแต่ละโปรเจกต์

> README นี้เป็น**เอกสารให้คนอ่าน** — Claude Code ไม่โหลดไฟล์นี้เข้า context
> **กฎที่บังคับใช้จริง** (routing, กฎเหล็ก "แตะโค้ด = ต้องผ่าน lead", เกณฑ์เลือกโหมด) อยู่ใน [`../RULES.md`](../RULES.md) ที่เดียว — แก้กฎต้องแก้ที่นั่น

## ตำแหน่งติดตั้ง

Clone รีโปนี้ไว้ที่ตำแหน่งที่คุณดูแล แล้วใช้ installer เพื่อ copy หรือ link เฉพาะไฟล์ agent ไปยัง user configuration ของ Claude Code โดยไม่แทนที่ทั้งโฟลเดอร์ agents:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Platform Claude -Mode Copy
```

Installer นี้ไม่สร้างหรือ migrate Memory ให้โปรเจกต์ ใช้ `scripts/initialize-memory.ps1 -ProjectPath <project>` แยกต่างหาก แล้ว commit `.agent-memory/` ไปกับ Git repository และ branch ของโปรเจกต์นั้น

## ทีมมีใครบ้าง

**Lead — คนลงมือแก้โค้ดจริง** (เลือกตาม tech stack ของโปรเจกต์)

| Agent | Callsign | ทำอะไร | Model | สิทธิ์แก้โค้ด |
|---|---|---|---|---|
| `unity-expert` | Forge | Lead โปรเจกต์ Unity — วิเคราะห์โค้ด, gameplay, performance, editor tools และ asset pipeline; ใช้ Clean Code, event-based/OOP, config และ design pattern เท่าที่จำเป็น | opus (xhigh) | แก้ได้เต็ม |
| `web-expert` | Nova | Lead โปรเจกต์เว็บ ทุกภาษา/framework — frontend, backend, API, database | opus (xhigh) | แก้ได้เต็ม |
| `system-tester` | Sentinel | ออกแบบ+รัน test เว็บ/เกมตามความเสี่ยง โดยอธิบายทุก test ว่าป้องกันอะไร ได้หลักฐานอะไร และผ่าน/ไม่ผ่านแปลว่าอะไร | opus (high) | เฉพาะไฟล์ test |

**ที่ปรึกษา — คิด/ออกแบบอย่างเดียว** ส่ง design ให้ lead ลงมือ ไม่แตะโค้ดเอง

| Agent | Callsign | ทำอะไร | Model |
|---|---|---|---|
| `system-planner` | Atlas | แตกงานใหญ่เป็นเฟส วิเคราะห์ stack กำหนดว่า expert ตัวไหนรับส่วนไหน | fable (xhigh) |
| `backend-architect` | Bedrock | โครงฝั่ง server + data layer ตั้งแต่เส้น API ขึ้นไป — service architecture, API contract, schema/index/query, migration, cache, queue, auth | opus (xhigh) |
| `network-expert` | Pulse | network foundation, transport/protocol, authority, sync, prediction/reconciliation, latency, bandwidth/memory/allocation และข้อแลกเปลี่ยน Photon Fusion/FishNet/Mirror | opus (xhigh) |
| `game-architect` | Blueprint | โครงสร้างระบบเกม — ownership/data flow, save/scene/state, pattern และ config ที่ใช้ร่วมกันง่ายโดยไม่แตก abstraction เกินจำเป็น | opus (xhigh) |
| `uxui-expert` | Prism | UX/UI เว็บและเกม — ตรวจความตรงสเปก, visual hierarchy, layout, สี, ฟอนต์, motion, state, accessibility และ HUD/menu ที่สวยและใช้งานได้จริง | opus (high) |
| `project-manager` | Compass | ตรวจ+รายงานอย่างเดียว — audit memory/index, drift Jira↔memory, status digest ข้ามโปรเจกต์, เสนอลำดับหยิบการ์ด | sonnet (high) |

**ทีม 3D** — ทำงานใน Blender ผ่าน Blender MCP ตามลำดับ organic เริ่ม Clay / hard-surface เริ่ม Chisel

| Agent | Callsign | ทำอะไร | Model |
|---|---|---|---|
| `3d-sculptor` | Clay | ปั้น organic/ตัวละคร high-poly, silhouette, anatomy, รายละเอียดผิว | opus (high) |
| `3d-modeller` | Chisel | hard surface, retopo, topology, UV, LOD, optimize + export mesh | opus (high) |
| `3d-rigger` | Marionette | bone, IK/FK, weight painting, skinning, shape keys, facial rig | opus (high) |
| `3d-animator` | Motion | keyframe, walk/idle/attack cycle, action/NLA, bake + export animation | opus (high) |

**การเลือก model** (ปรับ 2026-07-30 ตามความสามารถของ Claude 5 family):

- **`fable` (xhigh) — Atlas ตัวเดียว** จุดที่วางแผนผิดแล้วพังทั้งงาน และถูกเรียกครั้งเดียวต่องานใหญ่ ต้นทุนรวมเลยต่ำ
- **`opus` (xhigh) — lead ที่แก้โค้ดจริง (Forge, Nova) + ที่ปรึกษาสถาปัตย์ (Bedrock, Blueprint, Pulse)** Opus 5 เก่งสุดตรงงาน agentic coding หลายไฟล์ และ `xhigh` คือ effort ที่แนะนำสำหรับงาน coding/agentic โดยเฉพาะ · ที่ปรึกษาสถาปัตย์ลงมาจาก fable เพราะงานคือออกแบบรอบเดียวส่งต่อ ไม่ใช่ long-horizon ที่ Fable ได้เปรียบจริง
- **`opus` (high) — Prism, Sentinel + ทีม 3D ทั้ง 4** งานตัดสิน taste / หา bug / คุม Blender ผ่าน MCP ที่มี approval gate อยู่แล้ว — `high` คุ้มกว่าไม่ต้องดัน xhigh
- **`sonnet` (high) — Compass** งานตรวจตามเกณฑ์ที่เขียนไว้ชัด + อ่านไฟล์ memory ข้ามโปรเจกต์เยอะ (input token หนัก) Sonnet 5 ถูกกว่าและพอ

alias `fable`/`opus`/`sonnet` ชี้รุ่นล่าสุดของแต่ละ tier เสมอ (ตอนนี้ = Fable 5 / Opus 5 / Sonnet 5) ออกรุ่นใหม่ไม่ต้องไล่แก้ไฟล์ · **เปลี่ยน tier ของใครต้องบอก user ก่อน ห้ามปรับเงียบๆ**

> ตาราง model ส่วนนี้ใช้กับ **Claude Code เท่านั้น**. ฝั่ง Codex ไม่ใช้ alias `fable`/`opus`/`sonnet`; โปรไฟล์ TOML ควรปล่อยให้ inherit model/effort ที่ user เลือกเป็นค่าเริ่มต้น และ override ด้วย model identifier ที่ Codex รองรับเฉพาะเมื่อมีเหตุผลด้านคุณภาพ เวลา และ token ชัดเจน

## กติกาหลัก: Lead-by-Stack

- **พระเอกคือ lead ที่ตรงกับ stack ของโปรเจกต์** — ที่ปรึกษาออกแบบแล้วส่งต่อ ไม่ลงมือเอง
- **orchestrator ห้ามแก้โค้ดโปรเจกต์เอง** ต้อง spawn lead เสมอ (แก้เองได้เฉพาะ `<project-root>/.agent-memory/**` + config ของทีม agent)
- ทุก agent ขึ้นต้นรายงานด้วยบรรทัด `💭 ชื่อ: กำลังคิดอะไร` และ orchestrator ต้อง relay บรรทัดนี้ให้ user เห็นเสมอ
- ตาราง routing เต็ม (บริบทงาน → ใครคิด ใครทำ) อยู่ใน [`../RULES.md`](../RULES.md)

## โหมดการเรียกใช้: Subagent vs Agent Team

|  | **Subagent** (default) | **Agent Team** |
|---|---|---|
| ทำงานยังไง | orchestrator spawn agent ไปทำงานย่อย → รับผลกลับมารวมเอง | teammates เป็น session เต็มตัว มี shared task list |
| agent คุยกันเอง | ไม่ได้ — สื่อสารผ่าน orchestrator เท่านั้น | ได้ เถียง/ต่อรองกันเองระหว่างทำ |
| user คุยกับ agent | ไม่ได้ | ได้ คุยรายตัวได้ |
| token | ปกติ | แพงกว่าหลายเท่า |
| ใช้เมื่อไหร่ | **ทุกงาน** | เฉพาะงานที่ผ่านเกณฑ์ + user confirm |

### Subagent — ใช้เป็นค่าเริ่มต้นเสมอ

เรียกกี่ตัวตามความเสี่ยงจริง โดยยังคงกฎว่าการแก้ไฟล์โปรเจกต์ต้องผ่าน lead ตาม stack:

- **ตอบ/อธิบาย/วิเคราะห์แบบ read-only** → orchestrator ทำตรงได้ ไม่ต้อง spawn เพื่อสรุปซ้ำ
- **แก้จุดเดียวและความเสี่ยงต่ำ** → lead ตัวเดียว + focused self-verification ตาม acceptance criteria
- **behavior/regression/network/save/security/critical UI มีความเสี่ยง หรือ user ขอ test** → lead → Sentinel; Sentinel ต้องบอกวัตถุประสงค์ ความเสี่ยง และหลักฐานของแต่ละ test
- **ฟีเจอร์ข้ามหลายระบบ/รื้อระบบ** → Atlas วางแผน → lead + ที่ปรึกษาเฉพาะด้านที่งานแตะจริง → Sentinel เฉพาะเมื่อเข้าเกณฑ์ความเสี่ยง
- **งาน 3D** → เรียกทีละ stage ตามลำดับ pipeline โดยมี approval gate จาก user คั่นทุก stage

Advisor ที่อ่านอย่างเดียวและไม่พึ่งผลกันสามารถรันขนานได้ ส่วนงานเขียน งานมี dependency หรือแตะไฟล์เดียวกันให้รันตามลำดับ

ตอน spawn ทุกครั้ง: `description` ขึ้นต้นด้วย callsign (`Forge: fix creep pathing`) และระบุไฟล์/โมดูลในขอบเขต หน้าที่ ผลลัพธ์ที่ต้องส่ง acceptance criteria คำสั่งตรวจขั้นต่ำ รวมทั้ง "บริบทโปรเจกต์" และ rejected hypothesis ที่คัดจาก `<project-root>/.agent-memory/` เฉพาะส่วนที่เกี่ยวข้อง เพื่อไม่ให้แต่ละ agent สแกนรีโปซ้ำ · subagent อ่าน Memory ได้อย่างเดียวและรายงาน fact ใหม่กลับ orchestrator

### Agent Team — ต้องผ่านด่าน ห้ามเปิดเอง

เปิดใช้ได้แล้วผ่าน `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` ใน `settings.json` แต่ต้องผ่าน 3 ด่านก่อนทุกครั้ง:

1. **งานต้องการให้ agent เถียง/ต่อรองกันเอง*ระหว่างทำ*มั้ย?** — ถ้าแค่ต่างคนต่างทำแล้ว orchestrator รวมผลได้ = SUB จบ (งานที่เครื่องมือวัดได้ เช่น profiler ชี้ตัวการได้ = SUB เสมอ)
2. **แบ่งก้อนอิสระที่ไฟล์ไม่ชนกันได้มั้ย?** — sequential (คิด→ทำ→ตรวจ) หรือแตะไฟล์ชุดเดียวกัน = SUB จบ
3. **ผ่าน 1+2 → เสนอ user ก่อนเสมอ** — บอกเหตุผลที่เข้าเกณฑ์ + จำนวนตัว + เตือนว่า token แพงกว่าหลายเท่า แล้วรอ confirm

**Blacklist ห้าม TEAM เด็ดขาด:** flow การ์ดปกติ (หยิบ/ทำ/ปิด/จด memory) · 3D pipeline (approval gate ต้องผ่าน user ทีละ stage) · งานแตะ memory/config ระบบ · งานที่ agent ตัวเดียวเอาอยู่

**เคสที่เข้าเกณฑ์:** debug ที่ไล่แล้ว 2 รอบยังไม่เจอ root cause และมีหลายทฤษฎีแข่งกัน → เปิดทีมแข่งสมมติฐานหักล้างกันเอง · review ใหญ่หลายมุมอิสระ (security/perf/test) ก่อน release

**ตอนใช้จริง:** spawn teammate จาก agent definition ในโฟลเดอร์นี้เพื่อให้ tools + model ตรงตาม pin · teammate ที่เป็น lead-by-stack แก้โค้ดได้เองตาม definition (nested team ทำไม่ได้) · ไฟล์ memory ยังเป็นของ orchestrator คนเดียว teammate ห้ามแตะ

**Protocol กันทีมปลอม (ฉบับเต็มใน RULES.md):** spawn แล้วต้อง verify ว่า `~/.claude/teams/session-*/config.json` เกิดจริง — ไม่เกิด = ได้ subagent ต้องแจ้ง user ทันที ห้ามทำต่อเนียนๆ · spawn prompt ต้องสั่งให้ teammates ส่งข้อความหักล้างกันเองอย่างน้อย 1 รอบ (ไม่สั่ง = มันไม่คุยกันเอง) · แตกงานลง shared task list ให้ claim เอง · lead ห้ามทำงานแทน + ต้อง relay การโต้แย้งให้ user เห็น

**ข้อจำกัด (ยัง experimental):** `/resume` แล้ว teammates หาย ต้อง spawn ใหม่ · task status อาจค้าง เช็คของจริงก่อนเชื่อ · Windows ใช้ split pane ไม่ได้ ต้องเป็น in-process mode · แชทกับ teammate รายตัวได้เฉพาะ terminal CLI — desktop app เห็นได้ผ่าน lead relay เท่านั้น

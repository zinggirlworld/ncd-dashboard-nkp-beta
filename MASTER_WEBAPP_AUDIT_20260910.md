# /master-webapp-full Audit — 2026-09-10

## 1. Current state

WebApp เป็น SvelteKit static dashboard และโหลดข้อมูลจาก `static/foot_risk_summary.csv` โดย browser ไม่ได้ query SQL Server โดยตรง SQL ใช้สำหรับสร้างชุดข้อมูลสรุปแล้ว export เป็น CSV ให้ WebApp แสดงผล

Scope active ปัจจุบันเหลือเฉพาะ **Diabetic Foot Risk Dashboard** แสดงระดับ `Z0280-Z0283` แบบปีงบประมาณและไตรมาส

## 2. Evidence / Data reconciliation

ผล reconciliation ที่รันกับ SSBDATABASE จริงสำหรับชุดตรวจ FY2569:

| metric                                     | total HN |
| ------------------------------------------ | -------: |
| clinic 0105 all HN                         |    1,153 |
| clinic 0105 + same-visit E10-E14           |    1,068 |
| foot risk clinic 1201 all HN               |    1,178 |
| foot risk ∩ clinic0105 all                 |      652 |
| foot risk ∩ verified legacy DM cohort      |      652 |
| foot risk NOT in verified legacy DM cohort |      526 |

Root cause ของจำนวนเดิมที่สูงเกิน population ที่ต้องการคือ foot-risk query แบบ unrestricted นับเพิ่ม **526 HN** ที่ไม่อยู่ใน DM cohort ที่ใช้สำหรับ dashboard นี้

ผล export ปีงบประมาณ 2569:

| risk                |      HN |
| ------------------- | ------: |
| Z0280 เสี่ยงต่ำ     |     549 |
| Z0281 เสี่ยงปานกลาง |      89 |
| Z0282 เสี่ยงสูง     |      11 |
| Z0283 เสี่ยงสูงมาก  |       3 |
| **รวม**             | **652** |

ดังนั้น annual export FY2569 reconcile กับ population baseline `652 HN` ได้พอดี

## 3. Schema verification

จาก SSB schema/metadata ที่ใช้ตรวจสอบ:

- `dbo.VNMST`: `VISITDATE`, `VN`, `HN`
- `dbo.VNPRES`: `VISITDATE`, `VN`, `CLINIC`, `CLOSEVISITTYPE`
- `dbo.VNDIAG`: `VISITDATE`, `VN`, `ICDCODE`
- relation ที่ใช้ใน query: `VNMST ↔ VNPRES ↔ VNDIAG` ด้วย `VISITDATE + VN`
- clinic `0105` เป็นคลินิกเบาหวานตาม codebook ที่ตรวจไว้

## 4. Query / Business logic ที่ใช้

Population fence ปัจจุบัน:

1. DM cohort: clinic `0105`
2. ตัด `CLOSEVISITTYPE = '999'`
3. มี diagnosis `E10-E14` ใน visit เดียวกัน
4. Foot-risk event: clinic `1201` + `Z0280-Z0283`
5. HN ต้องอยู่ใน DM cohort ของ period เดียวกัน
6. HN เดียวมีหลาย risk code ใน period เดียวกัน: เลือกระดับสูงสุดด้วย `MAX(risk_order)`
7. final dataset มี 4 risk rows ต่อ period เสมอ รวม zero count

Query ใช้ `READ COMMITTED` และไม่มี `SELECT *`, `NOLOCK`, `READ UNCOMMITTED`

## 5. Critical findings

### C1 — Population mismatch — RESOLVED IN ACTIVE QUERY

Query unrestricted เดิมนับ foot-risk 1,178 HN แต่ population ที่อยู่ใน DM cohort มี 652 HN ต่างกัน 526 HN Active query ถูกแก้ให้มี DM population fence แล้ว และ export FY2569 รวมได้ 652 HN

### C2 — Unverified dashboard scope — REMOVED FROM ACTIVE UI

ส่วนที่ requirement ยังไม่สมบูรณ์ถูกถอดออกจาก UI/data contract/active query แล้ว หน้า active เหลือเฉพาะ Foot Risk ที่กำลังตรวจสอบ population และ mapping ได้

## 6. High findings / Remaining risks

### H1 — Clinic 1201 mapping ยังต้อง owner confirmation

SSB codebook ที่ตรวจไว้ระบุ clinic `1201` เป็นกายภาพบำบัดในเวลา ขณะที่ระบบเดิมใช้ `1201 + Z0280-Z0283` เป็น foot-risk event ดังนั้น mapping นี้เป็น legacy business rule และยังต้องให้เจ้าของ requirement ยืนยันก่อนประกาศเป็นนิยามองค์กร

### H2 — Annual และ quarterly figures เป็น period-fenced populations แยกกัน

Annual และ quarterly query สร้าง DM cohort ภายใน period ของตัวเอง จึงไม่ควรนำผลรวม 4 ไตรมาสมาแทน annual unique HN โดยตรง UI เพิ่มคำอธิบายเพื่อป้องกันการตีความผิดแล้ว

### H3 — Sample HN tracing ยังต้องทำใน live DB

Aggregate reconciliation ผ่านสำหรับ FY2569 แต่ยังควร trace HN จริงอย่างน้อย 5-10 ราย ครอบคลุมแต่ละ risk และ case ที่มีหลาย risk code เพื่อยืนยัน business meaning จาก source record

## 7. Changes made

- Active WebApp เหลือเฉพาะ Diabetic Foot Risk Dashboard
- ถอดข้อความ/องค์ประกอบ user-facing ที่อ้าง scope ที่ยังไม่สมบูรณ์ออกจากหน้า dashboard
- แก้ SQL ให้ foot-risk HN ต้อง intersect กับ verified DM cohort
- Dedup 1 HN ต่อ period และเลือก risk สูงสุด
- นำ CSV ที่รันจาก live query มาใส่ `static/foot_risk_summary.csv`
- FY2569 active total = 652 HN
- ปรับคำ UI จากการตีความเชิง action เป็นคำอธิบายข้อมูล `รวมกลุ่มเสี่ยงสูงและสูงมาก`
- เพิ่มคำอธิบายว่า annual และ quarter เป็น population-fenced period แยกกัน
- เพิ่ม fail-closed CSV validation ใน `src/lib/footRiskData.ts`:
  - required columns
  - integer validation
  - valid period type/order
  - risk code/order/name mapping
  - non-negative total
  - duplicate logical-key detection
  - ต้องครบ 4 risk levels ต่อ period
- เก็บข้อมูล legacy ไว้ใน `audit/` เพื่อ trace ย้อนหลัง ไม่ถูก serve เป็น active data

## 8. Verification actually performed

- CSV structure: **PASS** — 80 rows, columns ตรง data contract
- CSV duplicate logical keys: **PASS** — 0 duplicate
- CSV negative `total_hn`: **PASS** — 0
- CSV integer counts: **PASS**
- Risk code/order/name mapping: **PASS**
- ทุก period มี 4 risk levels: **PASS**
- FY2569 annual breakdown: **549 + 89 + 11 + 3 = 652 — PASS**
- Reconciliation FY2569 population baseline: **652 — PASS**
- Prettier for active Svelte/TypeScript: **PASS**
- Direct Svelte compiler parse/compile: `+page.svelte`, `+layout.svelte`, `FootRiskChart.svelte` — **PASS**
- TypeScript compile of `footRiskData.ts` with temporary `$app/paths` declaration — **PASS**
- Active `src/` + `static/` scan: ไม่มี user-facing legacy KPI scope — **PASS**
- Active SQL scan: ไม่มี `SELECT *`, `NOLOCK`, `READ UNCOMMITTED` — **PASS**

## 9. Tests not completed in this sandbox

`eslint`, full `svelte-check`, และ `vite build` ยังไม่สามารถถือว่า PASS ได้ใน sandbox นี้ เพราะ dependencies ใน ZIP เดิมเป็นฝั่ง Windows และ environment Linux ขาด native optional binding `@rolldown/binding-linux-x64-gnu` การติดตั้งใหม่ต้องใช้ environment/network ที่มี package registry ใช้งานได้

ก่อน deploy ให้รันบนเครื่องจริง/CI:

```bash
npm ci
npm run lint
npm run check
npm run build
```

## 10. Production acceptance gate

ก่อนประกาศ production data เป็น Final:

1. ให้เจ้าของ requirement ยืนยัน mapping `clinic 1201 + Z0280-Z0283`
2. trace HN จริงอย่างน้อย 5-10 รายจาก SSBDATABASE
3. ทดสอบ edge case HN ที่มีหลาย risk code ว่าเลือก highest risk ถูกต้อง
4. รัน lint/check/build บน environment ที่ถูก platform
5. smoke test หน้า Dashboard ปีงบ 2566-2569 และ Q1-Q4

ไม่มีการอ้างว่า Production PASS จนกว่าจะครบ gate ข้างต้น

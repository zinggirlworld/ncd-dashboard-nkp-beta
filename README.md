# Diabetic Foot Risk Dashboard — โรงพยาบาลนครพิงค์

Dashboard สรุปผลการประเมินความเสี่ยงเท้าในผู้ป่วยเบาหวาน โดยแสดงจำนวน HN ไม่ซ้ำตามระดับความเสี่ยง `Z0280-Z0283` ในมุมมองปีงบประมาณและไตรมาส

## Data source และ Query contract

ข้อมูลสำหรับหน้า WebApp มาจาก `static/foot_risk_summary.csv` ซึ่ง export จาก:

```text
sql/foot_risk_summary_export_no_bom.sql
```

กติกาปัจจุบัน:

- DM cohort: clinic `0105`
- ตัด visit ที่ `CLOSEVISITTYPE = '999'`
- ต้องมี diagnosis `E10-E14` ใน visit เดียวกัน
- Foot-risk event: clinic `1201` + `Z0280-Z0283`
- ผู้ถูกนับต้องอยู่ใน DM cohort ของงวดเดียวกัน
- HN เดียวมีหลาย risk code ในงวดเดียวกัน: เลือกระดับความเสี่ยงสูงสุด
- ใช้ `READ COMMITTED`
- ไม่ใช้ `SELECT *`, `NOLOCK` หรือ `READ UNCOMMITTED`

> Mapping `clinic 1201 + Z0280-Z0283` เป็น business rule ที่สืบทอดจากระบบเดิม และยังควรให้เจ้าของ requirement ยืนยันเป็นนิยามทางการขององค์กร

## Reconciliation ที่ยืนยันจาก SSBDATABASE วันที่ 2026-09-10

สำหรับชุดตรวจ FY2569:

```text
Foot risk clinic 1201 ทั้งหมด              1,178 HN
Foot risk ที่อยู่ใน verified DM cohort        652 HN
Foot risk ที่ไม่อยู่ใน verified DM cohort      526 HN
```

ผล export ปีงบประมาณ 2569 ที่นำมาแสดงใน WebApp:

```text
Z0280 เสี่ยงต่ำ          549 HN
Z0281 เสี่ยงปานกลาง      89 HN
Z0282 เสี่ยงสูง           11 HN
Z0283 เสี่ยงสูงมาก         3 HN
รวม                      652 HN
```

ไฟล์ CSV active ผ่านการตรวจโครงสร้างว่าไม่มี duplicate key ระดับ `period + risk_code`, ไม่มีจำนวนติดลบ และทุกงวดมีครบ 4 ระดับความเสี่ยง

## หมายเหตุเรื่องปีงบประมาณและไตรมาส

Population fence ถูกคำนวณแยกตามงวด ดังนั้นจำนวน HN ของปีงบประมาณและผลรวมของ 4 ไตรมาสไม่จำเป็นต้องเท่ากัน และไม่ควรนำผลรวมรายไตรมาสมาแทนจำนวน HN ของทั้งปีงบประมาณ

## เริ่มต้นใช้งาน

```bash
npm ci
npm run lint
npm run check
npm run build
npm run dev
```

ก่อน deploy production ต้องรัน `lint`, `check`, `build` บน environment ที่ติดตั้ง dependencies ตรงกับ platform จริง และทำ sample-HN tracing ตาม business requirement ที่เจ้าของงานยืนยัน

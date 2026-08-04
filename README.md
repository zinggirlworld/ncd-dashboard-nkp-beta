# NCD Dashboard NKP

Dashboard ติดตามตัวชี้วัด NCD การคัดกรองภาวะแทรกซ้อนจากโรคเบาหวาน และความเสี่ยงเท้า สำหรับคลินิกเบาหวาน โรงพยาบาลนครพิงค์

## ขอบเขตข้อมูล

ระบบรองรับเฉพาะ 2 ระดับเวลา:

- ปีงบประมาณ
- ไตรมาส 1–4

ไม่มี UI, data filter, chart หรือ CSV contract ระดับเดือน

## เริ่มต้นใช้งาน

```bash
npm ci
npm run check
npm run build
npm run dev
```

> หลีกเลี่ยง `npm audit fix --force` เพราะอาจ downgrade SvelteKit แบบ breaking change

## ไฟล์ข้อมูล

วางไฟล์ไว้ใน `static/`:

```text
static/ncd_indicator_summary.csv
static/foot_risk_summary.csv
```

จำนวนข้อมูลที่คาดหวัง:

- `ncd_indicator_summary.csv` 360 แถว: ปีงบประมาณ 72 + ไตรมาส 288
- `foot_risk_summary.csv` 76 แถว: ปีงบประมาณ 16 + ไตรมาส 60

## SQL สำหรับ Navicat

```text
sql/ncd_indicator_export_year_only_2566_2569_no_bom.sql
sql/ncd_indicator_export_quarter_only_2566_2569_no_bom.sql
sql/foot_risk_summary_export_no_bom.sql
```

## GitHub Pages

Workflow จะกำหนด base path จากชื่อ repository อัตโนมัติผ่าน `BASE_PATH` จึงไม่ต้องแก้ชื่อ repository ใน source code ทุกครั้ง

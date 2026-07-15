# NCD Dashboard NKP

Dashboard ตัวชี้วัด NCD / Diabetes Screening สำหรับคลินิก 0105 โรงพยาบาลนครพิงค์

## วิธีใช้งานแบบ GitHub Pages / Static Site

วางไฟล์ข้อมูลไว้ที่:

```text
static/ncd_indicator_summary.csv
static/foot_risk_summary.csv
```

จากนั้นรันในเครื่อง:

```bash
npm install
npm run dev
```

Build สำหรับ publish:

```bash
npm run build
```

## โครงข้อมูลหลัก

`ncd_indicator_summary.csv` ต้องมี column:

```text
period_type,fiscal_year_be,period_order,period_label,indicator_no,indicator_name,target_text,target_type,target_value,numerator,denominator,actual_percent,status,gap_from_target
```

Dashboard รองรับ:

- ปีงบประมาณ
- ไตรมาส
- เดือน

ถ้า CSV มีแค่ปีงบประมาณ ระบบจะแสดงข้อความแจ้งเมื่อเลือกไตรมาสหรือเดือน

## หมายเหตุเรื่อง SSBDATABASE

GitHub Pages เป็น Static Site จึงต่อ SSBDATABASE โดยตรงไม่ได้อย่างปลอดภัย ถ้าต้องการ Auto Update ให้ดูเอกสาร:

```text
docs/SSBDATABASE_AUTO_UPDATE.md
```

## SQL

ไฟล์ SQL สำหรับ export อยู่ในโฟลเดอร์:

```text
sql/
```

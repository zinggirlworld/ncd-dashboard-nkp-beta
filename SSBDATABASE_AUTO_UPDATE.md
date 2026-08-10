# แนวทาง Auto Update จาก SSBDATABASE

เวอร์ชันที่อัปขึ้น GitHub Pages เป็น Static Site จึงไม่สามารถต่อ SQL Server / SSBDATABASE โดยตรงจาก Browser ได้ เพราะจะเสี่ยงเรื่องรหัสผ่าน ฐานข้อมูล และ port ภายในโรงพยาบาล

แนวทางที่ปลอดภัยกว่า:

1. ให้ SQL Server / Scheduled Script คำนวณตัวชี้วัดตามรอบเวลา เช่น ทุกวัน 06:00 น.
2. เก็บผลลงตารางกลาง เช่น `dbo.NCD_INDICATOR_SUMMARY`
3. ให้ Dashboard อ่านจาก CSV ที่ export อัตโนมัติ หรืออ่านผ่าน Backend API ที่อยู่ใน LAN
4. ห้ามใส่ username/password ของ SQL Server ไว้ใน Svelte ฝั่ง Browser

โครงตารางกลางที่แนะนำให้เหมือน CSV:

```sql
CREATE TABLE dbo.NCD_INDICATOR_SUMMARY (
    period_type NVARCHAR(20),
    fiscal_year_be INT,
    period_order INT,
    period_label NVARCHAR(50),
    indicator_no INT,
    indicator_name NVARCHAR(500),
    target_text NVARCHAR(50),
    target_type VARCHAR(5),
    target_value DECIMAL(10,2),
    numerator INT,
    denominator INT,
    actual_percent DECIMAL(10,2),
    status NVARCHAR(20),
    gap_from_target DECIMAL(10,2),
    updated_at DATETIME DEFAULT GETDATE()
);
```

สำหรับ GitHub Pages ให้ใช้ไฟล์ CSV ใน `static/` ก่อน:

- `static/ncd_indicator_summary.csv`
- `static/foot_risk_summary.csv`

ถ้าต้องการ Auto จริง แนะนำทำ Backend แยก เช่น SvelteKit Server ใน LAN, FastAPI, หรือ Node.js API แล้วให้หน้า Dashboard เรียก API แทน CSV

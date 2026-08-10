# TECH IMPECCABLE AUDIT — NCD Dashboard Final Clean

## Scope

SvelteKit dashboard สำหรับคลินิกเบาหวาน โรงพยาบาลนครพิงค์ โดย Final scope รองรับ **ปีงบประมาณ** และ **ไตรมาส 1–4** เท่านั้น ไม่มีระดับเดือนใน UI, loaders, CSV contract หรือ SQL export ที่ใช้งานปัจจุบัน

## รอบปรับปรุง Final

ตรวจและปรับตาม `/tech impeccable /audit /colorize /adapt /arrange /typeset` โดยยึด source และไฟล์ข้อมูลจริงเป็นหลัก

| Area               | สิ่งที่ปรับ Final                                                                                                                                                                                    |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Technical          | แยก ECharts lifecycle effect ออกจาก data-update effect ในทั้ง 3 chart เพื่อไม่ dispose/recreate instance ทุกครั้งที่ filter/data เปลี่ยน; cleanup resize listener และ dispose เมื่อ DOM chart ถูกถอด |
| Data semantics     | อัตราผ่านคำนวณจาก `ผ่าน / ตัวชี้วัดที่ประเมินได้` ไม่รวมรายการที่ประเมินไม่ได้; ค่าเฉลี่ยร้อยละใช้เฉพาะ row ที่มี `actual_percent` จริง                                                              |
| SQL contract       | ลบ SQL duplicate/legacy ที่ชื่อ year/quarter แต่ภายในยังมี period เดือน; เหลือ SQL No-BOM 3 ไฟล์ และทำ year-only / quarter-only ให้ period table มีเฉพาะ scope ของไฟล์นั้นจริง                       |
| Colorize           | ตัด `indigo` ที่หลงเหลือใน category badge ออกจาก semantic palette และใช้ Sky แทน                                                                                                                     |
| Arrange / Typeset  | KPI percent ใช้ scale เล็กกว่า count, แยก `%`, tabular numbers, card min-height และ responsive grid; เปลี่ยนหัวข้อ presentation สำคัญเป็นภาษาไทย                                                     |
| Accessibility      | `lang="th"`, focus-visible, reduced-motion, labels, 44px controls, chart aria labels, table caption/scopes และ keyed each blocks                                                                     |
| Repository hygiene | Final ZIP ตัด `.git`, `.freebuff`, `node_modules`, `.svelte-kit`, `build`, `docs` legacy และรายงาน audit ซ้ำเก่า; เพิ่ม `.freebuff/` ใน `.gitignore`                                                 |

## Data contract verification

- `static/ncd_indicator_summary.csv` = **360 rows**
  - ปีงบประมาณ 72
  - ไตรมาส 288
- `static/foot_risk_summary.csv` = **76 rows**
  - ปีงบประมาณ 16
  - ไตรมาส 60
- Foot risk codes: Z0280–Z0283
- ไม่พบ `period_type = เดือน` ใน CSV
- SQL ที่ส่งมอบ:
  - `sql/ncd_indicator_export_year_only_2566_2569_no_bom.sql`
  - `sql/ncd_indicator_export_quarter_only_2566_2569_no_bom.sql`
  - `sql/foot_risk_summary_export_no_bom.sql`
- ไม่พบข้อความ/period `เดือน` ใน SQL Final ทั้ง 3 ไฟล์

## Audit scorecard

| Area                       | Score | Evidence                                                                            |
| -------------------------- | ----: | ----------------------------------------------------------------------------------- |
| Requirement Alignment      |  10.0 | Final source/data/SQL เป็น year + quarter เท่านั้น                                  |
| Technical Architecture     |   9.7 | Typed loaders, static adapter, clean source structure                               |
| Svelte / ECharts Lifecycle |   9.8 | Instance lifecycle แยกจาก option update; cleanup ครบ                                |
| Data Contract              |   9.9 | Schema/period/count ตรงกับ requirement                                              |
| Code Quality               |   9.7 | Dead/duplicate artifacts ถูกลบ, keyed each blocks                                   |
| UX Flow                    |   9.7 | ซ่อนงวดเมื่อเลือกปี; quarter 1–4 ชัดเจน                                             |
| Visual Hierarchy           |   9.7 | KPI → executive summary → charts → detail                                           |
| Color Consistency          |   9.7 | Emerald/Rose/Amber/Sky/Violet/Slate semantic palette                                |
| Data Readability           |   9.8 | KPI numeric hierarchy, tabular numerals, sticky detail table                        |
| Executive Presentation     |   9.8 | ลด technical language บนหน้าจอและใช้หัวข้อไทย                                       |
| Accessibility              |   9.7 | Thai lang, focus, reduced motion, labels/caption/scopes                             |
| Responsive Design          |   9.7 | 1/2/3/6 KPI grid, local table overflow, responsive chart height                     |
| Healthcare Appropriateness |   9.8 | NCD + screening + foot-risk hierarchy ตรงบริบทคลินิก                                |
| Maintainability            |   9.8 | Canonical SQL 3 ไฟล์, ไม่มี duplicate docs/source tree                              |
| Deployment Readiness       |   9.5 | GitHub Pages workflow + dynamic `BASE_PATH`; final npm gate ต้องยืนยันใน Windows/CI |

**Overall source audit: 9.73 / 10**

## Verification status

ยืนยันใน environment นี้หลังปรับ Final:

- Svelte compiler ตรวจ `.svelte` ทั้ง 5 ไฟล์: **PASS, 0 warnings**
- CSV schema/period/count: **PASS**
- Final SQL scope scan: **PASS — ไม่มีเดือน**
- Artifact hygiene scan: **PASS**

ข้อจำกัดของ environment นี้: `npm ci` ไปยัง package mirror ภายในตอบ 404 สำหรับ `zrender@6.1.0` จึงไม่อ้างว่า `npm run lint/check/build` ผ่านหลังการแก้ Final รอบนี้ใน environment นี้ แม้โปรเจกต์ก่อนแก้รอบ Final จะเคยผ่าน build/check/lint ตาม log ที่ให้มาแล้ว

ก่อน push GitHub ให้ยืนยันบน Windows หรือ GitHub Actions:

```bash
npm ci
npm run lint
npm run check
npm run build
```

ถ้าทั้ง 4 คำสั่งผ่าน ให้ถือว่า deployment gate ผ่านสมบูรณ์

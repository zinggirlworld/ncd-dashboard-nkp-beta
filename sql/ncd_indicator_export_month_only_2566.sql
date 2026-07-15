SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

------------------------------------------------------------
-- NCD Dashboard Export Query: ปีงบประมาณ + ไตรมาส + เดือน
-- Output columns match: static/ncd_indicator_summary.csv
-- Scope : Clinic 0105, Fiscal year 2566-2569, Indicators 1-18
-- Note  : Uses COLLATE DATABASE_DEFAULT to avoid collation conflict
------------------------------------------------------------

------------------------------------------------------------
-- 0) Clear temp tables
------------------------------------------------------------
IF OBJECT_ID('tempdb..#periods') IS NOT NULL DROP TABLE #periods;
IF OBJECT_ID('tempdb..#clinic_0105') IS NOT NULL DROP TABLE #clinic_0105;
IF OBJECT_ID('tempdb..#dm_visit') IS NOT NULL DROP TABLE #dm_visit;
IF OBJECT_ID('tempdb..#dm_patient') IS NOT NULL DROP TABLE #dm_patient;
IF OBJECT_ID('tempdb..#dm_type1') IS NOT NULL DROP TABLE #dm_type1;
IF OBJECT_ID('tempdb..#dm_type2') IS NOT NULL DROP TABLE #dm_type2;
IF OBJECT_ID('tempdb..#hba1c_check') IS NOT NULL DROP TABLE #hba1c_check;
IF OBJECT_ID('tempdb..#hba1c_latest') IS NOT NULL DROP TABLE #hba1c_latest;
IF OBJECT_ID('tempdb..#lipid_check') IS NOT NULL DROP TABLE #lipid_check;
IF OBJECT_ID('tempdb..#ldl_latest') IS NOT NULL DROP TABLE #ldl_latest;
IF OBJECT_ID('tempdb..#bp_latest') IS NOT NULL DROP TABLE #bp_latest;
IF OBJECT_ID('tempdb..#dm_age40') IS NOT NULL DROP TABLE #dm_age40;
IF OBJECT_ID('tempdb..#aspirin_patient') IS NOT NULL DROP TABLE #aspirin_patient;
IF OBJECT_ID('tempdb..#micro_check') IS NOT NULL DROP TABLE #micro_check;
IF OBJECT_ID('tempdb..#micro_positive') IS NOT NULL DROP TABLE #micro_positive;
IF OBJECT_ID('tempdb..#acei_arb') IS NOT NULL DROP TABLE #acei_arb;
IF OBJECT_ID('tempdb..#ipd_dx') IS NOT NULL DROP TABLE #ipd_dx;
IF OBJECT_ID('tempdb..#ipd_acute') IS NOT NULL DROP TABLE #ipd_acute;
IF OBJECT_ID('tempdb..#ipd_hypo') IS NOT NULL DROP TABLE #ipd_hypo;
IF OBJECT_ID('tempdb..#ipd_hyper') IS NOT NULL DROP TABLE #ipd_hyper;
IF OBJECT_ID('tempdb..#eye_screen') IS NOT NULL DROP TABLE #eye_screen;
IF OBJECT_ID('tempdb..#dental_screen') IS NOT NULL DROP TABLE #dental_screen;
IF OBJECT_ID('tempdb..#foot_screen') IS NOT NULL DROP TABLE #foot_screen;
IF OBJECT_ID('tempdb..#dx_all') IS NOT NULL DROP TABLE #dx_all;
IF OBJECT_ID('tempdb..#dr_patient') IS NOT NULL DROP TABLE #dr_patient;
IF OBJECT_ID('tempdb..#nephro_patient') IS NOT NULL DROP TABLE #nephro_patient;
IF OBJECT_ID('tempdb..#foot_ulcer_patient') IS NOT NULL DROP TABLE #foot_ulcer_patient;
IF OBJECT_ID('tempdb..#raw_indicator') IS NOT NULL DROP TABLE #raw_indicator;

------------------------------------------------------------
-- 1) Period table: ปีงบประมาณ + ไตรมาส + เดือน
------------------------------------------------------------
CREATE TABLE #periods (
    period_type nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    fiscal_year_be int NOT NULL,
    period_order int NOT NULL,
    period_label nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,
    date_start date NOT NULL,
    date_end date NOT NULL
);

-- ปีงบประมาณ
INSERT INTO #periods VALUES
(N'ปีงบประมาณ', 2566, 0, N'ปีงบประมาณ 2566', '2022-10-01', '2023-10-01'),
(N'ปีงบประมาณ', 2567, 0, N'ปีงบประมาณ 2567', '2023-10-01', '2024-10-01'),
(N'ปีงบประมาณ', 2568, 0, N'ปีงบประมาณ 2568', '2024-10-01', '2025-10-01'),
(N'ปีงบประมาณ', 2569, 0, N'ปีงบประมาณ 2569', '2025-10-01', '2026-10-01');

-- ไตรมาส
INSERT INTO #periods VALUES
(N'ไตรมาส', 2566, 1, N'ไตรมาส 1', '2022-10-01', '2023-01-01'),
(N'ไตรมาส', 2566, 2, N'ไตรมาส 2', '2023-01-01', '2023-04-01'),
(N'ไตรมาส', 2566, 3, N'ไตรมาส 3', '2023-04-01', '2023-07-01'),
(N'ไตรมาส', 2566, 4, N'ไตรมาส 4', '2023-07-01', '2023-10-01'),
(N'ไตรมาส', 2567, 1, N'ไตรมาส 1', '2023-10-01', '2024-01-01'),
(N'ไตรมาส', 2567, 2, N'ไตรมาส 2', '2024-01-01', '2024-04-01'),
(N'ไตรมาส', 2567, 3, N'ไตรมาส 3', '2024-04-01', '2024-07-01'),
(N'ไตรมาส', 2567, 4, N'ไตรมาส 4', '2024-07-01', '2024-10-01'),
(N'ไตรมาส', 2568, 1, N'ไตรมาส 1', '2024-10-01', '2025-01-01'),
(N'ไตรมาส', 2568, 2, N'ไตรมาส 2', '2025-01-01', '2025-04-01'),
(N'ไตรมาส', 2568, 3, N'ไตรมาส 3', '2025-04-01', '2025-07-01'),
(N'ไตรมาส', 2568, 4, N'ไตรมาส 4', '2025-07-01', '2025-10-01'),
(N'ไตรมาส', 2569, 1, N'ไตรมาส 1', '2025-10-01', '2026-01-01'),
(N'ไตรมาส', 2569, 2, N'ไตรมาส 2', '2026-01-01', '2026-04-01'),
(N'ไตรมาส', 2569, 3, N'ไตรมาส 3', '2026-04-01', '2026-07-01'),
(N'ไตรมาส', 2569, 4, N'ไตรมาส 4', '2026-07-01', '2026-10-01');

-- เดือน: order 1 = ต.ค., 12 = ก.ย.
INSERT INTO #periods VALUES
(N'เดือน', 2566, 1, N'ต.ค. 2565', '2022-10-01', '2022-11-01'),
(N'เดือน', 2566, 2, N'พ.ย. 2565', '2022-11-01', '2022-12-01'),
(N'เดือน', 2566, 3, N'ธ.ค. 2565', '2022-12-01', '2023-01-01'),
(N'เดือน', 2566, 4, N'ม.ค. 2566', '2023-01-01', '2023-02-01'),
(N'เดือน', 2566, 5, N'ก.พ. 2566', '2023-02-01', '2023-03-01'),
(N'เดือน', 2566, 6, N'มี.ค. 2566', '2023-03-01', '2023-04-01'),
(N'เดือน', 2566, 7, N'เม.ย. 2566', '2023-04-01', '2023-05-01'),
(N'เดือน', 2566, 8, N'พ.ค. 2566', '2023-05-01', '2023-06-01'),
(N'เดือน', 2566, 9, N'มิ.ย. 2566', '2023-06-01', '2023-07-01'),
(N'เดือน', 2566, 10, N'ก.ค. 2566', '2023-07-01', '2023-08-01'),
(N'เดือน', 2566, 11, N'ส.ค. 2566', '2023-08-01', '2023-09-01'),
(N'เดือน', 2566, 12, N'ก.ย. 2566', '2023-09-01', '2023-10-01'),

(N'เดือน', 2567, 1, N'ต.ค. 2566', '2023-10-01', '2023-11-01'),
(N'เดือน', 2567, 2, N'พ.ย. 2566', '2023-11-01', '2023-12-01'),
(N'เดือน', 2567, 3, N'ธ.ค. 2566', '2023-12-01', '2024-01-01'),
(N'เดือน', 2567, 4, N'ม.ค. 2567', '2024-01-01', '2024-02-01'),
(N'เดือน', 2567, 5, N'ก.พ. 2567', '2024-02-01', '2024-03-01'),
(N'เดือน', 2567, 6, N'มี.ค. 2567', '2024-03-01', '2024-04-01'),
(N'เดือน', 2567, 7, N'เม.ย. 2567', '2024-04-01', '2024-05-01'),
(N'เดือน', 2567, 8, N'พ.ค. 2567', '2024-05-01', '2024-06-01'),
(N'เดือน', 2567, 9, N'มิ.ย. 2567', '2024-06-01', '2024-07-01'),
(N'เดือน', 2567, 10, N'ก.ค. 2567', '2024-07-01', '2024-08-01'),
(N'เดือน', 2567, 11, N'ส.ค. 2567', '2024-08-01', '2024-09-01'),
(N'เดือน', 2567, 12, N'ก.ย. 2567', '2024-09-01', '2024-10-01'),

(N'เดือน', 2568, 1, N'ต.ค. 2567', '2024-10-01', '2024-11-01'),
(N'เดือน', 2568, 2, N'พ.ย. 2567', '2024-11-01', '2024-12-01'),
(N'เดือน', 2568, 3, N'ธ.ค. 2567', '2024-12-01', '2025-01-01'),
(N'เดือน', 2568, 4, N'ม.ค. 2568', '2025-01-01', '2025-02-01'),
(N'เดือน', 2568, 5, N'ก.พ. 2568', '2025-02-01', '2025-03-01'),
(N'เดือน', 2568, 6, N'มี.ค. 2568', '2025-03-01', '2025-04-01'),
(N'เดือน', 2568, 7, N'เม.ย. 2568', '2025-04-01', '2025-05-01'),
(N'เดือน', 2568, 8, N'พ.ค. 2568', '2025-05-01', '2025-06-01'),
(N'เดือน', 2568, 9, N'มิ.ย. 2568', '2025-06-01', '2025-07-01'),
(N'เดือน', 2568, 10, N'ก.ค. 2568', '2025-07-01', '2025-08-01'),
(N'เดือน', 2568, 11, N'ส.ค. 2568', '2025-08-01', '2025-09-01'),
(N'เดือน', 2568, 12, N'ก.ย. 2568', '2025-09-01', '2025-10-01'),

(N'เดือน', 2569, 1, N'ต.ค. 2568', '2025-10-01', '2025-11-01'),
(N'เดือน', 2569, 2, N'พ.ย. 2568', '2025-11-01', '2025-12-01'),
(N'เดือน', 2569, 3, N'ธ.ค. 2568', '2025-12-01', '2026-01-01'),
(N'เดือน', 2569, 4, N'ม.ค. 2569', '2026-01-01', '2026-02-01'),
(N'เดือน', 2569, 5, N'ก.พ. 2569', '2026-02-01', '2026-03-01'),
(N'เดือน', 2569, 6, N'มี.ค. 2569', '2026-03-01', '2026-04-01'),
(N'เดือน', 2569, 7, N'เม.ย. 2569', '2026-04-01', '2026-05-01'),
(N'เดือน', 2569, 8, N'พ.ค. 2569', '2026-05-01', '2026-06-01'),
(N'เดือน', 2569, 9, N'มิ.ย. 2569', '2026-06-01', '2026-07-01'),
(N'เดือน', 2569, 10, N'ก.ค. 2569', '2026-07-01', '2026-08-01'),
(N'เดือน', 2569, 11, N'ส.ค. 2569', '2026-08-01', '2026-09-01'),
(N'เดือน', 2569, 12, N'ก.ย. 2569', '2026-09-01', '2026-10-01');

CREATE INDEX IX_periods ON #periods (period_type, fiscal_year_be, period_order, date_start, date_end);

------------------------------------------------------------
-- FILTER: Export only monthly periods for fiscal year 2566
------------------------------------------------------------
DELETE FROM #periods
WHERE NOT (period_type = N'เดือน' AND fiscal_year_be = 2566);


------------------------------------------------------------
-- 2) Clinic 0105 base by period
------------------------------------------------------------
SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    P.period_label,
    P.date_start,
    P.date_end,
    CAST(V.VISITDATE AS date) AS VISITDATE,
    V.VN,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    V.BPHIGH,
    V.BPLOW
INTO #clinic_0105
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON V.VN = PR.VN
    AND V.VISITDATE = PR.VISITDATE
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE <  P.date_end
WHERE
    ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND PR.CLINIC = '0105';

CREATE INDEX IX_clinic_0105 ON #clinic_0105 (period_type, fiscal_year_be, period_order, HN, VN, VISITDATE);

------------------------------------------------------------
-- 3) DM visit / DM patient
------------------------------------------------------------
SELECT DISTINCT
    C.period_type,
    C.fiscal_year_be,
    C.period_order,
    C.period_label,
    C.date_start,
    C.date_end,
    C.VISITDATE,
    C.VN,
    C.HN,
    C.BPHIGH,
    C.BPLOW
INTO #dm_visit
FROM #clinic_0105 AS C
INNER JOIN dbo.VNDIAG AS D
    ON C.VN = D.VN
    AND C.VISITDATE = CAST(D.VISITDATE AS date)
WHERE
       D.ICDCODE LIKE 'E10%'
    OR D.ICDCODE LIKE 'E11%'
    OR D.ICDCODE LIKE 'E12%'
    OR D.ICDCODE LIKE 'E13%'
    OR D.ICDCODE LIKE 'E14%';

CREATE INDEX IX_dm_visit ON #dm_visit (period_type, fiscal_year_be, period_order, HN, VISITDATE, VN);

SELECT DISTINCT period_type, fiscal_year_be, period_order, period_label, date_start, date_end, HN
INTO #dm_patient
FROM #dm_visit;

CREATE INDEX IX_dm_patient ON #dm_patient (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT C.period_type, C.fiscal_year_be, C.period_order, C.period_label, C.date_start, C.date_end, C.HN
INTO #dm_type1
FROM #dm_visit AS C
INNER JOIN dbo.VNDIAG AS D
    ON C.VN = D.VN
    AND C.VISITDATE = CAST(D.VISITDATE AS date)
WHERE D.ICDCODE LIKE 'E10%';

CREATE INDEX IX_dm_type1 ON #dm_type1 (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT C.period_type, C.fiscal_year_be, C.period_order, C.period_label, C.date_start, C.date_end, C.HN
INTO #dm_type2
FROM #dm_visit AS C
INNER JOIN dbo.VNDIAG AS D
    ON C.VN = D.VN
    AND C.VISITDATE = CAST(D.VISITDATE AS date)
WHERE D.ICDCODE LIKE 'E11%';

CREATE INDEX IX_dm_type2 ON #dm_type2 (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 4) HbA1c 40375
------------------------------------------------------------
SELECT DISTINCT
    D.period_type,
    D.fiscal_year_be,
    D.period_order,
    D.HN
INTO #hba1c_check
FROM #dm_patient AS D
INNER JOIN dbo.LABREQ AS R
    ON D.HN = LTRIM(RTRIM(CAST(R.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
INNER JOIN dbo.LABRESULT AS L
    ON R.REQUESTNO = L.REQUESTNO
    AND R.HN = L.HN
WHERE
    L.CXLDATETIME IS NULL
    AND L.LABCODE = '40375'
    AND L.RESULTVALUE IS NOT NULL
    AND LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))) <> ''
    AND R.ENTRYDATETIME >= D.date_start
    AND R.ENTRYDATETIME <  D.date_end;

CREATE INDEX IX_hba1c_check ON #hba1c_check (period_type, fiscal_year_be, period_order, HN);

SELECT
    period_type,
    fiscal_year_be,
    period_order,
    HN,
    hba1c_value
INTO #hba1c_latest
FROM (
    SELECT
        D.period_type,
        D.fiscal_year_be,
        D.period_order,
        D.HN,
        CAST(X.result_text AS float) AS hba1c_value,
        ROW_NUMBER() OVER (
            PARTITION BY D.period_type, D.fiscal_year_be, D.period_order, D.HN
            ORDER BY L.RESULTDATETIME DESC
        ) AS rn
    FROM #dm_patient AS D
    INNER JOIN dbo.LABREQ AS R
        ON D.HN = LTRIM(RTRIM(CAST(R.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
    INNER JOIN dbo.LABRESULT AS L
        ON R.REQUESTNO = L.REQUESTNO
        AND R.HN = L.HN
    CROSS APPLY (
        SELECT REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))), ',', ''), '<', ''), '>', ''), '%', '') AS result_text
    ) AS X
    WHERE
        L.CXLDATETIME IS NULL
        AND L.LABCODE = '40375'
        AND L.RESULTVALUE IS NOT NULL
        AND LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))) <> ''
        AND X.result_text <> '.'
        AND X.result_text NOT LIKE '%[^0-9.]%'
        AND LEN(X.result_text) - LEN(REPLACE(X.result_text, '.', '')) <= 1
        AND R.ENTRYDATETIME >= D.date_start
        AND R.ENTRYDATETIME <  D.date_end
) AS A
WHERE rn = 1;

CREATE INDEX IX_hba1c_latest ON #hba1c_latest (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 5) Lipid / LDL
------------------------------------------------------------
SELECT DISTINCT
    D.period_type,
    D.fiscal_year_be,
    D.period_order,
    D.HN
INTO #lipid_check
FROM #dm_patient AS D
INNER JOIN dbo.LABREQ AS R
    ON D.HN = LTRIM(RTRIM(CAST(R.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
INNER JOIN dbo.LABRESULT AS L
    ON R.REQUESTNO = L.REQUESTNO
    AND R.HN = L.HN
WHERE
    L.CXLDATETIME IS NULL
    AND L.LABCODE IN ('322A', '322B', '322C', '322D')
    AND L.RESULTVALUE IS NOT NULL
    AND LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))) <> ''
    AND R.ENTRYDATETIME >= D.date_start
    AND R.ENTRYDATETIME <  D.date_end;

CREATE INDEX IX_lipid_check ON #lipid_check (period_type, fiscal_year_be, period_order, HN);

SELECT period_type, fiscal_year_be, period_order, HN, ldl_value
INTO #ldl_latest
FROM (
    SELECT
        D.period_type,
        D.fiscal_year_be,
        D.period_order,
        D.HN,
        CAST(X.result_text AS float) AS ldl_value,
        ROW_NUMBER() OVER (
            PARTITION BY D.period_type, D.fiscal_year_be, D.period_order, D.HN
            ORDER BY L.RESULTDATETIME DESC
        ) AS rn
    FROM #dm_patient AS D
    INNER JOIN dbo.LABREQ AS R
        ON D.HN = LTRIM(RTRIM(CAST(R.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
    INNER JOIN dbo.LABRESULT AS L
        ON R.REQUESTNO = L.REQUESTNO
        AND R.HN = L.HN
    CROSS APPLY (
        SELECT REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))), ',', ''), '<', ''), '>', ''), '%', '') AS result_text
    ) AS X
    WHERE
        L.CXLDATETIME IS NULL
        AND L.LABCODE = '322D'
        AND L.RESULTVALUE IS NOT NULL
        AND LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))) <> ''
        AND X.result_text <> '.'
        AND X.result_text NOT LIKE '%[^0-9.]%'
        AND LEN(X.result_text) - LEN(REPLACE(X.result_text, '.', '')) <= 1
        AND R.ENTRYDATETIME >= D.date_start
        AND R.ENTRYDATETIME <  D.date_end
) AS A
WHERE rn = 1;

CREATE INDEX IX_ldl_latest ON #ldl_latest (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 6) BP latest
------------------------------------------------------------
SELECT period_type, fiscal_year_be, period_order, HN, BPHIGH, BPLOW
INTO #bp_latest
FROM (
    SELECT
        period_type,
        fiscal_year_be,
        period_order,
        HN,
        BPHIGH,
        BPLOW,
        ROW_NUMBER() OVER (
            PARTITION BY period_type, fiscal_year_be, period_order, HN
            ORDER BY VISITDATE DESC, VN DESC
        ) AS rn
    FROM #dm_visit
    WHERE
        BPHIGH IS NOT NULL
        AND BPLOW IS NOT NULL
        AND BPHIGH > 0
        AND BPLOW > 0
) AS A
WHERE rn = 1;

CREATE INDEX IX_bp_latest ON #bp_latest (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 7) Aspirin age >= 40
------------------------------------------------------------
SELECT DISTINCT
    D.period_type,
    D.fiscal_year_be,
    D.period_order,
    D.HN
INTO #dm_age40
FROM (
    SELECT DISTINCT
        C.period_type,
        C.fiscal_year_be,
        C.period_order,
        C.HN,
        C.VISITDATE,
        B.BIRTHDATETIME,
        DATEDIFF(year, B.BIRTHDATETIME, C.VISITDATE)
        -
        CASE
            WHEN DATEADD(year, DATEDIFF(year, B.BIRTHDATETIME, C.VISITDATE), B.BIRTHDATETIME) > C.VISITDATE
            THEN 1 ELSE 0
        END AS age_year
    FROM #dm_visit AS C
    INNER JOIN (
        SELECT
            LTRIM(RTRIM(CAST(HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
            MIN(BIRTHDATETIME) AS BIRTHDATETIME
        FROM dbo.PATIENT_INFO
        WHERE BIRTHDATETIME IS NOT NULL
        GROUP BY LTRIM(RTRIM(CAST(HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
    ) AS B
        ON C.HN = B.HN
) AS D
WHERE D.age_year >= 40;

CREATE INDEX IX_dm_age40 ON #dm_age40 (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT
    D.period_type,
    D.fiscal_year_be,
    D.period_order,
    D.HN
INTO #aspirin_patient
FROM #dm_age40 AS D
INNER JOIN dbo.VNMST AS V
    ON D.HN = LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
INNER JOIN dbo.VNMEDICINE AS M
    ON V.VN = M.VN
    AND V.VISITDATE = M.VISITDATE
WHERE
    M.VISITDATE >= (SELECT MIN(date_start) FROM #periods P WHERE P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order)
    AND M.VISITDATE <  (SELECT MAX(date_end) FROM #periods P WHERE P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order)
    AND LTRIM(RTRIM(M.STOCKCODE)) COLLATE DATABASE_DEFAULT IN ('1020360', '1020050');

CREATE INDEX IX_aspirin_patient ON #aspirin_patient (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 8) Microalbuminuria 4039C
------------------------------------------------------------
SELECT DISTINCT
    D.period_type,
    D.fiscal_year_be,
    D.period_order,
    D.HN
INTO #micro_check
FROM #dm_patient AS D
INNER JOIN dbo.LABREQ AS R
    ON D.HN = LTRIM(RTRIM(CAST(R.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
INNER JOIN dbo.LABRESULT AS L
    ON R.REQUESTNO = L.REQUESTNO
    AND R.HN = L.HN
WHERE
    L.CXLDATETIME IS NULL
    AND L.LABCODE = '4039C'
    AND L.RESULTVALUE IS NOT NULL
    AND LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))) <> ''
    AND R.ENTRYDATETIME >= D.date_start
    AND R.ENTRYDATETIME <  D.date_end;

CREATE INDEX IX_micro_check ON #micro_check (period_type, fiscal_year_be, period_order, HN);

SELECT period_type, fiscal_year_be, period_order, HN, micro_value
INTO #micro_positive
FROM (
    SELECT
        D.period_type,
        D.fiscal_year_be,
        D.period_order,
        D.HN,
        CAST(X.result_text AS float) AS micro_value,
        ROW_NUMBER() OVER (
            PARTITION BY D.period_type, D.fiscal_year_be, D.period_order, D.HN
            ORDER BY L.RESULTDATETIME DESC
        ) AS rn
    FROM #dm_patient AS D
    INNER JOIN dbo.LABREQ AS R
        ON D.HN = LTRIM(RTRIM(CAST(R.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
    INNER JOIN dbo.LABRESULT AS L
        ON R.REQUESTNO = L.REQUESTNO
        AND R.HN = L.HN
    CROSS APPLY (
        SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))), ',', ''), '>', ''), '<', ''), '%', ''), 'มากกว่า', ''), ' ', '') AS result_text
    ) AS X
    WHERE
        L.CXLDATETIME IS NULL
        AND L.LABCODE = '4039C'
        AND L.RESULTVALUE IS NOT NULL
        AND LTRIM(RTRIM(CAST(L.RESULTVALUE AS varchar(1000)))) <> ''
        AND X.result_text <> '.'
        AND X.result_text NOT LIKE '%[^0-9.]%'
        AND LEN(X.result_text) - LEN(REPLACE(X.result_text, '.', '')) <= 1
        AND R.ENTRYDATETIME >= D.date_start
        AND R.ENTRYDATETIME <  D.date_end
) AS A
WHERE rn = 1
  AND micro_value >= 30;

CREATE INDEX IX_micro_positive ON #micro_positive (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #acei_arb
FROM dbo.VNMEDICINE AS M
INNER JOIN dbo.VNMST AS V
    ON M.VN = V.VN
    AND M.VISITDATE = V.VISITDATE
INNER JOIN #periods AS P
    ON M.VISITDATE >= P.date_start
    AND M.VISITDATE <  P.date_end
WHERE
    M.VISITDATE >= '2022-10-01'
    AND M.VISITDATE <  '2026-10-01'
    AND LTRIM(RTRIM(M.STOCKCODE)) COLLATE DATABASE_DEFAULT IN (
        '1130210',
        '1130220',
        '1130800',
        '1130320',
        '2130330',
        '2130400',
        '2130500',
        '2130610'
    );

CREATE INDEX IX_acei_arb ON #acei_arb (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 9) IPD diagnosis by discharge date
------------------------------------------------------------
SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(I.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    I.AN,
    REPLACE(LTRIM(RTRIM(ISNULL(X.ICD, ''))), '.', '') COLLATE DATABASE_DEFAULT AS ICD
INTO #ipd_dx
FROM dbo.TM_HNIPD_DREV_MT AS I
INNER JOIN #periods AS P
    ON I.DISCHARGEDATETIME >= P.date_start
    AND I.DISCHARGEDATETIME <  P.date_end
CROSS APPLY (
    VALUES
        (I.DIAGNOSES1),
        (I.DIAGNOSES2),
        (I.DIAGNOSES3),
        (I.DIAGNOSES4),
        (I.OTHERDIAGNOSES1),
        (I.OTHERDIAGNOSES2),
        (I.OTHERDIAGNOSES3),
        (I.OTHERDIAGNOSES4),
        (I.OTHERDIAGNOSES5),
        (I.OTHERDIAGNOSES6),
        (I.OTHERDIAGNOSES7),
        (I.OTHERDIAGNOSES8),
        (I.OTHERDIAGNOSES9),
        (I.OTHERDIAGNOSES10)
) AS X(ICD)
WHERE
    I.DISCHARGEDATETIME >= '2022-10-01'
    AND I.DISCHARGEDATETIME <  '2026-10-01'
    AND X.ICD IS NOT NULL
    AND LTRIM(RTRIM(X.ICD)) <> '';

CREATE INDEX IX_ipd_dx ON #ipd_dx (period_type, fiscal_year_be, period_order, HN, ICD);

SELECT DISTINCT D.period_type, D.fiscal_year_be, D.period_order, D.HN
INTO #ipd_acute
FROM #dm_patient AS D
INNER JOIN #ipd_dx AS I
    ON D.period_type = I.period_type
    AND D.fiscal_year_be = I.fiscal_year_be
    AND D.period_order = I.period_order
    AND D.HN = I.HN
WHERE
       I.ICD LIKE 'E100%' OR I.ICD LIKE 'E101%'
    OR I.ICD LIKE 'E110%' OR I.ICD LIKE 'E111%'
    OR I.ICD LIKE 'E120%' OR I.ICD LIKE 'E121%'
    OR I.ICD LIKE 'E130%' OR I.ICD LIKE 'E131%'
    OR I.ICD LIKE 'E140%' OR I.ICD LIKE 'E141%';

CREATE INDEX IX_ipd_acute ON #ipd_acute (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT D.period_type, D.fiscal_year_be, D.period_order, D.HN
INTO #ipd_hypo
FROM #dm_patient AS D
INNER JOIN #ipd_dx AS I
    ON D.period_type = I.period_type
    AND D.fiscal_year_be = I.fiscal_year_be
    AND D.period_order = I.period_order
    AND D.HN = I.HN
WHERE
       I.ICD LIKE 'E100%'
    OR I.ICD LIKE 'E110%'
    OR I.ICD LIKE 'E120%'
    OR I.ICD LIKE 'E130%'
    OR I.ICD LIKE 'E140%';

CREATE INDEX IX_ipd_hypo ON #ipd_hypo (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT D.period_type, D.fiscal_year_be, D.period_order, D.HN
INTO #ipd_hyper
FROM #dm_patient AS D
INNER JOIN #ipd_dx AS I
    ON D.period_type = I.period_type
    AND D.fiscal_year_be = I.fiscal_year_be
    AND D.period_order = I.period_order
    AND D.HN = I.HN
WHERE
       I.ICD LIKE 'E101%'
    OR I.ICD LIKE 'E111%'
    OR I.ICD LIKE 'E121%'
    OR I.ICD LIKE 'E131%'
    OR I.ICD LIKE 'E141%';

CREATE INDEX IX_ipd_hyper ON #ipd_hyper (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 10) Eye / Dental / Foot screen
------------------------------------------------------------
SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #eye_screen
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON V.VN = PR.VN
    AND V.VISITDATE = PR.VISITDATE
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE <  P.date_end
WHERE
    ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND PR.CLINIC IN ('0704', '0712');

CREATE INDEX IX_eye_screen ON #eye_screen (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #dental_screen
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON V.VN = PR.VN
    AND V.VISITDATE = PR.VISITDATE
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE <  P.date_end
WHERE
    ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND PR.CLINIC = '1117';

CREATE INDEX IX_dental_screen ON #dental_screen (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #foot_screen
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON V.VN = PR.VN
    AND V.VISITDATE = PR.VISITDATE
INNER JOIN dbo.VNDIAG AS D
    ON V.VN = D.VN
    AND V.VISITDATE = D.VISITDATE
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE <  P.date_end
WHERE
    ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND PR.CLINIC = '1201'
    AND D.ICDCODE IN ('Z0280', 'Z0281', 'Z0282', 'Z0283');

CREATE INDEX IX_foot_screen ON #foot_screen (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 11) All OPD diagnosis by period for chronic complication indicators
------------------------------------------------------------
SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    REPLACE(LTRIM(RTRIM(ISNULL(D.ICDCODE, ''))), '.', '') COLLATE DATABASE_DEFAULT AS ICD
INTO #dx_all
FROM dbo.VNMST AS V
INNER JOIN dbo.VNDIAG AS D
    ON V.VN = D.VN
    AND V.VISITDATE = D.VISITDATE
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE <  P.date_end
WHERE
    V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND D.ICDCODE IS NOT NULL
    AND LTRIM(RTRIM(D.ICDCODE)) <> '';

CREATE INDEX IX_dx_all ON #dx_all (period_type, fiscal_year_be, period_order, HN, ICD);

SELECT DISTINCT D.period_type, D.fiscal_year_be, D.period_order, D.HN
INTO #dr_patient
FROM #dm_patient AS D
INNER JOIN #dx_all AS X
    ON D.period_type = X.period_type
    AND D.fiscal_year_be = X.fiscal_year_be
    AND D.period_order = X.period_order
    AND D.HN = X.HN
WHERE
       X.ICD LIKE 'E103%'
    OR X.ICD LIKE 'E113%'
    OR X.ICD LIKE 'E123%'
    OR X.ICD LIKE 'E133%'
    OR X.ICD LIKE 'E143%'
    OR X.ICD LIKE 'H360%';

CREATE INDEX IX_dr_patient ON #dr_patient (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT D.period_type, D.fiscal_year_be, D.period_order, D.HN
INTO #nephro_patient
FROM #dm_patient AS D
INNER JOIN #dx_all AS X
    ON D.period_type = X.period_type
    AND D.fiscal_year_be = X.fiscal_year_be
    AND D.period_order = X.period_order
    AND D.HN = X.HN
WHERE
       X.ICD LIKE 'E102%'
    OR X.ICD LIKE 'E112%'
    OR X.ICD LIKE 'E122%'
    OR X.ICD LIKE 'E132%'
    OR X.ICD LIKE 'E142%'
    OR X.ICD LIKE 'N08%';

CREATE INDEX IX_nephro_patient ON #nephro_patient (period_type, fiscal_year_be, period_order, HN);

SELECT DISTINCT D.period_type, D.fiscal_year_be, D.period_order, D.HN
INTO #foot_ulcer_patient
FROM #dm_patient AS D
INNER JOIN #dx_all AS X
    ON D.period_type = X.period_type
    AND D.fiscal_year_be = X.fiscal_year_be
    AND D.period_order = X.period_order
    AND D.HN = X.HN
WHERE
       X.ICD LIKE 'L97%'
    OR X.ICD LIKE 'L03%'
    OR X.ICD LIKE 'S91%'
    OR X.ICD LIKE 'M86%';

CREATE INDEX IX_foot_ulcer_patient ON #foot_ulcer_patient (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 12) Raw indicator table
------------------------------------------------------------
CREATE TABLE #raw_indicator (
    period_type nvarchar(20) COLLATE DATABASE_DEFAULT,
    fiscal_year_be int,
    period_order int,
    period_label nvarchar(50) COLLATE DATABASE_DEFAULT,
    indicator_no int,
    indicator_name nvarchar(500) COLLATE DATABASE_DEFAULT,
    target_text nvarchar(50) COLLATE DATABASE_DEFAULT,
    target_type varchar(5) COLLATE DATABASE_DEFAULT,
    target_value numeric(10,2),
    numerator int,
    denominator int
);

------------------------------------------------------------
-- 13) Insert indicators 1-18
------------------------------------------------------------

-- 1 HbA1c checked
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       1, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจ HbA1c', N'>= 70%', '>=', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #hba1c_check GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 2 Type 2 HbA1c < 7
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       2, N'อัตราผู้ป่วยเบาหวานชนิดที่ 2 ที่มีระดับ HbA1c < 7%', N'> 40%', '>', 40,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_type2 GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT T.period_type, T.fiscal_year_be, T.period_order, COUNT(DISTINCT T.HN) numerator
    FROM #dm_type2 T
    INNER JOIN #hba1c_latest H
        ON T.period_type = H.period_type
        AND T.fiscal_year_be = H.fiscal_year_be
        AND T.period_order = H.period_order
        AND T.HN = H.HN
    WHERE H.hba1c_value < 7
    GROUP BY T.period_type, T.fiscal_year_be, T.period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 3 Type 1 HbA1c < 7
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       3, N'อัตราผู้ป่วยเบาหวานชนิดที่ 1 ที่มีระดับ HbA1c < 7%', N'> 40%', '>', 40,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_type1 GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT T.period_type, T.fiscal_year_be, T.period_order, COUNT(DISTINCT T.HN) numerator
    FROM #dm_type1 T
    INNER JOIN #hba1c_latest H
        ON T.period_type = H.period_type
        AND T.fiscal_year_be = H.fiscal_year_be
        AND T.period_order = H.period_order
        AND T.HN = H.HN
    WHERE H.hba1c_value < 7
    GROUP BY T.period_type, T.fiscal_year_be, T.period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 4 Acute DM admit
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       4, N'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลันจาก DM', N'< 4%', '<', 4,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #ipd_acute GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 5 Hypoglycemia admit
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       5, N'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลัน Hypoglycemia', N'< 4%', '<', 4,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #ipd_hypo GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 6 Hyperglycemia / DKA admit
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       6, N'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลัน Hyperglycemia, DKA', N'< 4%', '<', 4,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #ipd_hyper GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 7 Lipid profile
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       7, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจ Lipid profile', N'> 70%', '>', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #lipid_check GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 8 LDL < 100
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       8, N'อัตราผู้ป่วย DM ที่มีระดับ LDL < 100 mg/dL', N'> 60%', '>', 60,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #ldl_latest
    WHERE ldl_value < 100
    GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 9 BP <= 130/80
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       9, N'อัตราของระดับความดันโลหิตในผู้ป่วย DM <= 130/80 mmHg', N'>= 60%', '>=', 60,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #bp_latest
    WHERE BPHIGH <= 130 AND BPLOW <= 80
    GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 10 Aspirin age >=40
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       10, N'อัตราผู้ป่วย DM อายุ 40 ปีขึ้นไปที่ได้รับยา Aspirin', N'> 70%', '>', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_age40 GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #aspirin_patient GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 11 Microalbuminuria check
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       11, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจ Microalbuminuria ประจำปี', N'> 80%', '>', 80,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #micro_check GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 12 Microalbuminuria positive with ACEI/ARB
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       12, N'อัตราผู้ป่วย DM มี Microalbuminuria ที่ได้รักษาด้วยยา ACEI หรือ ARB', N'>= 60%', '>=', 60,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #micro_positive GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT M.period_type, M.fiscal_year_be, M.period_order, COUNT(DISTINCT M.HN) numerator
    FROM #micro_positive M
    INNER JOIN #acei_arb A
        ON M.period_type = A.period_type
        AND M.fiscal_year_be = A.fiscal_year_be
        AND M.period_order = A.period_order
        AND M.HN = A.HN
    GROUP BY M.period_type, M.fiscal_year_be, M.period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 13 Eye screen
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       13, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจจอประสาทตาประจำปี', N'> 70%', '>', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT E.period_type, E.fiscal_year_be, E.period_order, COUNT(DISTINCT E.HN) numerator
    FROM #eye_screen E
    INNER JOIN #dm_patient D
        ON E.period_type = D.period_type
        AND E.fiscal_year_be = D.fiscal_year_be
        AND E.period_order = D.period_order
        AND E.HN = D.HN
    GROUP BY E.period_type, E.fiscal_year_be, E.period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 14 Dental screen
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       14, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจสุขภาพช่องปากประจำปี', N'> 40%', '>', 40,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT E.period_type, E.fiscal_year_be, E.period_order, COUNT(DISTINCT E.HN) numerator
    FROM #dental_screen E
    INNER JOIN #dm_patient D
        ON E.period_type = D.period_type
        AND E.fiscal_year_be = D.fiscal_year_be
        AND E.period_order = D.period_order
        AND E.HN = D.HN
    GROUP BY E.period_type, E.fiscal_year_be, E.period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 15 Foot screen
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       15, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจเท้าอย่างละเอียดประจำปี', N'> 80%', '>', 80,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT E.period_type, E.fiscal_year_be, E.period_order, COUNT(DISTINCT E.HN) numerator
    FROM #foot_screen E
    INNER JOIN #dm_patient D
        ON E.period_type = D.period_type
        AND E.fiscal_year_be = D.fiscal_year_be
        AND E.period_order = D.period_order
        AND E.HN = D.HN
    GROUP BY E.period_type, E.fiscal_year_be, E.period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 16 Diabetic retinopathy
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       16, N'อัตราผู้ป่วยเบาหวานที่มี Diabetic retinopathy', N'< 15%', '<', 15,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #dr_patient GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 17 Diabetic nephropathy
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       17, N'อัตราผู้ป่วยเบาหวานที่มี Diabetic nephropathy', N'< 30%', '<', 30,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #nephro_patient GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

-- 18 Foot ulcer
INSERT INTO #raw_indicator
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
       18, N'อัตราผู้ป่วยเบาหวานที่มีแผลที่เท้า', N'< 5%', '<', 5,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #periods P
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) denominator
    FROM #dm_patient GROUP BY period_type, fiscal_year_be, period_order
) D ON P.period_type = D.period_type AND P.fiscal_year_be = D.fiscal_year_be AND P.period_order = D.period_order
LEFT JOIN (
    SELECT period_type, fiscal_year_be, period_order, COUNT(DISTINCT HN) numerator
    FROM #foot_ulcer_patient GROUP BY period_type, fiscal_year_be, period_order
) N ON P.period_type = N.period_type AND P.fiscal_year_be = N.fiscal_year_be AND P.period_order = N.period_order;

------------------------------------------------------------
-- 14) Final output for Svelte CSV
------------------------------------------------------------
SELECT
    period_type,
    fiscal_year_be,
    period_order,
    period_label,
    indicator_no,
    indicator_name,
    target_text,
    target_type,
    target_value,
    numerator,
    denominator,
    CAST(
        numerator * 100.0 / NULLIF(denominator, 0)
        AS numeric(10,2)
    ) AS actual_percent,
    CASE
        WHEN denominator = 0 THEN N'ไม่มีข้อมูล'
        WHEN target_type = '>='
             AND numerator * 100.0 / NULLIF(denominator, 0) >= target_value
            THEN N'ผ่าน'
        WHEN target_type = '>'
             AND numerator * 100.0 / NULLIF(denominator, 0) > target_value
            THEN N'ผ่าน'
        WHEN target_type = '<'
             AND numerator * 100.0 / NULLIF(denominator, 0) < target_value
            THEN N'ผ่าน'
        ELSE N'ไม่ผ่าน'
    END AS status,
    CAST(
        CASE
            WHEN denominator = 0 THEN NULL
            WHEN target_type IN ('>=', '>')
                THEN numerator * 100.0 / NULLIF(denominator, 0) - target_value
            WHEN target_type = '<'
                THEN target_value - numerator * 100.0 / NULLIF(denominator, 0)
            ELSE NULL
        END
        AS numeric(10,2)
    ) AS gap_from_target
FROM #raw_indicator
ORDER BY
    fiscal_year_be,
    CASE period_type
        WHEN N'ปีงบประมาณ' THEN 1
        WHEN N'ไตรมาส' THEN 2
        WHEN N'เดือน' THEN 3
        ELSE 99
    END,
    period_order,
    indicator_no;

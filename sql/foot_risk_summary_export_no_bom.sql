SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

------------------------------------------------------------
-- Diabetic Foot Risk Summary Export Query
-- Output columns match: static/foot_risk_summary.csv
-- Fiscal years: 2566-2569
-- Periods: ปีงบประมาณ + ไตรมาส
--
-- IMPORTANT DATA CONTRACT
-- 1) Preserve the verified legacy DM cohort used for historical reconciliation:
--    non-cancelled clinic 0105 visit + same-visit E10-E14 diagnosis.
-- 2) Foot-risk event: clinic 1201 + ICD Z0280-Z0283.
-- 3) Only HN present in the DM cohort for the SAME period are counted.
-- 4) If one HN has multiple risk codes in a period, the highest risk wins.
-- 5) Output always contains 4 risk rows per period, including zero counts.
--
-- Before production use, run:
-- sql/foot_risk_population_reconciliation.sql
------------------------------------------------------------

IF OBJECT_ID('tempdb..#periods') IS NOT NULL DROP TABLE #periods;
IF OBJECT_ID('tempdb..#risk_levels') IS NOT NULL DROP TABLE #risk_levels;
IF OBJECT_ID('tempdb..#dm_cohort') IS NOT NULL DROP TABLE #dm_cohort;
IF OBJECT_ID('tempdb..#foot_raw') IS NOT NULL DROP TABLE #foot_raw;
IF OBJECT_ID('tempdb..#foot_dm') IS NOT NULL DROP TABLE #foot_dm;
IF OBJECT_ID('tempdb..#foot_max_risk') IS NOT NULL DROP TABLE #foot_max_risk;

------------------------------------------------------------
-- 1) Periods
------------------------------------------------------------
CREATE TABLE #periods (
    period_type nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    fiscal_year_be int NOT NULL,
    period_order int NOT NULL,
    period_label nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,
    date_start date NOT NULL,
    date_end date NOT NULL
);

INSERT INTO #periods VALUES
(N'ปีงบประมาณ', 2566, 0, N'ปีงบประมาณ 2566', '2022-10-01', '2023-10-01'),
(N'ปีงบประมาณ', 2567, 0, N'ปีงบประมาณ 2567', '2023-10-01', '2024-10-01'),
(N'ปีงบประมาณ', 2568, 0, N'ปีงบประมาณ 2568', '2024-10-01', '2025-10-01'),
(N'ปีงบประมาณ', 2569, 0, N'ปีงบประมาณ 2569', '2025-10-01', '2026-10-01'),
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

CREATE UNIQUE INDEX IX_periods
    ON #periods (period_type, fiscal_year_be, period_order);

CREATE TABLE #risk_levels (
    risk_code varchar(10) COLLATE DATABASE_DEFAULT NOT NULL,
    risk_name nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,
    risk_order int NOT NULL
);

INSERT INTO #risk_levels VALUES
('Z0280', N'เสี่ยงต่ำ', 1),
('Z0281', N'เสี่ยงปานกลาง', 2),
('Z0282', N'เสี่ยงสูง', 3),
('Z0283', N'เสี่ยงสูงมาก', 4);

------------------------------------------------------------
-- 2) DM cohort (legacy population preserved)
-- Grain after DISTINCT: 1 HN per period.
------------------------------------------------------------
SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #dm_cohort
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON PR.VISITDATE = V.VISITDATE
    AND PR.VN = V.VN
INNER JOIN dbo.VNDIAG AS D
    ON D.VISITDATE = V.VISITDATE
    AND D.VN = V.VN
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE < P.date_end
WHERE
    V.HN IS NOT NULL
    AND LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) <> ''
    AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND PR.CLINIC = '0105'
    AND (
           D.ICDCODE LIKE 'E10%'
        OR D.ICDCODE LIKE 'E11%'
        OR D.ICDCODE LIKE 'E12%'
        OR D.ICDCODE LIKE 'E13%'
        OR D.ICDCODE LIKE 'E14%'
    );

CREATE UNIQUE INDEX IX_dm_cohort
    ON #dm_cohort (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 3) Foot-risk events
-- Verified visit joins use VISITDATE + VN.
------------------------------------------------------------
SELECT DISTINCT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    P.period_label,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    D.ICDCODE COLLATE DATABASE_DEFAULT AS risk_code,
    CASE
        WHEN D.ICDCODE = 'Z0280' THEN 1
        WHEN D.ICDCODE = 'Z0281' THEN 2
        WHEN D.ICDCODE = 'Z0282' THEN 3
        WHEN D.ICDCODE = 'Z0283' THEN 4
    END AS risk_order
INTO #foot_raw
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON PR.VISITDATE = V.VISITDATE
    AND PR.VN = V.VN
INNER JOIN dbo.VNDIAG AS D
    ON D.VISITDATE = V.VISITDATE
    AND D.VN = V.VN
INNER JOIN #periods AS P
    ON V.VISITDATE >= P.date_start
    AND V.VISITDATE < P.date_end
WHERE
    V.HN IS NOT NULL
    AND LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) <> ''
    AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND PR.CLINIC = '1201'
    AND D.ICDCODE IN ('Z0280', 'Z0281', 'Z0282', 'Z0283');

CREATE INDEX IX_foot_raw
    ON #foot_raw (period_type, fiscal_year_be, period_order, HN, risk_order);

------------------------------------------------------------
-- 4) Population fence: only same-period DM cohort
------------------------------------------------------------
SELECT
    F.period_type,
    F.fiscal_year_be,
    F.period_order,
    F.period_label,
    F.HN,
    F.risk_order
INTO #foot_dm
FROM #foot_raw AS F
INNER JOIN #dm_cohort AS D
    ON D.period_type = F.period_type
    AND D.fiscal_year_be = F.fiscal_year_be
    AND D.period_order = F.period_order
    AND D.HN = F.HN;

CREATE INDEX IX_foot_dm
    ON #foot_dm (period_type, fiscal_year_be, period_order, HN, risk_order);

------------------------------------------------------------
-- 5) Dedup: highest risk per HN per period
------------------------------------------------------------
SELECT
    period_type,
    fiscal_year_be,
    period_order,
    period_label,
    HN,
    MAX(risk_order) AS risk_order
INTO #foot_max_risk
FROM #foot_dm
GROUP BY
    period_type,
    fiscal_year_be,
    period_order,
    period_label,
    HN;

CREATE UNIQUE INDEX IX_foot_max_risk
    ON #foot_max_risk (period_type, fiscal_year_be, period_order, HN);

------------------------------------------------------------
-- 6) Final dashboard CSV
-- Always 4 risk rows per period, including zero counts.
------------------------------------------------------------
SELECT
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    P.period_label,
    R.risk_code,
    R.risk_name,
    R.risk_order,
    COUNT(F.HN) AS total_hn
FROM #periods AS P
CROSS JOIN #risk_levels AS R
LEFT JOIN #foot_max_risk AS F
    ON F.period_type = P.period_type
    AND F.fiscal_year_be = P.fiscal_year_be
    AND F.period_order = P.period_order
    AND F.risk_order = R.risk_order
GROUP BY
    P.period_type,
    P.fiscal_year_be,
    P.period_order,
    P.period_label,
    R.risk_code,
    R.risk_name,
    R.risk_order
ORDER BY
    P.fiscal_year_be,
    CASE P.period_type WHEN N'ปีงบประมาณ' THEN 1 WHEN N'ไตรมาส' THEN 2 ELSE 99 END,
    P.period_order,
    R.risk_order;

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

------------------------------------------------------------
-- Foot Risk Summary Export Query
-- Output columns match: static/foot_risk_summary.csv
-- Scope: Foot exam clinic 1201 + ICD Z0280-Z0283
-- Fiscal year 2566-2569
-- Periods: ปีงบประมาณ + ไตรมาส
-- Save as CSV: foot_risk_summary.csv
------------------------------------------------------------

IF OBJECT_ID('tempdb..#periods') IS NOT NULL DROP TABLE #periods;
IF OBJECT_ID('tempdb..#foot_raw') IS NOT NULL DROP TABLE #foot_raw;
IF OBJECT_ID('tempdb..#foot_max_risk') IS NOT NULL DROP TABLE #foot_max_risk;

------------------------------------------------------------
-- 1) Period table
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

CREATE INDEX IX_periods ON #periods (period_type, fiscal_year_be, period_order, date_start, date_end);

------------------------------------------------------------
-- 2) Pull foot risk rows
-- ถ้า HN เดียวกันมีหลาย risk code ในงวดเดียวกัน เลือกระดับความเสี่ยงสูงสุด
------------------------------------------------------------
SELECT
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
        ELSE 0
    END AS risk_order
INTO #foot_raw
FROM dbo.VNPRES AS PR WITH (NOLOCK)
INNER JOIN dbo.VNMST AS V WITH (NOLOCK)
    ON V.VN = PR.VN
    AND V.VISITDATE = PR.VISITDATE
INNER JOIN dbo.VNDIAG AS D WITH (NOLOCK)
    ON D.VN = PR.VN
    AND D.VISITDATE = PR.VISITDATE
INNER JOIN #periods AS P
    ON PR.VISITDATE >= P.date_start
    AND PR.VISITDATE <  P.date_end
WHERE
    PR.CLINIC = '1201'
    AND D.ICDCODE IN ('Z0280', 'Z0281', 'Z0282', 'Z0283')
    AND PR.VISITDATE >= '2022-10-01'
    AND PR.VISITDATE <  '2026-10-01'
    AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999';

CREATE INDEX IX_foot_raw ON #foot_raw (period_type, fiscal_year_be, period_order, HN, risk_order);

SELECT
    period_type,
    fiscal_year_be,
    period_order,
    period_label,
    HN,
    MAX(risk_order) AS risk_order
INTO #foot_max_risk
FROM #foot_raw
GROUP BY
    period_type,
    fiscal_year_be,
    period_order,
    period_label,
    HN;

CREATE INDEX IX_foot_max_risk ON #foot_max_risk (period_type, fiscal_year_be, period_order, risk_order, HN);

------------------------------------------------------------
-- 3) Final output for Dashboard CSV
------------------------------------------------------------
SELECT
    F.period_type,
    F.fiscal_year_be,
    F.period_order,
    F.period_label,
    CASE F.risk_order
        WHEN 1 THEN 'Z0280'
        WHEN 2 THEN 'Z0281'
        WHEN 3 THEN 'Z0282'
        WHEN 4 THEN 'Z0283'
    END AS risk_code,
    CASE F.risk_order
        WHEN 1 THEN N'เสี่ยงต่ำ'
        WHEN 2 THEN N'เสี่ยงปานกลาง'
        WHEN 3 THEN N'เสี่ยงสูง'
        WHEN 4 THEN N'เสี่ยงสูงมาก'
    END AS risk_name,
    F.risk_order,
    COUNT(DISTINCT F.HN) AS total_hn
FROM #foot_max_risk AS F
GROUP BY
    F.period_type,
    F.fiscal_year_be,
    F.period_order,
    F.period_label,
    F.risk_order
ORDER BY
    F.fiscal_year_be,
    CASE F.period_type
        WHEN N'ปีงบประมาณ' THEN 1
        WHEN N'ไตรมาส' THEN 2
        ELSE 99
    END,
    F.period_order,
    F.risk_order;

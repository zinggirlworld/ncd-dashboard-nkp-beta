/* NCD SCREENING ONLY v1.0 | Navicat / SQL Server
   Output 1: screening CSV (14 columns, only eye/oral/foot).
   Output 2: foot-risk CSV (8 columns, four levels per period).
   Output 3: reconciliation + provenance, NOT for dashboard CSV.
   HIS tables are READ ONLY; only local #temp tables are written.
   IDs 13/14/15 are retained solely for compatibility with the existing dashboard.
   No HbA1c, medication, IPD or other indicator calculations.
*/
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Edit this SAME date in both files. Inclusive service-date cutoff.
-- A run during this date may not include the whole day's later entries.
DECLARE @DataThroughDate date = '2026-09-28';
DECLARE @PeriodMode nvarchar(20) = N'ปีงบประมาณ';
DECLARE @QueryVersion varchar(30) = 'NCD_SCREENING_ONLY_v1.0';
DECLARE @StartedAtServer datetime = GETDATE();
DECLARE @WindowStart date = '2022-10-01';
DECLARE @WindowEnd date = '2026-10-01';
DECLARE @DataEndExclusive date = DATEADD(day, 1, @DataThroughDate);
IF @DataEndExclusive > @WindowEnd SET @DataEndExclusive = @WindowEnd;
IF @DataThroughDate < @WindowStart
BEGIN
    RAISERROR('DataThroughDate is before the supported fiscal-year range.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('tempdb..#ncd_periods') IS NOT NULL DROP TABLE #ncd_periods;
IF OBJECT_ID('tempdb..#ncd_visits') IS NOT NULL DROP TABLE #ncd_visits;
IF OBJECT_ID('tempdb..#ncd_dm') IS NOT NULL DROP TABLE #ncd_dm;
IF OBJECT_ID('tempdb..#ncd_service') IS NOT NULL DROP TABLE #ncd_service;
IF OBJECT_ID('tempdb..#ncd_foot') IS NOT NULL DROP TABLE #ncd_foot;
IF OBJECT_ID('tempdb..#ncd_domains') IS NOT NULL DROP TABLE #ncd_domains;
IF OBJECT_ID('tempdb..#ncd_counts') IS NOT NULL DROP TABLE #ncd_counts;
IF OBJECT_ID('tempdb..#ncd_risk_levels') IS NOT NULL DROP TABLE #ncd_risk_levels;
IF OBJECT_ID('tempdb..#ncd_risk_summary') IS NOT NULL DROP TABLE #ncd_risk_summary;

CREATE TABLE #ncd_periods (
    period_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    period_type nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    fiscal_year_be int NOT NULL,
    period_order int NOT NULL,
    period_label nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,
    date_start date NOT NULL,
    date_end date NOT NULL
);
-- Only the requested period type is constructed. No monthly periods.
IF @PeriodMode = N'ปีงบประมาณ'
BEGIN
    INSERT INTO #ncd_periods
        (period_type, fiscal_year_be, period_order, period_label, date_start, date_end)
    VALUES
    (N'ปีงบประมาณ',2566,0,N'ปีงบประมาณ 2566','2022-10-01','2023-10-01'),
    (N'ปีงบประมาณ',2567,0,N'ปีงบประมาณ 2567','2023-10-01','2024-10-01'),
    (N'ปีงบประมาณ',2568,0,N'ปีงบประมาณ 2568','2024-10-01','2025-10-01'),
    (N'ปีงบประมาณ',2569,0,N'ปีงบประมาณ 2569','2025-10-01','2026-10-01');
END
ELSE
BEGIN
    INSERT INTO #ncd_periods
        (period_type, fiscal_year_be, period_order, period_label, date_start, date_end)
    VALUES
    (N'ไตรมาส',2566,1,N'ไตรมาส 1','2022-10-01','2023-01-01'),
    (N'ไตรมาส',2566,2,N'ไตรมาส 2','2023-01-01','2023-04-01'),
    (N'ไตรมาส',2566,3,N'ไตรมาส 3','2023-04-01','2023-07-01'),
    (N'ไตรมาส',2566,4,N'ไตรมาส 4','2023-07-01','2023-10-01'),
    (N'ไตรมาส',2567,1,N'ไตรมาส 1','2023-10-01','2024-01-01'),
    (N'ไตรมาส',2567,2,N'ไตรมาส 2','2024-01-01','2024-04-01'),
    (N'ไตรมาส',2567,3,N'ไตรมาส 3','2024-04-01','2024-07-01'),
    (N'ไตรมาส',2567,4,N'ไตรมาส 4','2024-07-01','2024-10-01'),
    (N'ไตรมาส',2568,1,N'ไตรมาส 1','2024-10-01','2025-01-01'),
    (N'ไตรมาส',2568,2,N'ไตรมาส 2','2025-01-01','2025-04-01'),
    (N'ไตรมาส',2568,3,N'ไตรมาส 3','2025-04-01','2025-07-01'),
    (N'ไตรมาส',2568,4,N'ไตรมาส 4','2025-07-01','2025-10-01'),
    (N'ไตรมาส',2569,1,N'ไตรมาส 1','2025-10-01','2026-01-01'),
    (N'ไตรมาส',2569,2,N'ไตรมาส 2','2026-01-01','2026-04-01'),
    (N'ไตรมาส',2569,3,N'ไตรมาส 3','2026-04-01','2026-07-01'),
    (N'ไตรมาส',2569,4,N'ไตรมาส 4','2026-07-01','2026-10-01');
END;

-- Materialize relevant non-cancelled encounters once.
-- Preserve raw VISITDATE for the exact service/foot diagnosis join.
SELECT DISTINCT
    P.period_id,
    V.VISITDATE,
    V.VN,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    PR.CLINIC COLLATE DATABASE_DEFAULT AS CLINIC
INTO #ncd_visits
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON PR.VN = V.VN AND PR.VISITDATE = V.VISITDATE
INNER JOIN #ncd_periods AS P
    ON V.VISITDATE >= P.date_start AND V.VISITDATE < P.date_end
WHERE V.VISITDATE >= @WindowStart
  AND V.VISITDATE < @DataEndExclusive
  AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
  AND PR.CLINIC IN ('0105','0704','0712','1117','1201');
CREATE INDEX IX_ncd_visits ON #ncd_visits (CLINIC, period_id, HN, VN, VISITDATE);

-- Preserve the supplied 626-query's DM cohort semantics:
-- same VN + same calendar date for E10-E14, not an unrequested join change.
-- NULL HN is excluded because the original COUNT(DISTINCT HN) ignores NULL.
-- Empty HN is retained for comparability and flagged in Output 3.
SELECT DISTINCT V.period_id, V.HN
INTO #ncd_dm
FROM #ncd_visits AS V
WHERE V.CLINIC = '0105'
  AND V.HN IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM dbo.VNDIAG AS D
      WHERE D.VN = V.VN
        AND D.VISITDATE >= CAST(V.VISITDATE AS date)
        AND D.VISITDATE < DATEADD(day, 1, CAST(V.VISITDATE AS date))
        AND (D.ICDCODE LIKE 'E10%' OR D.ICDCODE LIKE 'E11%'
          OR D.ICDCODE LIKE 'E12%' OR D.ICDCODE LIKE 'E13%'
          OR D.ICDCODE LIKE 'E14%')
  );
CREATE UNIQUE INDEX IX_ncd_dm ON #ncd_dm (period_id, HN);

-- Eye and oral: one HN per domain and period, within the SAME DM cohort.
SELECT DISTINCT V.period_id, V.HN,
    CASE WHEN V.CLINIC IN ('0704','0712') THEN 13 ELSE 14 END AS indicator_no
INTO #ncd_service
FROM #ncd_visits AS V
INNER JOIN #ncd_dm AS C ON C.period_id = V.period_id AND C.HN = V.HN
WHERE V.CLINIC IN ('0704','0712','1117');
CREATE UNIQUE INDEX IX_ncd_service ON #ncd_service (period_id, indicator_no, HN);

-- SINGLE SOURCE for foot count AND all four foot-risk levels.
-- Highest risk per HN per period; repeated visits/codes do not add people.
SELECT V.period_id, V.HN,
    MAX(CASE D.ICDCODE WHEN 'Z0280' THEN 1 WHEN 'Z0281' THEN 2
                      WHEN 'Z0282' THEN 3 WHEN 'Z0283' THEN 4 END) AS risk_order
INTO #ncd_foot
FROM #ncd_visits AS V
INNER JOIN #ncd_dm AS C ON C.period_id = V.period_id AND C.HN = V.HN
INNER JOIN dbo.VNDIAG AS D ON D.VN = V.VN AND D.VISITDATE = V.VISITDATE
WHERE V.CLINIC = '1201'
  AND D.ICDCODE IN ('Z0280','Z0281','Z0282','Z0283')
GROUP BY V.period_id, V.HN;
CREATE UNIQUE INDEX IX_ncd_foot ON #ncd_foot (period_id, HN);

INSERT INTO #ncd_service (period_id, HN, indicator_no)
SELECT F.period_id, F.HN, 15 FROM #ncd_foot AS F;

CREATE TABLE #ncd_domains (
    indicator_no int NOT NULL PRIMARY KEY,
    indicator_name nvarchar(500) COLLATE DATABASE_DEFAULT NOT NULL,
    target_text nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,
    target_type varchar(5) COLLATE DATABASE_DEFAULT NOT NULL,
    target_value numeric(10,2) NOT NULL
);
-- Existing file targets retained as references, not newly approved targets.
INSERT INTO #ncd_domains VALUES
(13,N'อัตราผู้ป่วย DM ที่ได้รับการตรวจจอประสาทตาประจำปี',N'> 70%','>',70),
(14,N'อัตราผู้ป่วย DM ที่ได้รับการตรวจสุขภาพช่องปากประจำปี',N'> 40%','>',40),
(15,N'อัตราผู้ป่วย DM ที่ได้รับการตรวจเท้าอย่างละเอียดประจำปี',N'> 80%','>',80);

SELECT P.period_id, M.indicator_no,
    ISNULL(S.numerator,0) AS numerator, ISNULL(C.denominator,0) AS denominator
INTO #ncd_counts
FROM #ncd_periods AS P
CROSS JOIN #ncd_domains AS M
LEFT JOIN (
    SELECT period_id, indicator_no, COUNT(HN) AS numerator
    FROM #ncd_service GROUP BY period_id, indicator_no
) AS S ON S.period_id = P.period_id AND S.indicator_no = M.indicator_no
LEFT JOIN (
    SELECT period_id, COUNT(HN) AS denominator
    FROM #ncd_dm GROUP BY period_id
) AS C ON C.period_id = P.period_id;
CREATE UNIQUE INDEX IX_ncd_counts ON #ncd_counts (period_id, indicator_no);

CREATE TABLE #ncd_risk_levels (
    risk_order int NOT NULL PRIMARY KEY,
    risk_code varchar(10) COLLATE DATABASE_DEFAULT NOT NULL,
    risk_name nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL
);
INSERT INTO #ncd_risk_levels VALUES
(1,'Z0280',N'เสี่ยงต่ำ'),(2,'Z0281',N'เสี่ยงปานกลาง'),
(3,'Z0282',N'เสี่ยงสูง'),(4,'Z0283',N'เสี่ยงสูงมาก');

SELECT P.period_id, R.risk_order, R.risk_code, R.risk_name, COUNT(F.HN) AS total_hn
INTO #ncd_risk_summary
FROM #ncd_periods AS P
CROSS JOIN #ncd_risk_levels AS R
LEFT JOIN #ncd_foot AS F ON F.period_id = P.period_id AND F.risk_order = R.risk_order
GROUP BY P.period_id, R.risk_order, R.risk_code, R.risk_name;
CREATE UNIQUE INDEX IX_ncd_risk_summary ON #ncd_risk_summary (period_id, risk_order);

-- OUTPUT 1: ncd_indicator_summary schema, ONLY 3 screening domains.
-- Annual targets are not used to grade a single quarter.
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
    M.indicator_no, M.indicator_name, M.target_text, M.target_type, M.target_value,
    C.numerator, C.denominator,
    CAST(C.numerator * 100.0 / NULLIF(C.denominator,0) AS numeric(10,2)) AS actual_percent,
    CASE WHEN C.denominator = 0 THEN N'ไม่มีข้อมูล'
         WHEN P.period_type = N'ไตรมาส' THEN N'ไม่ประเมินเกณฑ์รายปี'
         WHEN C.numerator * 100.0 / NULLIF(C.denominator,0) > M.target_value THEN N'ผ่าน'
         ELSE N'ไม่ผ่าน' END AS status,
    CASE WHEN P.period_type = N'ไตรมาส' THEN CAST(NULL AS numeric(10,2))
         ELSE CAST(C.numerator * 100.0 / NULLIF(C.denominator,0) - M.target_value
              AS numeric(10,2)) END AS gap_from_target
FROM #ncd_counts AS C
INNER JOIN #ncd_periods AS P ON P.period_id = C.period_id
INNER JOIN #ncd_domains AS M ON M.indicator_no = C.indicator_no
ORDER BY P.fiscal_year_be, P.period_order, M.indicator_no;

-- OUTPUT 2: foot_risk_summary schema, always FOUR levels per period.
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
    R.risk_code, R.risk_name, R.risk_order, R.total_hn
FROM #ncd_risk_summary AS R
INNER JOIN #ncd_periods AS P ON P.period_id = R.period_id
ORDER BY P.fiscal_year_be, P.period_order, R.risk_order;

-- OUTPUT 3: reconciliation and export provenance. Keep as a separate CSV.
-- PASS verifies arithmetic/set consistency, NOT clinical definition validity.
-- READ COMMITTED prevents dirty reads but is NOT a database-wide snapshot.
SELECT P.period_type, P.fiscal_year_be, P.period_order, P.period_label,
    C.denominator AS dm_cohort_hn,
    C.numerator AS foot_screen_hn,
    R.risk_total_hn,
    C.numerator - R.risk_total_hn AS difference_hn,
    CASE WHEN C.numerator <> R.risk_total_hn THEN 'FAIL'
         WHEN C.numerator > C.denominator THEN 'FAIL'
         WHEN R.risk_levels <> 4 THEN 'FAIL'
         WHEN ISNULL(B.blank_hn,0) > 0 THEN 'CHECK_BLANK_HN'
         WHEN C.denominator = 0 THEN 'NO_COHORT'
         ELSE 'PASS' END AS reconciliation_status,
    ISNULL(B.blank_hn,0) AS blank_hn_in_cohort,
    CASE WHEN @DataEndExclusive < P.date_end THEN 'PARTIAL_PERIOD'
         ELSE 'PERIOD_ENDED' END AS calendar_coverage,
    P.date_start AS period_start,
    P.date_end AS period_end_exclusive,
    @DataThroughDate AS requested_data_through_date,
    CASE WHEN P.date_end < @DataEndExclusive THEN P.date_end
         ELSE @DataEndExclusive END AS effective_end_exclusive,
    @StartedAtServer AS run_started_at_server,
    GETDATE() AS run_finished_at_server,
    DB_NAME() AS source_database,
    @QueryVersion AS query_version
FROM #ncd_counts AS C
INNER JOIN #ncd_periods AS P ON P.period_id = C.period_id
INNER JOIN (
    SELECT period_id, SUM(total_hn) AS risk_total_hn, COUNT(risk_order) AS risk_levels
    FROM #ncd_risk_summary GROUP BY period_id
) AS R ON R.period_id = C.period_id
LEFT JOIN (
    SELECT period_id, COUNT(HN) AS blank_hn FROM #ncd_dm
    WHERE HN = '' GROUP BY period_id
) AS B ON B.period_id = C.period_id
WHERE C.indicator_no = 15
ORDER BY P.fiscal_year_be, P.period_order;


-- OUTPUT 4: JOIN sensitivity audit; diagnostic only, not dashboard data.
-- Materialize matching diagnosis rows ONCE for both comparison modes.
-- This read happens after Outputs 1-3; concurrent HIS edits can affect comparison.
IF OBJECT_ID('tempdb..#audit_diag') IS NOT NULL DROP TABLE #audit_diag;
IF OBJECT_ID('tempdb..#audit_dm') IS NOT NULL DROP TABLE #audit_dm;
IF OBJECT_ID('tempdb..#audit_foot') IS NOT NULL DROP TABLE #audit_foot;
IF OBJECT_ID('tempdb..#audit_modes') IS NOT NULL DROP TABLE #audit_modes;
SELECT DISTINCT V.period_id, V.HN, V.CLINIC,
    CASE WHEN D.VISITDATE = V.VISITDATE THEN 1 ELSE 0 END AS exact_match,
    CASE WHEN D.ICDCODE LIKE 'E10%' OR D.ICDCODE LIKE 'E11%'
           OR D.ICDCODE LIKE 'E12%' OR D.ICDCODE LIKE 'E13%'
           OR D.ICDCODE LIKE 'E14%' THEN 1 ELSE 0 END AS is_dm,
    CASE D.ICDCODE WHEN 'Z0280' THEN 1 WHEN 'Z0281' THEN 2
                  WHEN 'Z0282' THEN 3 WHEN 'Z0283' THEN 4 ELSE 0 END AS risk_order
INTO #audit_diag
FROM #ncd_visits AS V
INNER JOIN dbo.VNDIAG AS D
    ON D.VN = V.VN
   AND D.VISITDATE >= CAST(V.VISITDATE AS date)
   AND D.VISITDATE < DATEADD(day,1,CAST(V.VISITDATE AS date))
WHERE V.HN IS NOT NULL
  AND V.CLINIC IN ('0105','1201')
  AND (D.ICDCODE LIKE 'E10%' OR D.ICDCODE LIKE 'E11%'
    OR D.ICDCODE LIKE 'E12%' OR D.ICDCODE LIKE 'E13%'
    OR D.ICDCODE LIKE 'E14%' OR D.ICDCODE IN ('Z0280','Z0281','Z0282','Z0283'));

CREATE TABLE #audit_modes (mode_id int PRIMARY KEY, dm_exact int, foot_exact int,
    mode_label varchar(50) COLLATE DATABASE_DEFAULT);
INSERT INTO #audit_modes VALUES
(1,0,1,'CURRENT_DM_DAY_FOOT_EXACT'),
(2,1,1,'DM_EXACT_FOOT_EXACT'),
(3,0,0,'DM_DAY_FOOT_DAY'),
(4,1,0,'DM_EXACT_FOOT_DAY');

SELECT DISTINCT M.mode_id, D.period_id, D.HN
INTO #audit_dm
FROM #audit_modes AS M
INNER JOIN #audit_diag AS D ON (M.dm_exact=0 OR D.exact_match=1)
WHERE D.CLINIC='0105' AND D.is_dm=1;
CREATE UNIQUE INDEX IX_audit_dm ON #audit_dm(mode_id,period_id,HN);

SELECT M.mode_id, D.period_id, D.HN, MAX(D.risk_order) AS risk_order
INTO #audit_foot
FROM #audit_modes AS M
INNER JOIN #audit_diag AS D ON (M.foot_exact=0 OR D.exact_match=1)
INNER JOIN #audit_dm AS C
 ON C.mode_id=M.mode_id AND C.period_id=D.period_id AND C.HN=D.HN
WHERE D.CLINIC='1201' AND D.risk_order>0
GROUP BY M.mode_id,D.period_id,D.HN;
CREATE UNIQUE INDEX IX_audit_foot ON #audit_foot(mode_id,period_id,HN);

SELECT P.period_type,P.fiscal_year_be,P.period_order,P.period_label,
 M.mode_id,M.mode_label,
 (SELECT COUNT(*) FROM #audit_dm AS C WHERE C.mode_id=M.mode_id AND C.period_id=P.period_id) AS dm_cohort_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=P.period_id) AS foot_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=P.period_id AND F.risk_order=1) AS risk_low_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=P.period_id AND F.risk_order=2) AS risk_moderate_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=P.period_id AND F.risk_order=3) AS risk_high_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=P.period_id AND F.risk_order=4) AS risk_very_high_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=P.period_id
  AND NOT EXISTS (SELECT 1 FROM #audit_foot AS B WHERE B.mode_id=1 AND B.period_id=F.period_id AND B.HN=F.HN)) AS added_vs_current_hn,
 (SELECT COUNT(*) FROM #audit_foot AS B WHERE B.mode_id=1 AND B.period_id=P.period_id
  AND NOT EXISTS (SELECT 1 FROM #audit_foot AS F WHERE F.mode_id=M.mode_id AND F.period_id=B.period_id AND F.HN=B.HN)) AS removed_vs_current_hn,
 (SELECT COUNT(*) FROM #audit_foot AS F WHERE F.mode_id=1 AND F.period_id=P.period_id)-N.numerator AS audit_current_minus_output1,
 @DataThroughDate AS requested_data_through_date,
 GETDATE() AS audit_finished_at_server
FROM #ncd_periods AS P CROSS JOIN #audit_modes AS M
INNER JOIN #ncd_counts AS N ON N.period_id=P.period_id AND N.indicator_no=15
ORDER BY P.fiscal_year_be,P.period_order,M.mode_id;

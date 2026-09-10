SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

------------------------------------------------------------
-- Foot-risk population reconciliation / READ ONLY
-- Purpose: explain why dashboard counts differ.
-- Default scope: fiscal year 2569.
------------------------------------------------------------
DECLARE @DateStart date = '2025-10-01';
DECLARE @DateEnd   date = '2026-10-01';

IF OBJECT_ID('tempdb..#clinic0105_all') IS NOT NULL DROP TABLE #clinic0105_all;
IF OBJECT_ID('tempdb..#clinic0105_dm') IS NOT NULL DROP TABLE #clinic0105_dm;
IF OBJECT_ID('tempdb..#foot_all') IS NOT NULL DROP TABLE #foot_all;

-- A) All non-cancelled HN attending clinic 0105.
SELECT DISTINCT
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #clinic0105_all
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON PR.VISITDATE = V.VISITDATE
    AND PR.VN = V.VN
WHERE
    V.VISITDATE >= @DateStart
    AND V.VISITDATE < @DateEnd
    AND PR.CLINIC = '0105'
    AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND V.HN IS NOT NULL
    AND LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) <> '';

-- B) Legacy DM cohort used for historical reconciliation:
-- clinic 0105 + same-visit E10-E14 diagnosis.
SELECT DISTINCT
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #clinic0105_dm
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON PR.VISITDATE = V.VISITDATE
    AND PR.VN = V.VN
INNER JOIN dbo.VNDIAG AS D
    ON D.VISITDATE = V.VISITDATE
    AND D.VN = V.VN
WHERE
    V.VISITDATE >= @DateStart
    AND V.VISITDATE < @DateEnd
    AND PR.CLINIC = '0105'
    AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND V.HN IS NOT NULL
    AND LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) <> ''
    AND (
           D.ICDCODE LIKE 'E10%'
        OR D.ICDCODE LIKE 'E11%'
        OR D.ICDCODE LIKE 'E12%'
        OR D.ICDCODE LIKE 'E13%'
        OR D.ICDCODE LIKE 'E14%'
    );

-- C) All HN with foot-risk codes in clinic 1201, without DM population fence.
SELECT DISTINCT
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #foot_all
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS PR
    ON PR.VISITDATE = V.VISITDATE
    AND PR.VN = V.VN
INNER JOIN dbo.VNDIAG AS D
    ON D.VISITDATE = V.VISITDATE
    AND D.VN = V.VN
WHERE
    V.VISITDATE >= @DateStart
    AND V.VISITDATE < @DateEnd
    AND PR.CLINIC = '1201'
    AND ISNULL(PR.CLOSEVISITTYPE, '') <> '999'
    AND D.ICDCODE IN ('Z0280', 'Z0281', 'Z0282', 'Z0283')
    AND V.HN IS NOT NULL
    AND LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) <> '';

------------------------------------------------------------
-- Result 1: population counts
------------------------------------------------------------
SELECT N'01 clinic 0105 all HN' AS metric, COUNT(*) AS total_hn FROM #clinic0105_all
UNION ALL
SELECT N'02 clinic 0105 + same-visit E10-E14', COUNT(*) FROM #clinic0105_dm
UNION ALL
SELECT N'03 foot risk clinic 1201 all HN', COUNT(*) FROM #foot_all
UNION ALL
SELECT N'04 foot risk ∩ clinic0105 all', COUNT(*)
FROM #foot_all AS F INNER JOIN #clinic0105_all AS C ON C.HN = F.HN
UNION ALL
SELECT N'05 foot risk ∩ legacy DM cohort', COUNT(*)
FROM #foot_all AS F INNER JOIN #clinic0105_dm AS D ON D.HN = F.HN
UNION ALL
SELECT N'06 foot risk NOT in legacy DM cohort', COUNT(*)
FROM #foot_all AS F LEFT JOIN #clinic0105_dm AS D ON D.HN = F.HN WHERE D.HN IS NULL;

------------------------------------------------------------
-- Result 2: reconciliation identity
-- Corrected dashboard population should equal metric 05.
------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM #foot_all AS F INNER JOIN #clinic0105_dm AS D ON D.HN = F.HN) AS corrected_dashboard_hn,
    (SELECT COUNT(*) FROM #foot_all) AS unrestricted_foot_hn,
    (SELECT COUNT(*) FROM #foot_all AS F LEFT JOIN #clinic0105_dm AS D ON D.HN = F.HN WHERE D.HN IS NULL) AS excluded_not_in_dm_cohort;

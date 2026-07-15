SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

------------------------------------------------------------
-- NCD Dashboard Export Query
-- Output: ncd_indicator_summary.csv
-- Scope : Clinic 0105, Fiscal year 2566-2569, Indicators 1-18
-- Note  : Added COLLATE DATABASE_DEFAULT to avoid collation conflict
------------------------------------------------------------

------------------------------------------------------------
-- 0) Clear temp tables
------------------------------------------------------------
IF OBJECT_ID('tempdb..#fy') IS NOT NULL DROP TABLE #fy;
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
-- 1) Fiscal years
------------------------------------------------------------
CREATE TABLE #fy (
    fiscal_year varchar(4) COLLATE DATABASE_DEFAULT NOT NULL
);

INSERT INTO #fy VALUES ('2566'), ('2567'), ('2568'), ('2569');

------------------------------------------------------------
-- 2) Clinic 0105 base
------------------------------------------------------------
SELECT DISTINCT
    CAST(V.VISITDATE AS date) AS VISITDATE,
    V.VN,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    V.BPHIGH,
    V.BPLOW,
    CAST(
        CASE
            WHEN V.VISITDATE >= '2022-10-01' AND V.VISITDATE < '2023-10-01' THEN '2566'
            WHEN V.VISITDATE >= '2023-10-01' AND V.VISITDATE < '2024-10-01' THEN '2567'
            WHEN V.VISITDATE >= '2024-10-01' AND V.VISITDATE < '2025-10-01' THEN '2568'
            WHEN V.VISITDATE >= '2025-10-01' AND V.VISITDATE < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year
INTO #clinic_0105
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS P
    ON V.VN = P.VN
    AND V.VISITDATE = P.VISITDATE
WHERE
    ISNULL(P.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND P.CLINIC = '0105';

CREATE INDEX IX_clinic_0105 ON #clinic_0105 (fiscal_year, HN, VN, VISITDATE);

------------------------------------------------------------
-- 3) DM visit / DM patient
------------------------------------------------------------
SELECT DISTINCT
    C.fiscal_year,
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

CREATE INDEX IX_dm_visit ON #dm_visit (fiscal_year, HN, VISITDATE, VN);

SELECT DISTINCT fiscal_year, HN
INTO #dm_patient
FROM #dm_visit;

CREATE INDEX IX_dm_patient ON #dm_patient (fiscal_year, HN);

SELECT DISTINCT C.fiscal_year, C.HN
INTO #dm_type1
FROM #dm_visit AS C
INNER JOIN dbo.VNDIAG AS D
    ON C.VN = D.VN
    AND C.VISITDATE = CAST(D.VISITDATE AS date)
WHERE D.ICDCODE LIKE 'E10%';

CREATE INDEX IX_dm_type1 ON #dm_type1 (fiscal_year, HN);

SELECT DISTINCT C.fiscal_year, C.HN
INTO #dm_type2
FROM #dm_visit AS C
INNER JOIN dbo.VNDIAG AS D
    ON C.VN = D.VN
    AND C.VISITDATE = CAST(D.VISITDATE AS date)
WHERE D.ICDCODE LIKE 'E11%';

CREATE INDEX IX_dm_type2 ON #dm_type2 (fiscal_year, HN);

------------------------------------------------------------
-- 4) HbA1c 40375
------------------------------------------------------------
SELECT DISTINCT
    D.fiscal_year,
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
    AND R.ENTRYDATETIME >= CASE
        WHEN D.fiscal_year = '2566' THEN '2022-10-01'
        WHEN D.fiscal_year = '2567' THEN '2023-10-01'
        WHEN D.fiscal_year = '2568' THEN '2024-10-01'
        WHEN D.fiscal_year = '2569' THEN '2025-10-01'
    END
    AND R.ENTRYDATETIME < CASE
        WHEN D.fiscal_year = '2566' THEN '2023-10-01'
        WHEN D.fiscal_year = '2567' THEN '2024-10-01'
        WHEN D.fiscal_year = '2568' THEN '2025-10-01'
        WHEN D.fiscal_year = '2569' THEN '2026-10-01'
    END;

CREATE INDEX IX_hba1c_check ON #hba1c_check (fiscal_year, HN);

SELECT
    fiscal_year,
    HN,
    hba1c_value
INTO #hba1c_latest
FROM (
    SELECT
        D.fiscal_year,
        D.HN,
        CAST(X.result_text AS float) AS hba1c_value,
        ROW_NUMBER() OVER (
            PARTITION BY D.fiscal_year, D.HN
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
        AND R.ENTRYDATETIME >= CASE
            WHEN D.fiscal_year = '2566' THEN '2022-10-01'
            WHEN D.fiscal_year = '2567' THEN '2023-10-01'
            WHEN D.fiscal_year = '2568' THEN '2024-10-01'
            WHEN D.fiscal_year = '2569' THEN '2025-10-01'
        END
        AND R.ENTRYDATETIME < CASE
            WHEN D.fiscal_year = '2566' THEN '2023-10-01'
            WHEN D.fiscal_year = '2567' THEN '2024-10-01'
            WHEN D.fiscal_year = '2568' THEN '2025-10-01'
            WHEN D.fiscal_year = '2569' THEN '2026-10-01'
        END
) AS A
WHERE rn = 1;

CREATE INDEX IX_hba1c_latest ON #hba1c_latest (fiscal_year, HN);

------------------------------------------------------------
-- 5) Lipid / LDL
------------------------------------------------------------
SELECT DISTINCT
    D.fiscal_year,
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
    AND R.ENTRYDATETIME >= CASE
        WHEN D.fiscal_year = '2566' THEN '2022-10-01'
        WHEN D.fiscal_year = '2567' THEN '2023-10-01'
        WHEN D.fiscal_year = '2568' THEN '2024-10-01'
        WHEN D.fiscal_year = '2569' THEN '2025-10-01'
    END
    AND R.ENTRYDATETIME < CASE
        WHEN D.fiscal_year = '2566' THEN '2023-10-01'
        WHEN D.fiscal_year = '2567' THEN '2024-10-01'
        WHEN D.fiscal_year = '2568' THEN '2025-10-01'
        WHEN D.fiscal_year = '2569' THEN '2026-10-01'
    END;

CREATE INDEX IX_lipid_check ON #lipid_check (fiscal_year, HN);

SELECT fiscal_year, HN, ldl_value
INTO #ldl_latest
FROM (
    SELECT
        D.fiscal_year,
        D.HN,
        CAST(X.result_text AS float) AS ldl_value,
        ROW_NUMBER() OVER (
            PARTITION BY D.fiscal_year, D.HN
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
        AND R.ENTRYDATETIME >= CASE
            WHEN D.fiscal_year = '2566' THEN '2022-10-01'
            WHEN D.fiscal_year = '2567' THEN '2023-10-01'
            WHEN D.fiscal_year = '2568' THEN '2024-10-01'
            WHEN D.fiscal_year = '2569' THEN '2025-10-01'
        END
        AND R.ENTRYDATETIME < CASE
            WHEN D.fiscal_year = '2566' THEN '2023-10-01'
            WHEN D.fiscal_year = '2567' THEN '2024-10-01'
            WHEN D.fiscal_year = '2568' THEN '2025-10-01'
            WHEN D.fiscal_year = '2569' THEN '2026-10-01'
        END
) AS A
WHERE rn = 1;

CREATE INDEX IX_ldl_latest ON #ldl_latest (fiscal_year, HN);

------------------------------------------------------------
-- 6) BP latest
------------------------------------------------------------
SELECT fiscal_year, HN, BPHIGH, BPLOW
INTO #bp_latest
FROM (
    SELECT
        fiscal_year,
        HN,
        BPHIGH,
        BPLOW,
        ROW_NUMBER() OVER (
            PARTITION BY fiscal_year, HN
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

CREATE INDEX IX_bp_latest ON #bp_latest (fiscal_year, HN);

------------------------------------------------------------
-- 7) Aspirin age >= 40
------------------------------------------------------------
SELECT DISTINCT
    D.fiscal_year,
    D.HN
INTO #dm_age40
FROM (
    SELECT DISTINCT
        C.fiscal_year,
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
        ON C.HN COLLATE DATABASE_DEFAULT = B.HN COLLATE DATABASE_DEFAULT
) AS D
WHERE D.age_year >= 40;

CREATE INDEX IX_dm_age40 ON #dm_age40 (fiscal_year, HN);

SELECT DISTINCT
    D.fiscal_year,
    D.HN
INTO #aspirin_patient
FROM #dm_age40 AS D
INNER JOIN dbo.VNMST AS V
    ON D.HN = LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT
INNER JOIN dbo.VNMEDICINE AS M
    ON V.VN = M.VN
    AND V.VISITDATE = M.VISITDATE
WHERE
    M.VISITDATE >= CASE
        WHEN D.fiscal_year = '2566' THEN '2022-10-01'
        WHEN D.fiscal_year = '2567' THEN '2023-10-01'
        WHEN D.fiscal_year = '2568' THEN '2024-10-01'
        WHEN D.fiscal_year = '2569' THEN '2025-10-01'
    END
    AND M.VISITDATE < CASE
        WHEN D.fiscal_year = '2566' THEN '2023-10-01'
        WHEN D.fiscal_year = '2567' THEN '2024-10-01'
        WHEN D.fiscal_year = '2568' THEN '2025-10-01'
        WHEN D.fiscal_year = '2569' THEN '2026-10-01'
    END
    AND LTRIM(RTRIM(M.STOCKCODE)) COLLATE DATABASE_DEFAULT IN ('1020360', '1020050');

CREATE INDEX IX_aspirin_patient ON #aspirin_patient (fiscal_year, HN);

------------------------------------------------------------
-- 8) Microalbuminuria 4039C
------------------------------------------------------------
SELECT DISTINCT
    D.fiscal_year,
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
    AND R.ENTRYDATETIME >= CASE
        WHEN D.fiscal_year = '2566' THEN '2022-10-01'
        WHEN D.fiscal_year = '2567' THEN '2023-10-01'
        WHEN D.fiscal_year = '2568' THEN '2024-10-01'
        WHEN D.fiscal_year = '2569' THEN '2025-10-01'
    END
    AND R.ENTRYDATETIME < CASE
        WHEN D.fiscal_year = '2566' THEN '2023-10-01'
        WHEN D.fiscal_year = '2567' THEN '2024-10-01'
        WHEN D.fiscal_year = '2568' THEN '2025-10-01'
        WHEN D.fiscal_year = '2569' THEN '2026-10-01'
    END;

CREATE INDEX IX_micro_check ON #micro_check (fiscal_year, HN);

SELECT fiscal_year, HN, micro_value
INTO #micro_positive
FROM (
    SELECT
        D.fiscal_year,
        D.HN,
        CAST(X.result_text AS float) AS micro_value,
        ROW_NUMBER() OVER (
            PARTITION BY D.fiscal_year, D.HN
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
        AND R.ENTRYDATETIME >= CASE
            WHEN D.fiscal_year = '2566' THEN '2022-10-01'
            WHEN D.fiscal_year = '2567' THEN '2023-10-01'
            WHEN D.fiscal_year = '2568' THEN '2024-10-01'
            WHEN D.fiscal_year = '2569' THEN '2025-10-01'
        END
        AND R.ENTRYDATETIME < CASE
            WHEN D.fiscal_year = '2566' THEN '2023-10-01'
            WHEN D.fiscal_year = '2567' THEN '2024-10-01'
            WHEN D.fiscal_year = '2568' THEN '2025-10-01'
            WHEN D.fiscal_year = '2569' THEN '2026-10-01'
        END
) AS A
WHERE rn = 1
  AND micro_value >= 30;

CREATE INDEX IX_micro_positive ON #micro_positive (fiscal_year, HN);

SELECT DISTINCT
    CAST(
        CASE
            WHEN M.VISITDATE >= '2022-10-01' AND M.VISITDATE < '2023-10-01' THEN '2566'
            WHEN M.VISITDATE >= '2023-10-01' AND M.VISITDATE < '2024-10-01' THEN '2567'
            WHEN M.VISITDATE >= '2024-10-01' AND M.VISITDATE < '2025-10-01' THEN '2568'
            WHEN M.VISITDATE >= '2025-10-01' AND M.VISITDATE < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #acei_arb
FROM dbo.VNMEDICINE AS M
INNER JOIN dbo.VNMST AS V
    ON M.VN = V.VN
    AND M.VISITDATE = V.VISITDATE
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

CREATE INDEX IX_acei_arb ON #acei_arb (fiscal_year, HN);

------------------------------------------------------------
-- 9) IPD diagnosis
------------------------------------------------------------
SELECT DISTINCT
    CAST(
        CASE
            WHEN I.DISCHARGEDATETIME >= '2022-10-01' AND I.DISCHARGEDATETIME < '2023-10-01' THEN '2566'
            WHEN I.DISCHARGEDATETIME >= '2023-10-01' AND I.DISCHARGEDATETIME < '2024-10-01' THEN '2567'
            WHEN I.DISCHARGEDATETIME >= '2024-10-01' AND I.DISCHARGEDATETIME < '2025-10-01' THEN '2568'
            WHEN I.DISCHARGEDATETIME >= '2025-10-01' AND I.DISCHARGEDATETIME < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year,
    LTRIM(RTRIM(CAST(I.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    I.AN,
    REPLACE(LTRIM(RTRIM(ISNULL(X.ICD, ''))), '.', '') COLLATE DATABASE_DEFAULT AS ICD
INTO #ipd_dx
FROM dbo.TM_HNIPD_DREV_MT AS I
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

CREATE INDEX IX_ipd_dx ON #ipd_dx (fiscal_year, HN, ICD);

SELECT DISTINCT D.fiscal_year, D.HN
INTO #ipd_acute
FROM #dm_patient AS D
INNER JOIN #ipd_dx AS I
    ON D.fiscal_year COLLATE DATABASE_DEFAULT = I.fiscal_year COLLATE DATABASE_DEFAULT
    AND D.HN COLLATE DATABASE_DEFAULT = I.HN COLLATE DATABASE_DEFAULT
WHERE
       I.ICD LIKE 'E100%' OR I.ICD LIKE 'E101%'
    OR I.ICD LIKE 'E110%' OR I.ICD LIKE 'E111%'
    OR I.ICD LIKE 'E120%' OR I.ICD LIKE 'E121%'
    OR I.ICD LIKE 'E130%' OR I.ICD LIKE 'E131%'
    OR I.ICD LIKE 'E140%' OR I.ICD LIKE 'E141%';

CREATE INDEX IX_ipd_acute ON #ipd_acute (fiscal_year, HN);

SELECT DISTINCT D.fiscal_year, D.HN
INTO #ipd_hypo
FROM #dm_patient AS D
INNER JOIN #ipd_dx AS I
    ON D.fiscal_year COLLATE DATABASE_DEFAULT = I.fiscal_year COLLATE DATABASE_DEFAULT
    AND D.HN COLLATE DATABASE_DEFAULT = I.HN COLLATE DATABASE_DEFAULT
WHERE
       I.ICD LIKE 'E100%'
    OR I.ICD LIKE 'E110%'
    OR I.ICD LIKE 'E120%'
    OR I.ICD LIKE 'E130%'
    OR I.ICD LIKE 'E140%';

CREATE INDEX IX_ipd_hypo ON #ipd_hypo (fiscal_year, HN);

SELECT DISTINCT D.fiscal_year, D.HN
INTO #ipd_hyper
FROM #dm_patient AS D
INNER JOIN #ipd_dx AS I
    ON D.fiscal_year COLLATE DATABASE_DEFAULT = I.fiscal_year COLLATE DATABASE_DEFAULT
    AND D.HN COLLATE DATABASE_DEFAULT = I.HN COLLATE DATABASE_DEFAULT
WHERE
       I.ICD LIKE 'E101%'
    OR I.ICD LIKE 'E111%'
    OR I.ICD LIKE 'E121%'
    OR I.ICD LIKE 'E131%'
    OR I.ICD LIKE 'E141%';

CREATE INDEX IX_ipd_hyper ON #ipd_hyper (fiscal_year, HN);

------------------------------------------------------------
-- 10) Eye / Dental / Foot screen
------------------------------------------------------------
SELECT DISTINCT
    CAST(
        CASE
            WHEN V.VISITDATE >= '2022-10-01' AND V.VISITDATE < '2023-10-01' THEN '2566'
            WHEN V.VISITDATE >= '2023-10-01' AND V.VISITDATE < '2024-10-01' THEN '2567'
            WHEN V.VISITDATE >= '2024-10-01' AND V.VISITDATE < '2025-10-01' THEN '2568'
            WHEN V.VISITDATE >= '2025-10-01' AND V.VISITDATE < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #eye_screen
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS P
    ON V.VN = P.VN
    AND V.VISITDATE = P.VISITDATE
WHERE
    ISNULL(P.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND P.CLINIC IN ('0704', '0712');

CREATE INDEX IX_eye_screen ON #eye_screen (fiscal_year, HN);

SELECT DISTINCT
    CAST(
        CASE
            WHEN V.VISITDATE >= '2022-10-01' AND V.VISITDATE < '2023-10-01' THEN '2566'
            WHEN V.VISITDATE >= '2023-10-01' AND V.VISITDATE < '2024-10-01' THEN '2567'
            WHEN V.VISITDATE >= '2024-10-01' AND V.VISITDATE < '2025-10-01' THEN '2568'
            WHEN V.VISITDATE >= '2025-10-01' AND V.VISITDATE < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #dental_screen
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS P
    ON V.VN = P.VN
    AND V.VISITDATE = P.VISITDATE
WHERE
    ISNULL(P.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND P.CLINIC = '1117';

CREATE INDEX IX_dental_screen ON #dental_screen (fiscal_year, HN);

SELECT DISTINCT
    CAST(
        CASE
            WHEN V.VISITDATE >= '2022-10-01' AND V.VISITDATE < '2023-10-01' THEN '2566'
            WHEN V.VISITDATE >= '2023-10-01' AND V.VISITDATE < '2024-10-01' THEN '2567'
            WHEN V.VISITDATE >= '2024-10-01' AND V.VISITDATE < '2025-10-01' THEN '2568'
            WHEN V.VISITDATE >= '2025-10-01' AND V.VISITDATE < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN
INTO #foot_screen
FROM dbo.VNMST AS V
INNER JOIN dbo.VNPRES AS P
    ON V.VN = P.VN
    AND V.VISITDATE = P.VISITDATE
INNER JOIN dbo.VNDIAG AS D
    ON V.VN = D.VN
    AND V.VISITDATE = D.VISITDATE
WHERE
    ISNULL(P.CLOSEVISITTYPE, '') <> '999'
    AND V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND P.CLINIC = '1201'
    AND D.ICDCODE IN ('Z0280', 'Z0281', 'Z0282', 'Z0283');

CREATE INDEX IX_foot_screen ON #foot_screen (fiscal_year, HN);

------------------------------------------------------------
-- 11) All diagnosis in fiscal year for complication indicators
------------------------------------------------------------
SELECT DISTINCT
    CAST(
        CASE
            WHEN V.VISITDATE >= '2022-10-01' AND V.VISITDATE < '2023-10-01' THEN '2566'
            WHEN V.VISITDATE >= '2023-10-01' AND V.VISITDATE < '2024-10-01' THEN '2567'
            WHEN V.VISITDATE >= '2024-10-01' AND V.VISITDATE < '2025-10-01' THEN '2568'
            WHEN V.VISITDATE >= '2025-10-01' AND V.VISITDATE < '2026-10-01' THEN '2569'
        END AS varchar(4)
    ) COLLATE DATABASE_DEFAULT AS fiscal_year,
    LTRIM(RTRIM(CAST(V.HN AS varchar(50)))) COLLATE DATABASE_DEFAULT AS HN,
    REPLACE(LTRIM(RTRIM(ISNULL(D.ICDCODE, ''))), '.', '') COLLATE DATABASE_DEFAULT AS ICD
INTO #dx_all
FROM dbo.VNMST AS V
INNER JOIN dbo.VNDIAG AS D
    ON V.VN = D.VN
    AND V.VISITDATE = D.VISITDATE
WHERE
    V.VISITDATE >= '2022-10-01'
    AND V.VISITDATE <  '2026-10-01'
    AND D.ICDCODE IS NOT NULL
    AND LTRIM(RTRIM(D.ICDCODE)) <> '';

CREATE INDEX IX_dx_all ON #dx_all (fiscal_year, HN, ICD);

SELECT DISTINCT D.fiscal_year, D.HN
INTO #dr_patient
FROM #dm_patient AS D
INNER JOIN #dx_all AS X
    ON D.fiscal_year COLLATE DATABASE_DEFAULT = X.fiscal_year COLLATE DATABASE_DEFAULT
    AND D.HN COLLATE DATABASE_DEFAULT = X.HN COLLATE DATABASE_DEFAULT
WHERE
       X.ICD LIKE 'E103%'
    OR X.ICD LIKE 'E113%'
    OR X.ICD LIKE 'E123%'
    OR X.ICD LIKE 'E133%'
    OR X.ICD LIKE 'E143%'
    OR X.ICD LIKE 'H360%';

CREATE INDEX IX_dr_patient ON #dr_patient (fiscal_year, HN);

SELECT DISTINCT D.fiscal_year, D.HN
INTO #nephro_patient
FROM #dm_patient AS D
INNER JOIN #dx_all AS X
    ON D.fiscal_year COLLATE DATABASE_DEFAULT = X.fiscal_year COLLATE DATABASE_DEFAULT
    AND D.HN COLLATE DATABASE_DEFAULT = X.HN COLLATE DATABASE_DEFAULT
WHERE
       X.ICD LIKE 'E102%'
    OR X.ICD LIKE 'E112%'
    OR X.ICD LIKE 'E122%'
    OR X.ICD LIKE 'E132%'
    OR X.ICD LIKE 'E142%'
    OR X.ICD LIKE 'N08%';

CREATE INDEX IX_nephro_patient ON #nephro_patient (fiscal_year, HN);

SELECT DISTINCT D.fiscal_year, D.HN
INTO #foot_ulcer_patient
FROM #dm_patient AS D
INNER JOIN #dx_all AS X
    ON D.fiscal_year COLLATE DATABASE_DEFAULT = X.fiscal_year COLLATE DATABASE_DEFAULT
    AND D.HN COLLATE DATABASE_DEFAULT = X.HN COLLATE DATABASE_DEFAULT
WHERE
       X.ICD LIKE 'L97%'
    OR X.ICD LIKE 'L03%'
    OR X.ICD LIKE 'S91%'
    OR X.ICD LIKE 'M86%';

CREATE INDEX IX_foot_ulcer_patient ON #foot_ulcer_patient (fiscal_year, HN);

------------------------------------------------------------
-- 12) Raw indicator table
------------------------------------------------------------
CREATE TABLE #raw_indicator (
    fiscal_year varchar(4) COLLATE DATABASE_DEFAULT,
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
SELECT F.fiscal_year, 1, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจ HbA1c', N'>= 70%', '>=', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #hba1c_check GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 2 Type 2 HbA1c < 7
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 2, N'อัตราผู้ป่วยเบาหวานชนิดที่ 2 ที่มีระดับ HbA1c < 7%', N'> 40%', '>', 40,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_type2 GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT T.fiscal_year, COUNT(DISTINCT T.HN) numerator
    FROM #dm_type2 T
    INNER JOIN #hba1c_latest H ON T.fiscal_year COLLATE DATABASE_DEFAULT = H.fiscal_year COLLATE DATABASE_DEFAULT AND T.HN COLLATE DATABASE_DEFAULT = H.HN COLLATE DATABASE_DEFAULT
    WHERE H.hba1c_value < 7
    GROUP BY T.fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 3 Type 1 HbA1c < 7
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 3, N'อัตราผู้ป่วยเบาหวานชนิดที่ 1 ที่มีระดับ HbA1c < 7%', N'> 40%', '>', 40,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_type1 GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT T.fiscal_year, COUNT(DISTINCT T.HN) numerator
    FROM #dm_type1 T
    INNER JOIN #hba1c_latest H ON T.fiscal_year COLLATE DATABASE_DEFAULT = H.fiscal_year COLLATE DATABASE_DEFAULT AND T.HN COLLATE DATABASE_DEFAULT = H.HN COLLATE DATABASE_DEFAULT
    WHERE H.hba1c_value < 7
    GROUP BY T.fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 4 Acute DM admit
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 4, N'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลันจาก DM', N'< 4%', '<', 4,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #ipd_acute GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 5 Hypoglycemia admit
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 5, N'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลัน Hypoglycemia', N'< 4%', '<', 4,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #ipd_hypo GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 6 Hyperglycemia / DKA admit
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 6, N'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลัน Hyperglycemia, DKA', N'< 4%', '<', 4,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #ipd_hyper GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 7 Lipid profile
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 7, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจ Lipid profile', N'> 70%', '>', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #lipid_check GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 8 LDL < 100
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 8, N'อัตราผู้ป่วย DM ที่มีระดับ LDL < 100 mg/dL', N'> 60%', '>', 60,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT fiscal_year, COUNT(DISTINCT HN) numerator
    FROM #ldl_latest
    WHERE ldl_value < 100
    GROUP BY fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 9 BP <= 130/80
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 9, N'อัตราของระดับความดันโลหิตในผู้ป่วย DM <= 130/80 mmHg', N'>= 60%', '>=', 60,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT fiscal_year, COUNT(DISTINCT HN) numerator
    FROM #bp_latest
    WHERE BPHIGH <= 130 AND BPLOW <= 80
    GROUP BY fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 10 Aspirin age >=40
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 10, N'อัตราผู้ป่วย DM อายุ 40 ปีขึ้นไปที่ได้รับยา Aspirin', N'> 70%', '>', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_age40 GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #aspirin_patient GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 11 Microalbuminuria check
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 11, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจ Microalbuminuria ประจำปี', N'> 80%', '>', 80,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #micro_check GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 12 Microalbuminuria positive with ACEI/ARB
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 12, N'อัตราผู้ป่วย DM มี Microalbuminuria ที่ได้รักษาด้วยยา ACEI หรือ ARB', N'>= 60%', '>=', 60,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #micro_positive GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT M.fiscal_year, COUNT(DISTINCT M.HN) numerator
    FROM #micro_positive M
    INNER JOIN #acei_arb A ON M.fiscal_year COLLATE DATABASE_DEFAULT = A.fiscal_year COLLATE DATABASE_DEFAULT AND M.HN COLLATE DATABASE_DEFAULT = A.HN COLLATE DATABASE_DEFAULT
    GROUP BY M.fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 13 Eye screen
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 13, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจจอประสาทตาประจำปี', N'> 70%', '>', 70,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT E.fiscal_year, COUNT(DISTINCT E.HN) numerator
    FROM #eye_screen E
    INNER JOIN #dm_patient D ON E.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT AND E.HN COLLATE DATABASE_DEFAULT = D.HN COLLATE DATABASE_DEFAULT
    GROUP BY E.fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 14 Dental screen
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 14, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจสุขภาพช่องปากประจำปี', N'> 40%', '>', 40,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT E.fiscal_year, COUNT(DISTINCT E.HN) numerator
    FROM #dental_screen E
    INNER JOIN #dm_patient D ON E.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT AND E.HN COLLATE DATABASE_DEFAULT = D.HN COLLATE DATABASE_DEFAULT
    GROUP BY E.fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 15 Foot screen
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 15, N'อัตราผู้ป่วย DM ที่ได้รับการตรวจเท้าอย่างละเอียดประจำปี', N'> 80%', '>', 80,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (
    SELECT E.fiscal_year, COUNT(DISTINCT E.HN) numerator
    FROM #foot_screen E
    INNER JOIN #dm_patient D ON E.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT AND E.HN COLLATE DATABASE_DEFAULT = D.HN COLLATE DATABASE_DEFAULT
    GROUP BY E.fiscal_year
) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 16 Diabetic retinopathy
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 16, N'อัตราผู้ป่วยเบาหวานที่มี Diabetic retinopathy', N'< 15%', '<', 15,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #dr_patient GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 17 Diabetic nephropathy
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 17, N'อัตราผู้ป่วยเบาหวานที่มี Diabetic nephropathy', N'< 30%', '<', 30,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #nephro_patient GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

-- 18 Foot ulcer
INSERT INTO #raw_indicator
SELECT F.fiscal_year, 18, N'อัตราผู้ป่วยเบาหวานที่มีแผลที่เท้า', N'< 5%', '<', 5,
       ISNULL(N.numerator, 0), ISNULL(D.denominator, 0)
FROM #fy F
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) denominator FROM #dm_patient GROUP BY fiscal_year) D ON F.fiscal_year COLLATE DATABASE_DEFAULT = D.fiscal_year COLLATE DATABASE_DEFAULT
LEFT JOIN (SELECT fiscal_year, COUNT(DISTINCT HN) numerator FROM #foot_ulcer_patient GROUP BY fiscal_year) N ON F.fiscal_year COLLATE DATABASE_DEFAULT = N.fiscal_year COLLATE DATABASE_DEFAULT;

------------------------------------------------------------
-- 14) Final output for Svelte CSV
------------------------------------------------------------
SELECT
    N'ปีงบประมาณ' AS period_type,

    fiscal_year AS fiscal_year_be,

    0 AS period_order,

    N'ปีงบประมาณ ' + fiscal_year AS period_label,

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
    indicator_no;

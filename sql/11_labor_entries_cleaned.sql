-- Purpose:
-- Apply documented cleaning rules to labor_entries.csv
-- to produce a reusable cleaned labor view.

-- Grain:
-- One row per unique time_entry_id after exact duplicate removal.
-- The reporting period represented by each entry remains unknown.

-- Cleaning rules:
-- 1. Remove the extra exact duplicate of TE000222, retaining one row.
-- 2. Convert work_date to DATE using standard parsing followed by
--    the validated M/D/YYYY fallback.
--    This converts TE002542's date to 2023-05-19.
-- 3. Preserve regular_hours at four decimal places.
-- 4. Preserve overtime_hours, hourly_rate, and labor_cost at
--    two decimal places.
-- Use DECIMAL(10,4) for regular_hours_clean.
-- Use DECIMAL(10,2) for overtime_hours_clean, hourly_rate_clean,
-- and labor_cost_clean.
-- 5. Fill TE001843's missing hourly rate with 38.96 in cleaned output.
--    Preserve the raw NULL and flag the rate as formula-derived.
-- 6. Standardize 'carpenter ' to 'Carpenter'.
-- 7. Correct project_id from P996 to P003 specifically for TE000408.
--    Preserve the raw project ID and flag the correction.

-- Source preservation:
-- Leave raw source data unchanged.
-- Retain original values alongside corrected or derived values
-- so changes can be traced.

-- Exception handling:
-- Preserve TE001216's 'General Labor' value and flag it as unresolved.
-- Preserve the 152 documented one-cent labor-cost differences.
-- Preserve TE003191's recorded labor cost and flag its unexplained
-- 125.00 difference for clarification.
-- Preserve labor recorded after baseline completion; it is evidence
-- of work beyond the baseline date, not automatically a data error.
-- Do not reclassify regular or overtime hours without a confirmed
-- reporting period and authoritative overtime rule.

-- Reporting treatment:
-- Keep recorded labor_cost separate from calculated validation amounts.
-- Do not add labor costs to the budget-versus-actual report until
-- their overlap with cost transactions has been investigated.
-- Do not interpret each entry as a daily or weekly labor total.

-- Expected results:
-- 18,003 rows after removing one exact duplicate.
-- 18,003 distinct time_entry_id values.


-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Cleaning step 1: Remove exact duplicate rows while preserving all raw columns.
-- Expected: 18,003 total rows and 18,003 unique time_entry_ids.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT time_entry_id) AS unique_time_entry_id_count
FROM deduplicated;

-- PASS: 18,003 rows and 18,003 distinct time_entry_id values.


-- Cleaning step 2: Convert work_date to DATE.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    time_entry_id,
    work_date,
COALESCE(
            TRY_CAST(work_date AS DATE),
            CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
        ) AS work_date_clean
FROM deduplicated;

-- PASS: TE002542 converts from 5/19/2023 to 2023-05-19.
-- Output remains at 18,003 rows.


-- Cleaning step 3: Convert regular_hours to DECIMAL(10, 4).
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    time_entry_id,
    regular_hours,
    TRY_CAST(regular_hours AS DECIMAL(10, 4))
      AS regular_hours_clean
FROM deduplicated;

-- Spot-check passed: TE016347 retains regular_hours of 16.5592.

-- Cleaning step 4: Convert overtime_hours to DECIMAL(10, 2).
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    time_entry_id,
    overtime_hours,
    TRY_CAST(overtime_hours AS DECIMAL(10, 2))
      AS overtime_hours_clean
FROM deduplicated;

-- Spot-check passed: TE000119 retains overtime_hours of 5.03.


-- Cleaning step 5: Convert hourly_rate to DECIMAL(10, 2) and fill the missing
-- rate for TE001843 only with 38.96, preserving the raw field and adding a
-- formula derived flag.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    time_entry_id,
    hourly_rate,
    TRY_CAST(
        CASE
            WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                THEN 38.96
            ELSE hourly_rate
        END AS DECIMAL(10, 2)
    ) AS hourly_rate_clean,
    (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
      AS hourly_rate_derived_flag
FROM deduplicated;

-- Spot-check passed: TE001843 retains raw NULL, receives cleaned
-- hourly rate 38.96, and has hourly_rate_derived_flag = TRUE.
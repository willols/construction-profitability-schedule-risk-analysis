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


-- Cleaning step 6: Convert labor_cost to DECIMAL(10, 2).
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    time_entry_id,
    labor_cost,
    TRY_CAST(labor_cost AS DECIMAL(10, 2))
      AS labor_cost_clean
FROM deduplicated;

-- Spot-check passed: TE004869 retains labor_cost of 1653 after conversion.


-- Cleaning step 7: Preserve raw trade and add trade_clean.
-- Standardize carpenter variants to Carpenter and trim trade values.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    time_entry_id,
    trade AS raw_trade,
    CASE
        WHEN LOWER(TRIM(trade)) = 'carpenter'
            THEN 'Carpenter'
        ELSE TRIM(trade)
    END AS trade_clean
FROM deduplicated;

-- Spot-check passed: TE000917 converts 'carpenter ' to 'Carpenter'.


-- Cleaning step 8: Preserve raw project_id and add project_id_clean.
-- Assign TE000408 to P003 and flag it.
-- Keep all other project IDs unchanged.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    *,
    CASE
        WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
            THEN 'P003'
            ELSE project_id
        END AS project_id_clean,
    (time_entry_id = 'TE000408' AND project_id = 'P996') AS project_id_corrected_flag
FROM deduplicated;

-- Spot-check passed: TE000408 retains raw P996, receives cleaned P003,
-- and has project_id_corrected_flag = TRUE.


-- Cleaning step 9: Preserve TE001216's recorded trade of 'General Labor'.
-- Flag its trade classification as unresolved.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    *,
    (time_entry_id = 'TE001216' AND trade = 'General Labor')
      AS trade_unresolved_flag
FROM deduplicated;

-- Spot-check passed: TE001216 retains 'General Labor'
-- and has trade_unresolved_flag = TRUE.


-- Cleaning step 10: Preserve TE003191's recorded labor cost and flag its
-- unexplained $125 difference.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    *,
    (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
FROM deduplicated;

-- Spot-check passed: TE003191 retains labor_cost of 1530.88
-- and has labor_cost_unresolved_flag = TRUE.


-- Cleaning step 11: Combine transformations and exception flags.
-- Deduplicate the source rows, then apply cleaning rules.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    *,
    CASE
        WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
            THEN 'P003'
            ELSE project_id
        END AS project_id_clean,
    COALESCE(
            TRY_CAST(work_date AS DATE),
            CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
        ) AS work_date_clean,
    CASE
        WHEN LOWER(TRIM(trade)) = 'carpenter'
            THEN 'Carpenter'
        ELSE TRIM(trade)
    END AS trade_clean,
    TRY_CAST(regular_hours AS DECIMAL(10, 4))
      AS regular_hours_clean,
    TRY_CAST(overtime_hours AS DECIMAL(10, 2))
      AS overtime_hours_clean,
    TRY_CAST(
        CASE
            WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                THEN 38.96
            ELSE hourly_rate
        END AS DECIMAL(10, 2)
    ) AS hourly_rate_clean,
    TRY_CAST(labor_cost AS DECIMAL(10, 2))
      AS labor_cost_clean,
    (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
      AS hourly_rate_derived_flag,
    (time_entry_id = 'TE000408' AND project_id = 'P996')
      AS project_id_corrected_flag,
    (time_entry_id = 'TE001216' AND trade = 'General Labor')
      AS trade_unresolved_flag,
    (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
FROM deduplicated;


-- Validation 1: Confirm row count and unique time_entry IDs.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT time_entry_id) AS unique_time_entry_id_count
FROM cleaned_labor_entries;

-- PASS: 18,003 rows and 18,003 distinct time_entry_id values.


-- Validation 2: Check for failed work_date conversions.
-- Return rows where raw work_date is present but work_date_clean is NULL.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_labor_entries
WHERE work_date IS NOT NULL
  AND work_date_clean IS NULL;

-- PASS: Zero rows returned; no non-NULL source dates failed conversion.


-- Validation 3: Check for failed regular_hours conversions.
-- Return rows where raw regular_hours is present but regular_hours_clean is NULL.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_labor_entries
WHERE regular_hours IS NOT NULL
  AND regular_hours_clean IS NULL;

-- PASS: Zero rows returned; no non-NULL regular_hours values failed conversion.


-- Validation 4: Check for failed overtime_hours conversions.
-- Return rows where raw overtime_hours is present but overtime_hours_clean is NULL.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_labor_entries
WHERE overtime_hours IS NOT NULL
  AND overtime_hours_clean IS NULL;

-- PASS: Zero rows returned; no non-NULL overtime_hours values failed conversion.


-- Validation 5: Check for failed hourly_rate conversions.
-- Return rows where raw hourly_rate is present but hourly_rate_clean is NULL.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_labor_entries
WHERE hourly_rate IS NOT NULL
  AND hourly_rate_clean IS NULL;

-- PASS: Zero rows returned; no non-NULL hourly_rate values failed conversion.


-- Validation 6: Check for failed labor_cost conversions.
-- Return rows where raw labor_cost is present but labor_cost_clean is NULL.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_labor_entries
WHERE labor_cost IS NOT NULL
  AND labor_cost_clean IS NULL;

-- PASS: Zero rows returned; no non-NULL labor_cost values failed conversion.


-- Validation 7: Verify TE001843's derived hourly_rate.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    time_entry_id,
    hourly_rate,
    hourly_rate_clean,
    hourly_rate_derived_flag
FROM cleaned_labor_entries
WHERE time_entry_id = 'TE001843';

-- PASS: TE001843 retains raw NULL, receives hourly_rate_clean of 38.96,
-- and has hourly_rate_derived_flag = TRUE.


-- Validation 8: Verify TE000408's project_id correction and correction flag.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    time_entry_id,
    project_id,
    project_id_clean,
    project_id_corrected_flag
FROM cleaned_labor_entries
WHERE time_entry_id = 'TE000408';

-- PASS: TE000408 retains raw P996, receives project_id_clean of P003,
-- and has project_id_corrected_flag = TRUE.


-- Validation 9: Validate trade_clean mapping.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    trade,
    trade_clean,
    COUNT(*) AS row_total
FROM cleaned_labor_entries
GROUP BY
    trade,
    trade_clean
ORDER BY row_total;

-- PASS: The single 'carpenter ' entry maps to 'Carpenter'.
-- All other trade values remain unchanged, including 'General Labor'.


-- Validation 10: Validate the trade_unresolved_flag for TE001216.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_labor_entries
WHERE time_entry_id = 'TE001216';

-- PASS: TE001216 retains 'General Labor' in trade and trade_clean,
-- and has trade_unresolved_flag = TRUE.


-- Validation 11: Verify TE003191 preserves its recorded labor cost
-- and is flagged as unresolved.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    time_entry_id,
    labor_cost,
    labor_cost_clean,
    labor_cost_unresolved_flag
FROM cleaned_labor_entries
WHERE time_entry_id = 'TE003191';

-- PASS: TE003191 retains 1530.88 in both cost columns.


-- Validation 12: Verify that all four flags mark only the intended labor entries.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    time_entry_id,
    hourly_rate_derived_flag,
    project_id_corrected_flag,
    trade_unresolved_flag,
    labor_cost_unresolved_flag
FROM cleaned_labor_entries
WHERE hourly_rate_derived_flag = TRUE
  OR project_id_corrected_flag = TRUE
  OR trade_unresolved_flag = TRUE
  OR labor_cost_unresolved_flag = TRUE;

-- PASS: Only the four expected entries are flagged, each with its intended flag TRUE.


-- Validation 13: Check that non-NULL numeric values are preserved
-- after conversion to their intended DECIMAL types.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    time_entry_id,
    regular_hours,
    regular_hours_clean,
    overtime_hours,
    overtime_hours_clean,
    hourly_rate,
    hourly_rate_clean,
    labor_cost,
    labor_cost_clean
FROM cleaned_labor_entries
WHERE regular_hours <> regular_hours_clean
    OR overtime_hours <> overtime_hours_clean
    OR hourly_rate <> hourly_rate_clean
    OR labor_cost <> labor_cost_clean;

-- PASS: Zero rows returned; no numeric differences detected
-- across the four non-NULL raw/cleaned pairs.


-- Validation 14: Verify that total cleaned labor cost matches
-- total recorded labor cost in the deduplicated source.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    (SELECT SUM(labor_cost)
     FROM deduplicated) AS labor_cost_total,

    (SELECT SUM(labor_cost_clean)
     FROM cleaned_labor_entries) AS labor_cost_clean_total;

-- PASS: Deduplicated and cleaned labor-cost totals reconcile
-- to the cent at 30,917,634.47.
-- The raw DOUBLE sum contains a negligible floating-point artifact.


-- Validation 15: Verify that cleaned columns and flags
-- have their intended data types.
DESCRIBE
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT *
FROM cleaned_labor_entries;

-- PASS: Cleaned columns and flags have their intended types.
-- Regular hours use DECIMAL(10,4) to preserve source precision;
-- overtime hours, hourly rate, and labor cost use DECIMAL(10,2).


-- Validation 16: Identify labor entries whose project_id_clean
-- has no matching project_id in construction.cleaned_projects.
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT
    l.time_entry_id,
    l.project_id_clean,
    p.project_id
FROM cleaned_labor_entries AS l
LEFT JOIN construction.cleaned_projects AS p
    ON l.project_id_clean = p.project_id
WHERE p.project_id IS NULL;

-- PASS: Zero unmatched labor entries; all cleaned project IDs
-- match construction.cleaned_projects.


-- Create construction.cleaned_labor_entries as a reusable view
-- of the validated labor-cleaning logic.
CREATE OR REPLACE VIEW construction.cleaned_labor_entries AS
WITH deduplicated AS (
SELECT DISTINCT *
FROM read_csv_auto('data/raw/labor_entries.csv')
),

cleaned_labor_entries AS (
    SELECT
        *,
        CASE
            WHEN time_entry_id = 'TE000408' AND project_id = 'P996'
                THEN 'P003'
                ELSE project_id
            END AS project_id_clean,
        COALESCE(
                TRY_CAST(work_date AS DATE),
                CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
            ) AS work_date_clean,
        CASE
            WHEN LOWER(TRIM(trade)) = 'carpenter'
                THEN 'Carpenter'
            ELSE TRIM(trade)
        END AS trade_clean,
        TRY_CAST(regular_hours AS DECIMAL(10, 4))
        AS regular_hours_clean,
        TRY_CAST(overtime_hours AS DECIMAL(10, 2))
        AS overtime_hours_clean,
        TRY_CAST(
            CASE
                WHEN time_entry_id = 'TE001843' AND hourly_rate IS NULL
                    THEN 38.96
                ELSE hourly_rate
            END AS DECIMAL(10, 2)
        ) AS hourly_rate_clean,
        TRY_CAST(labor_cost AS DECIMAL(10, 2))
        AS labor_cost_clean,
        (time_entry_id = 'TE001843' AND hourly_rate IS NULL)
        AS hourly_rate_derived_flag,
        (time_entry_id = 'TE000408' AND project_id = 'P996')
        AS project_id_corrected_flag,
        (time_entry_id = 'TE001216' AND trade = 'General Labor')
        AS trade_unresolved_flag,
        (time_entry_id = 'TE003191') AS labor_cost_unresolved_flag
    FROM deduplicated
)

SELECT *
FROM cleaned_labor_entries;


-- View validation 1: Check total rows and unique time entry IDs.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT time_entry_id) AS unique_time_entry_id_count
FROM construction.cleaned_labor_entries;

-- PASS: Saved view returns 18,003 rows and 18,003 unique time entry IDs.


-- View validation 2: Verify the saved view's cleaned labor-cost total.
SELECT
    SUM(labor_cost_clean) AS labor_cost_clean_total
FROM construction.cleaned_labor_entries;

-- PASS: Saved view labor_cost total matches the validated total of 30,917,634.47.


-- View validation 3: Verify that all four flags mark only the intended labor entries.
SELECT
    time_entry_id,
    hourly_rate_derived_flag,
    project_id_corrected_flag,
    trade_unresolved_flag,
    labor_cost_unresolved_flag
FROM construction.cleaned_labor_entries
WHERE hourly_rate_derived_flag = TRUE
  OR project_id_corrected_flag = TRUE
  OR trade_unresolved_flag = TRUE
  OR labor_cost_unresolved_flag = TRUE;

-- PASS: Saved view returns only the four expected flagged entries,
-- each with its intended flag TRUE.
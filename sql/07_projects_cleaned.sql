-- Purpose:
-- Apply the documented cleaning rules established during projects.csv
-- profiling to produce a reusable cleaned projects dataset.
--
-- Grain:
-- One row per unique project_id.
--
-- Cleaning rules:
-- 1. Remove one occurrence of the exact P042 duplicate, retaining one row.
-- 2. Preserve the raw project_status value. Trim whitespace, normalize
--    case, and apply explicit mappings to produce the standardized values:
--    active, completed, and on_hold.
-- 3. Remove currency symbols and thousands separators from
--    original_contract_value, then safely cast to DECIMAL(10, 2).
--    Confirm that P066's cleaned value is 672000.00.
-- 4. Convert project date fields to DATE. Preserve P013's raw baseline
--    completion date and set its unresolved cleaned value to NULL,
--    excluding it from calculations requiring a confirmed baseline date.
-- 5. Preserve P052's missing project_type as NULL, representing unknown,
--    unless authoritative evidence becomes available.
--
-- Expected result:
-- 96 rows and 96 distinct project_id values after removing
-- one occurrence of the exact P042 duplicate.
-- Documented exceptions remain identifiable in the cleaned output.


-- Cleaning step 1: Remove exact duplicate rows.
-- Use DISTINCT across all columns to retain one copy of each unique row.
SELECT DISTINCT *
FROM read_csv_auto('data/raw/projects.csv');


-- Cleaning step 2: Standardize project_status.
-- Normalize case and surrounding whitespace, then map
-- 'complete' to 'completed' and 'on hold' to 'on_hold'.
SELECT
    project_status,
    CASE
        WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
        WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
        ELSE LOWER(TRIM(project_status))
    END AS project_status_clean
FROM read_csv_auto('data/raw/projects.csv');


-- Cleaning step 3: Normalize and convert original_contract_value.
-- Remove currency symbol and thousand separators, then cast to decimal(10, 2)
SELECT
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS original_contract_value_clean
FROM read_csv_auto('data/raw/projects.csv');


-- Cleaning step 4: Safely convert baseline_completion_date to DATE.
-- Preserve the raw value for traceability. P013's ambiguous date
-- '8/10/2023' remains NULL in the cleaned column because its
-- month/day order could not be confirmed.
SELECT
    project_id,
    baseline_completion_date,
    TRY_CAST(baseline_completion_date AS DATE) AS baseline_completion_date_clean
FROM read_csv_auto('data/raw/projects.csv');


-- Cleaning step 5: Preserve missing project_type.
-- Retain P052's existing NULL because its project type is unknown.
-- No transformation is required.


-- Validation 1: Validate total rows and distinct project_ids after
-- cleaning rules are applied
WITH cleaned_projects AS (
SELECT DISTINCT
    *,
    CASE
        WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
        WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
        ELSE LOWER(TRIM(project_status))
    END AS project_status_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS original_contract_value_clean,
    TRY_CAST(baseline_completion_date AS DATE)
      AS baseline_completion_date_clean
FROM read_csv_auto('data/raw/projects.csv')
ORDER BY project_id
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT project_id) AS project_id_count
FROM cleaned_projects;

-- Results: 96 rows and 96 distinct project_id values.
-- Pass: Expected row count and one row per project confirmed.


-- Validation 2: Check for failed contract-value conversions.
-- Identify populated raw values that became NULL after cleaning.
-- Expected result: Zero rows.
WITH cleaned_projects AS (
SELECT DISTINCT
    *,
    CASE
        WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
        WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
        ELSE LOWER(TRIM(project_status))
    END AS project_status_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS original_contract_value_clean,
    TRY_CAST(baseline_completion_date AS DATE)
      AS baseline_completion_date_clean
FROM read_csv_auto('data/raw/projects.csv')
ORDER BY project_id
)

SELECT
    *
FROM cleaned_projects
WHERE original_contract_value IS NOT NULL
  AND original_contract_value_clean IS NULL;

-- Results: Zero rows.
-- Pass: No failed conversions for populated original_contract_values.


-- Validation 3: Check for NULL baseline_completion_date conversions.
-- Identify populated raw values that became NULL after cleaning.
-- Expected: One row, P013, with ambiguous raw date '8/10/2023'
-- and a NULL cleaned baseline completion date.
WITH cleaned_projects AS (
SELECT DISTINCT
    *,
    CASE
        WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
        WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
        ELSE LOWER(TRIM(project_status))
    END AS project_status_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS original_contract_value_clean,
    TRY_CAST(baseline_completion_date AS DATE)
      AS baseline_completion_date_clean
FROM read_csv_auto('data/raw/projects.csv')
ORDER BY project_id
)

SELECT
    project_id,
    baseline_completion_date,
    baseline_completion_date_clean
FROM cleaned_projects
WHERE baseline_completion_date IS NOT NULL
  AND baseline_completion_date_clean IS NULL;

-- Result: Only P013 returned, with raw date '8/10/2023'
-- and a NULL cleaned baseline completion date.
-- PASS: No unexpected baseline-date conversion failures.


-- Validation 4: Check cleaned project_status values and their counts.
-- Expected: Only active, completed, and on_hold with total equal to 96.
WITH cleaned_projects AS (
SELECT DISTINCT
    *,
    CASE
        WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
        WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
        ELSE LOWER(TRIM(project_status))
    END AS project_status_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS original_contract_value_clean,
    TRY_CAST(baseline_completion_date AS DATE)
      AS baseline_completion_date_clean
FROM read_csv_auto('data/raw/projects.csv')
ORDER BY project_id
)

SELECT
    project_status_clean,
    COUNT(*) AS frequency_count
FROM cleaned_projects
GROUP BY project_status_clean
ORDER BY frequency_count ASC;

-- Results: Three status values: on_hold (3), active (18),
-- and completed (75), totaling 96 rows.
-- PASS: Only expected status values appear; counts match the cleaned row count.


-- Validation 5: Check output data types after cleaning.
-- Expected: project_status_clean: VARCHAR,
-- original_contract_value_clean: DECIMAL(10,2),
-- baseline_completion_date_clean: DATE.
DESCRIBE
WITH cleaned_projects AS (
    SELECT DISTINCT
        *,
        CASE
            WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
            WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
            ELSE LOWER(TRIM(project_status))
        END AS project_status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(original_contract_value, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS original_contract_value_clean,
        TRY_CAST(baseline_completion_date AS DATE)
            AS baseline_completion_date_clean
    FROM read_csv_auto('data/raw/projects.csv')
)
SELECT *
FROM cleaned_projects;

-- Results: Cleaned status is VARCHAR; cleaned contract value is
-- DECIMAL(10,2); cleaned baseline completion date is DATE.
-- baseline_start_date and actual_completion_date are also DATE.
-- PASS: All checked columns have the expected data types.


-- Validation 6: Compare cleaned and deduplicated-source contract totals,
-- using P066's verified 672000.00 and direct casts for other source values.
-- Expected difference: 0.00.
WITH deduplicated_projects AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/projects.csv')
),

contract_totals AS (
    SELECT
        SUM(
            TRY_CAST(
                REPLACE(REPLACE(original_contract_value, '$', ''), ',', '')
                AS DECIMAL(10,2)
            )
        ) AS cleaned_total,

        SUM(
            CASE
                WHEN project_id = 'P066'
                    THEN CAST(672000.00 AS DECIMAL(10,2))
                ELSE CAST(original_contract_value AS DECIMAL(10,2))
            END
        ) AS reference_total
    FROM deduplicated_projects
)

SELECT
    cleaned_total,
    reference_total,
    cleaned_total - reference_total AS difference
FROM contract_totals;

-- Result: Both totals = 141761000; difference = 0.00.
-- PASS: Cleaned contract total matches the source reference.


-- Validation 7: Validate that P052's project_type remained nulled in cleaned output.
-- Expected: P052 project_type is NULL
WITH cleaned_projects AS (
    SELECT DISTINCT
        *,
        CASE
            WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
            WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
            ELSE LOWER(TRIM(project_status))
        END AS project_status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(original_contract_value, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS original_contract_value_clean,
        TRY_CAST(baseline_completion_date AS DATE)
            AS baseline_completion_date_clean
    FROM read_csv_auto('data/raw/projects.csv')
)
SELECT project_id, project_type
FROM cleaned_projects
WHERE project_id = 'P052';

-- Result: One row for P052; project_type is NULL.
-- PASS: Missing project type preserved.


-- Flag missing project types and unresolved baseline completion dates.
-- Expected: P013 = FALSE/TRUE; P052 = TRUE/FALSE; no other flagged projects.
WITH flagged_projects AS (
    SELECT DISTINCT
        project_id,
        project_type IS NULL AS project_type_missing_flag,
        (
            baseline_completion_date IS NOT NULL
            AND TRY_CAST(baseline_completion_date AS DATE) IS NULL
        ) AS baseline_completion_date_unresolved_flag
    FROM read_csv_auto('data/raw/projects.csv')
)
SELECT *
FROM flagged_projects
WHERE project_type_missing_flag
   OR baseline_completion_date_unresolved_flag
ORDER BY project_id;

-- PASS: Only P013 has an unresolved baseline date;
-- only P052 has a missing project type.


-- Open and select the persistent project database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Save the cleaned projects view with raw columns and exception flags.
CREATE OR REPLACE VIEW construction.cleaned_projects AS
SELECT DISTINCT
    *,
    CASE
        WHEN LOWER(TRIM(project_status)) = 'complete' THEN 'completed'
        WHEN LOWER(TRIM(project_status)) = 'on hold' THEN 'on_hold'
        ELSE LOWER(TRIM(project_status))
    END AS project_status_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',', ''
        ) AS DECIMAL(10, 2)
    ) AS original_contract_value_clean,
    TRY_CAST(baseline_completion_date AS DATE)
        AS baseline_completion_date_clean,
    project_type IS NULL AS project_type_missing_flag,
    (
        baseline_completion_date IS NOT NULL
        AND TRY_CAST(baseline_completion_date AS DATE) IS NULL
    ) AS baseline_completion_date_unresolved_flag
FROM read_csv_auto('data/raw/projects.csv');


-- Verify the saved view's counts, contract total, and exception flags.
-- Expected: 96 rows, 96 unique projects, total = 141761000.00,
-- one missing project type, and one unresolved baseline completion date.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT project_id) AS unique_projects,
    SUM(original_contract_value_clean) AS total_contract_value,
    COUNT(*) FILTER (
        WHERE project_type_missing_flag
    ) AS missing_project_types,
    COUNT(*) FILTER (
        WHERE baseline_completion_date_unresolved_flag
    ) AS unresolved_baseline_dates
FROM construction.cleaned_projects;

-- PASS: 96 unique projects, contract total = 141761000.00,
-- one missing project type, and one unresolved baseline date.

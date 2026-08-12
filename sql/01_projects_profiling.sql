-- Projects Data Profiling
-- Source: data/raw/projects.csv
-- Purpose:
-- - Profile the raw projects dataset before cleaning and transformation.
-- - Identify schema, completeness, uniqueness, categorical, date, numeric,
--   and relationship issues that could affect the analysis.
-- Notes:
-- - Preserve the original investigation numbering from the combined profiling file.
-- - Preserve raw source values; document cleaning decisions separately.
-- - Reporting cutoff: 2026-06-30.


-- Investigation 1: Inspect the column names and data types DuckDB infers
-- for the raw projects file.
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/projects.csv');

-- Findings:
-- - baseline_completion_date was inferred as VARCHAR rather than DATE.
-- - original_contract_value was inferred as VARCHAR rather than a numeric type.


-- Investigation 1A: Preview sample values for an initial visual inspection.
SELECT *
FROM read_csv_auto('data/raw/projects.csv')
LIMIT 10;

-- Findings:
-- - The sample appears consistent with one row per project, but it does not
--   verify that project_id is unique across the complete file.
-- - project_status contains inconsistent categorical values, specifically
--   'completed' and 'Complete'.
-- - The sample does not explain why baseline_completion_date and
--   original_contract_value were inferred as VARCHAR; both require further
--   investigation across the complete file.


-- Investigation 2: Count total rows, distinct project IDs, and rows with
-- missing project IDs to test the expected one-row-per-project grain.
SELECT
    COUNT(*) row_count,
    COUNT(DISTINCT project_id) AS distinct_project_id,
    SUM(CASE WHEN project_id IS NULL THEN 1 ELSE 0
        END) AS missing_project_ids
FROM read_csv_auto('data/raw/projects.csv');

-- Findings:
-- - The projects file contains 97 rows, 96 distinct project IDs, and no
--   missing project IDs.
-- - One project ID appears more than once, so the expected one-row-per-project
--   grain has not yet been confirmed.
-- - The duplicated project ID and its associated records require further
--   investigation.


-- Investigation 2A: Identify project IDs that appear more than once so their
-- associated records can be inspected and the expected one-row-per-project
-- grain can be evaluated.
SELECT
    project_id,
    COUNT(*) AS occurrence_count
FROM read_csv_auto('data/raw/projects.csv')
GROUP BY project_id
HAVING COUNT(*) > 1;

-- Findings:
-- - project_id P042 appears in two rows.
-- - This result does not determine whether the records are exact duplicates
--   or contain conflicting values.
-- - Inspect all columns for both records before deciding how to handle the
--   duplicated project ID.


-- Investigation 2B: Identify whether the complete records for project_id P042 are identical or conflicting.
SELECT *
FROM read_csv_auto('data/raw/projects.csv')
WHERE project_id = 'P042';

-- Findings:
-- - Both P042 records contain identical values across all 13 columns,
--   confirming that they are exact duplicate records.
-- - If both records are retained, they will overstate the project count and
--   could duplicate P042-related costs, labor, updates, and change orders
--   during joins, inflating project-level metrics.


-- Investigation 3: Count NULL values in each column of projects.csv to assess
-- completeness and distinguish expected status-dependent missingness from
-- critical data-quality problems.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(project_id) AS missing_project_id,
    COUNT(*) - COUNT(project_name) AS missing_project_name,
    COUNT(*) - COUNT(client_name) AS missing_client_name,
    COUNT(*) - COUNT(project_type) AS missing_project_type,
    COUNT(*) - COUNT(project_manager) AS missing_project_manager,
    COUNT(*) - COUNT(location) AS missing_location,
    COUNT(*) - COUNT(project_status) AS missing_project_status,
    COUNT(*) - COUNT(baseline_start_date) AS missing_baseline_start_date,
    COUNT(*) - COUNT(baseline_completion_date) AS missing_baseline_completion_date,
    COUNT(*) - COUNT(actual_start_date) AS missing_actual_start_date,
    COUNT(*) - COUNT(actual_completion_date) AS missing_actual_completion_date,
    COUNT(*) - COUNT(original_contract_value) AS missing_original_contract_value,
    COUNT(*) - COUNT(original_budget) AS missing_original_budget
FROM read_csv_auto('data/raw/projects.csv');

-- Findings:
-- - One row has a missing project_type, which prevents that project from being
--   classified reliably in analyses grouped by project type and requires
--   further investigation.
-- - Twenty-one rows have missing actual_completion_date values. These may be
--   expected for projects that are not complete, but they must be compared
--   with project_status before being classified as legitimate missing values
--   or data-quality issues.
-- - All other tested fields contain no NULL values, indicating strong
--   completeness across the remaining project attributes.


-- Investigation 3A: Inspect the record with the missing project_type to determine
-- whether its other attributes provide reliable evidence for classification
-- without assigning an unsupported value based on inconclusive clues.
SELECT *
FROM read_csv_auto('data/raw/projects.csv')
WHERE project_type IS NULL;

-- Findings:
-- - Project P052 is the only record with a missing project_type.
-- - Its available attributes do not provide reliable evidence for assigning a
--   specific project type, so the missing value should not be inferred.
-- - The raw NULL must remain unchanged. If a non-NULL category is required in
--   a cleaned output, the project can be classified as 'Unknown' and the
--   limitation documented.


-- Investigation 3B: Group rows with missing actual_completion_date values by
-- project_status to determine whether the missing dates are consistent with
-- projects that were not completed by the reporting cutoff.
SELECT
    project_status,
    COUNT(*) AS missing_date_row_count
FROM read_csv_auto('data/raw/projects.csv')
WHERE actual_completion_date IS NULL
GROUP BY project_status;

-- Findings:
-- - All 21 raw rows with missing actual_completion_date values have statuses
--   that appear to represent active or on-hold projects.
-- - No completed-status values appear among these rows, so the missing dates
--   are consistent with projects that were unfinished at the reporting cutoff.
-- - project_status contains inconsistent values, including 'active' versus
--   ' active ' and 'On Hold' versus 'on_hold'. These values should be
--   standardized only in cleaned outputs.


-- Investigation 4: Identify each distinct raw project_status value and its
-- frequency to reveal formatting inconsistencies that require standardization
-- in cleaned output.
SELECT
    project_status,
    '[' || project_status || ']' AS status_display,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/projects.csv')
GROUP BY project_status
ORDER BY project_status;

-- Findings:
-- - Six distinct raw project_status values appear to represent three logical
--   categories: active, completed, and on_hold.
-- - Active variants account for 18 raw rows: 'active' has 17 rows and
--   ' active ' has 1 row.
-- - Completed variants account for 76 raw rows: 'completed' has 75 rows and
--   'Complete' has 1 row.
-- - On-hold variants account for 3 raw rows: 'on_hold' has 2 rows and
--   'On Hold' has 1 row.
-- - LOWER(TRIM(project_status)) alone would not resolve the wording and
--   separator differences. An explicit standardization rule will be required
--   in cleaned outputs while preserving the raw values.


-- Investigation 5A: Determine why baseline_completion_date was
-- inferred as VARCHAR instead of DATE.
SELECT
    project_id,
    baseline_completion_date,
    TRY_CAST(baseline_completion_date AS DATE) AS parsed_baseline_completion_date
FROM read_csv_auto('data/raw/projects.csv')
WHERE baseline_completion_date IS NOT NULL
  AND TRY_CAST(baseline_completion_date AS DATE) IS NULL;

-- Findings:
-- - Project P013 contains the only non-NULL baseline_completion_date value that
--   failed conversion to DATE: '8/10/2023'.
-- - This slash-based format differs from the ISO-style dates used elsewhere
--   and likely caused DuckDB to infer the entire column as VARCHAR.
-- - The value is ambiguous because it could represent August 10 or October 8,
--   2023. It should not be converted until the source date convention is
--   confirmed and documented.


-- Investigation 5B: Identify values preventing original_contract_value
-- from being numeric.
SELECT
    project_id,
    original_contract_value,
    TRY_CAST(original_contract_value AS DECIMAL (18, 2)) AS parsed_original_contract_value
FROM read_csv_auto('data/raw/projects.csv')
WHERE original_contract_value IS NOT NULL
    AND TRY_CAST(original_contract_value AS DECIMAL (18, 2)) IS NULL;

-- Findings:
-- - Project P066 contains the only non-NULL original_contract_value that failed
--   conversion to DECIMAL(18, 2): '$672,000'.
-- - The currency symbol and thousands separator differ from the unformatted
--   numeric values elsewhere and likely caused DuckDB to infer the entire
--   column as VARCHAR.
-- - In cleaned output, the formatting should be removed and the value converted
--   to 672000.00 as DECIMAL(18, 2), while the raw value remains unchanged.


-- Investigation 6: Test logical date ordering within the planned and actual
-- project timelines.
-- - baseline_start_date must be on or before baseline_completion_date.
-- - actual_start_date must be on or before actual_completion_date when an
--   actual completion date exists.
-- - P013 cannot be evaluated in the baseline check until its ambiguous
--   baseline_completion_date is resolved.


-- Investigation 6A: Identify projects whose safely parsed
-- baseline_completion_date occurs before baseline_start_date.
SELECT
    project_id,
    baseline_start_date,
    baseline_completion_date,
    TRY_CAST(baseline_completion_date AS DATE)
        AS parsed_baseline_completion_date
FROM read_csv_auto('data/raw/projects.csv')
WHERE TRY_CAST(baseline_completion_date AS DATE) IS NOT NULL
  AND TRY_CAST(baseline_completion_date AS DATE)
        < CAST(baseline_start_date AS DATE);

-- Findings:
-- - No ordering violations were found among rows with parseable
--   baseline_completion_date values.
-- - P013 remains untested because its ambiguous baseline_completion_date could
--   not be safely parsed.
-- - The check was performed on raw rows and therefore still includes the known
--   P042 duplicate, although no baseline-order violation was found.


-- Investigation 6B: Identify projects whose actual_completion_date
-- occurs before actual_start_date, excluding projects with no
-- actual_completion_date.
SELECT
    project_id,
    actual_completion_date,
    actual_start_date
FROM read_csv_auto('data/raw/projects.csv')
WHERE actual_completion_date IS NOT NULL
    AND actual_completion_date < actual_start_date;

-- Findings:
-- - No projects with a recorded actual_completion_date had an
--   actual_completion_date before actual_start_date.
-- - Projects without an actual_completion_date were excluded because their
--   actual date ordering could not be evaluated.


-- Investigation 7A: Identify the minimum and maximum actual_start_date
-- and actual_completion_date values to detect potentially unreasonable
-- date boundaries that require further investigation.
SELECT
    MIN(actual_start_date) AS minimum_actual_start_date,
    MAX(actual_start_date) AS maximum_actual_start_date,
    MIN(actual_completion_date) AS minimum_actual_completion_date,
    MAX(actual_completion_date) AS maximum_actual_completion_date
FROM read_csv_auto('data/raw/projects.csv');

-- Findings:
-- - actual_start_date ranges from 2023-01-28 to 2026-04-26.
-- - Among non-NULL values, actual_completion_date ranges from 2023-05-19
--   to 2026-03-22.
-- - No actual-date boundary extends beyond the June 30, 2026,
--   reporting cutoff, and no obviously unreasonable boundary was identified.
-- - These aggregate boundaries may come from different projects and should not
--   be interpreted as dates belonging to the same project.


-- Investigation 7B: Identify the minimum and maximum baseline_start_date and
-- safely converted baseline_completion_date values to detect potentially
-- unreasonable date boundaries, excluding completion values that cannot be
-- converted to DATE.
SELECT
    MIN(baseline_start_date) AS minimum_baseline_start_date,
    MAX(baseline_start_date) AS maximum_baseline_start_date,
    MIN(TRY_CAST(baseline_completion_date AS DATE)) AS minimum_baseline_completion_date,
    MAX(TRY_CAST(baseline_completion_date AS DATE)) AS maximum_baseline_completion_date
FROM read_csv_auto('data/raw/projects.csv');

-- Findings:
-- - baseline_start_date ranges from 2023-01-13 to 2026-04-19.
-- - Among safely parsed values, baseline_completion_date ranges from
--   2023-05-09 to 2026-12-18.
-- - The maximum baseline_completion_date extends beyond the June 30, 2026,
--   reporting cutoff, but this is not a violation because baseline dates are
--   planned dates that may reasonably extend beyond the cutoff.
-- - P013's ambiguous baseline_completion_date was excluded from the safely
--   parsed completion-date range because it could not be reliably converted.
-- - No obviously unreasonable boundary was identified among the safely parsed
--   baseline dates.


-- Investigation 8: Numeric anomalies in projects.csv

-- Investigation 8A: Identify the minimum and maximum original_contract_value
-- and original_budget values after safely normalizing and converting contract
-- values to DECIMAL, to detect potentially unreasonable amounts.
SELECT
    MIN(
        TRY_CAST(
            REPLACE(
                REPLACE(original_contract_value, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 2)
        )
    ) AS minimum_original_contract_value,
    MAX(
        TRY_CAST(
            REPLACE(
                REPLACE(original_contract_value, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 2)
        )
    ) AS maximum_original_contract_value,
    MIN(original_budget) AS minimum_original_budget,
    MAX(original_budget) AS maximum_original_budget
FROM read_csv_auto('data/raw/projects.csv');

-- Findings:
-- - After normalization, original_contract_value ranges from 276,000.00
--   to 3,773,000.00.
-- - original_budget ranges from 223,600.00 to 2,917,000.00.
-- - Both minimums are positive, so no zero or negative values were identified
--   among the processed contract values and budgets.
-- - P066's formatted value of $672,000 was successfully normalized and
--   included in the contract-value range.
-- - No obviously unreasonable numeric boundary was identified.


-- Investigation 8B: Identify projects whose original_budget exceeds the
-- safely normalized original_contract_value, flagging potential negative
-- planned margins that require further investigation.
SELECT
    project_id,
    TRY_CAST(
        REPLACE(
            REPLACE(original_contract_value, '$', ''),
            ',',
            ''
        ) AS DECIMAL(18, 2)
    ) AS standardized_original_contract_value,
    original_budget
FROM read_csv_auto('data/raw/projects.csv')
WHERE original_budget > standardized_original_contract_value;

-- Findings:
-- - The query returned zero rows.
-- - No project had an original_budget greater than its normalized
--   original_contract_value, so no planned negative margin was identified
--   from the original amounts.
-- - P066's formatted contract value of $672,000 was normalized and included
--   in the comparison.
-- - These results do not establish actual profitability, which will depend on
--   actual costs, change orders, and other financial activity.
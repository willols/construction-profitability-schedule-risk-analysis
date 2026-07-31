-- Construction Project Profitability and Schedule-Risk Analysis
-- File: sql/01_data_profiling.sql
--
-- Purpose:
-- Profile the raw client data to understand its structure, grain, completeness,
-- consistency, and relationships before cleaning and business analysis.
--
-- Source data:
-- - data/raw/projects.csv
-- - data/raw/project_budgets.csv
-- - data/raw/cost_transactions.csv
-- - data/raw/labor_entries.csv
-- - data/raw/project_updates.csv
-- - data/raw/change_orders.csv
--
-- Reporting cutoff: June 30, 2026
--
-- Reporting-cutoff policy:
-- - Actual activity dated on or before June 30, 2026, will be included in
--   cutoff-based analysis.
-- - Actual activity after the cutoff will remain in the raw data but will be
--   excluded from cutoff-based calculations.
-- - Future planned dates will remain because they represent expectations known
--   at the cutoff and are necessary for schedule-risk analysis.
-- - The raw CSVs will be preserved to maintain an auditable source, make the
--   analysis reproducible, and prevent uncertainty about what the client
--   originally provided.
--
-- Data-handling rule:
-- Treat all raw CSV files as immutable source data. Apply any corrections or
-- standardization only in cleaned outputs.
--
-- Profiling scope:
-- Inspect column names, inferred data types, row counts, grain, key uniqueness,
-- duplicates, missing values, categorical consistency, date ranges, numeric
-- anomalies, and relationships between files.


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


-- project_budgets.csv profiling
-- Profiling scope:
-- - Inspect column names, inferred data types, row counts, grain, key uniqueness,
-- duplicates, missing values, categorical consistency, date ranges, numeric
-- anomalies, and relationships between files.
-- Data-handling rule:
-- - Treat all raw CSV files as immutable source data. Apply any corrections or
-- standardization only in cleaned outputs.


-- Investigation 9: Inspect project_budgets.csv schema
-- Purpose:
-- - Confirm the column names and DuckDB-inferred data types before performing
-- calculations or other profiling checks.


DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/project_budgets.csv');

-- Findings:
-- - budget_line_id, project_id, and cost_category were inferred as VARCHAR,
--   which is appropriate at the schema level.
-- - original_budget_amount was inferred as BIGINT, which is reasonable for
--   whole-dollar budget values.
-- - approved_budget_change was unexpectedly inferred as VARCHAR and requires
--   further investigation.
-- - revised_budget_amount was inferred as DOUBLE; inspect the raw values before
--   determining whether type standardization is needed in cleaned data.
-- - All columns are nullable according to DESCRIBE, but this does not confirm
--   that actual NULL values are present.


-- Investigation 10: Confirm row count, grain, and key uniqueness
-- Purpose:
-- - Compare the total row count with candidate-key distinct counts to determine
--   the file's grain and test whether each budget line is uniquely identified.
-- Expected grain:
-- - One row represents one budget line for one project and one cost category.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT budget_line_id) AS unique_budget_line_id,
    COUNT(DISTINCT project_id) AS unique_project_id,
    COUNT(DISTINCT (project_id, cost_category)) AS unique_project_cost_category
FROM read_csv_auto('data/raw/project_budgets.csv');

-- Findings:
-- - The file contains 674 total rows.
-- - There are 673 distinct budget_line_id values.
-- - There are 97 distinct project_id values.
-- - There are 673 distinct project_id and cost_category combinations.
-- - The expected grain of one budget line per project and cost category remains
--   unconfirmed because both candidate-key counts are one below the row count.
-- - Missing-key and duplicate checks are required to explain the discrepancy.
-- - project_budgets.csv contains 97 distinct project IDs, compared with 96 in
--   projects.csv; this difference requires later relationship testing.


-- Investigation 10A: Check for missing or blank budget_line_id values
-- Purpose:
-- - Determine whether a missing or blank budget_line_id explains why the total
--   row count exceeds the distinct budget_line_id count.
SELECT
    COUNT(*) AS missing_budget_line_id_row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE budget_line_id IS NULL
   OR TRIM(budget_line_id) = '';

-- Findings:
-- - No rows have a NULL or blank budget_line_id.
-- - Missing IDs do not explain the difference between 674 rows and 673 distinct
--   IDs.
-- - This confirms that at least one duplicate budget_line_id exists, but the
--   affected ID has not yet been identified.


-- Investigation 10B: Identify duplicate budget_line_id values
-- Purpose:
-- - Identify any budget_line_id values that appear more than once and count how
--   many rows are associated with each duplicated ID.
SELECT
    budget_line_id,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
GROUP BY budget_line_id
HAVING COUNT(*) > 1;

-- Findings:
-- - budget_line_id BUD-P031-01 appears in two rows.
-- - budget_line_id is not unique in the raw file.
-- - This duplicate explains the discrepancy between 674 total rows and 673
--   distinct budget_line_id values.
-- - It remains unknown whether the two records are exact duplicates or
--   conflicting records.


-- Investigation 10C: Inspect rows for duplicate budget_line_id BUD-P031-01
-- Purpose:
-- - Compare all columns in the two records to determine whether they are exact
--   duplicates or contain conflicting values.
SELECT *
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE budget_line_id = 'BUD-P031-01';

-- Findings:
-- - The two rows containing budget_line_id BUD-P031-01 are exact duplicates;
--   all six column values match.
-- - This duplicate explains the difference between 674 total rows and both 673
--   distinct budget_line_id values and 673 distinct project_id and
--   cost_category combinations.
-- - The raw CSV will remain unchanged. One copy of the duplicated row will be
--   retained in the cleaned output.


-- Investigation 11: Check missing values in project_budgets.csv
-- Purpose:
-- - Identify which columns contain missing values, count how many rows are
--   affected in each column, and check VARCHAR columns for blank or
--   whitespace-only values.
SELECT
    COUNT(*) AS row_count,
    COUNT(*) - COUNT(budget_line_id) AS missing_budget_line_id,
    COUNT(*) - COUNT(project_id) AS missing_project_id,
    COUNT(*) - COUNT(cost_category) AS missing_cost_category,
    COUNT(*) - COUNT(original_budget_amount) AS missing_original_budget_amount,
    COUNT(*) - COUNT(approved_budget_change) AS missing_approved_budget_change,
    COUNT(*) - COUNT(revised_budget_amount) AS missing_revised_budget_amount,
    COUNT(*) FILTER (
        WHERE budget_line_id IS NOT NULL
        AND TRIM(budget_line_id) = ''
        ) AS blank_budget_line_id,
    COUNT(*) FILTER (
        WHERE project_id IS NOT NULL
        AND TRIM(project_id) = ''
        ) AS blank_project_id,
    COUNT(*) FILTER (
        WHERE cost_category IS NOT NULL
        AND TRIM(cost_category) = ''
        ) AS blank_cost_category,
    COUNT(*) FILTER (
        WHERE approved_budget_change IS NOT NULL
        AND TRIM(approved_budget_change) = ''
        ) AS blank_approved_budget_change
FROM read_csv_auto('data/raw/project_budgets.csv');

-- Findings:
-- - No NULL, blank, or whitespace-only values were identified in budget_line_id,
--   project_id, or cost_category.
-- - No NULL, blank, or whitespace-only values were identified in
--   approved_budget_change.
-- - No missing revised_budget_amount values were identified.
-- - Exactly one row has a missing original_budget_amount.
-- - The aggregate result does not identify which record is affected.


-- Investigation 11A: Identify the row with a missing original_budget_amount
-- Purpose:
-- - Identify the affected row and inspect its identifying and monetary fields
--   to determine whether the missing original_budget_amount can be reliably
--   derived from the other budget fields or must remain unresolved.
SELECT *
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE original_budget_amount IS NULL;

-- Findings:
-- - budget_line_id BUD-P057-04 for project P057 contains the only NULL
--   original_budget_amount.
-- - The row has an approved_budget_change of 0 and a revised_budget_amount of
--   31672.
-- - If revised_budget_amount equals original_budget_amount plus
--   approved_budget_change, the implied original_budget_amount is 31672.
-- - This relationship has not yet been validated across the dataset, so the
--   missing value remains unresolved and no imputation decision has been made.


-- Investigation 12: Inspect cost_category values
-- Purpose:
-- - Check whether cost_category values are formatted consistently and identify
--   capitalization, spacing, spelling, or unexpected labels that could split
--   categories and make aggregations inaccurate.
SELECT
    cost_category,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
GROUP BY cost_category
ORDER BY row_count DESC, cost_category;

-- Findings:
-- - The file contains 11 distinct raw cost_category labels.
-- - Seven labels appear to be canonical: Labor, Equipment, Permits & Fees,
--   Other, Subcontractors, Materials, and General Conditions.
-- - Four inconsistent variants were identified, each appearing once:
--   'General conditions' → 'General Conditions'
--   'Materials ' → 'Materials'
--   'labor' → 'Labor'
--   'Sub-Contractors' → 'Subcontractors'
-- - Leaving these variants unchanged would split category-level aggregations
--   and produce inaccurate results.
-- - The four variants should be standardized only in cleaned data; the raw CSV
--   remains unchanged.


-- Investigation 13: Investigate approved_budget_change type inference and numeric parseability
-- Purpose:
-- - Identify the raw values or formatting patterns that caused DuckDB to infer
--   approved_budget_change as VARCHAR.
-- - Determine whether all non-NULL, non-blank values can be safely parsed as numeric.
-- - Use the findings to define required cleaning rules and inform the selection of
--   an appropriate exact numeric type for the cleaned dataset.
SELECT
    approved_budget_change,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE
    approved_budget_change IS NOT NULL
    AND TRY_CAST(approved_budget_change AS DECIMAL(18, 2)) IS NULL
GROUP BY approved_budget_change
ORDER BY
    row_count DESC,
    approved_budget_change;

-- Findings:
-- - $3,485.49 is the only populated value that fails direct numeric parsing,
--   and it appears once.
-- - The currency symbol and thousands separator prevent direct conversion to
--   DECIMAL and explain why DuckDB inferred the column as VARCHAR.
-- - The candidate cleaning rule is to remove both formatting characters before
--   converting the normalized value to a numeric type; this rule still requires
--   validation across the full column.


-- Investigation 13A: Validate approved_budget_change normalization
-- Purpose:
-- - Test whether removing currency symbols and thousands separators from populated
--   approved_budget_change values allows them to be safely converted to DECIMAL.
-- - Identify any values that remain unparseable after normalization; zero returned
--   rows would validate the candidate cleaning rule for the observed column values.
SELECT
SELECT
    approved_budget_change,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE
    approved_budget_change IS NOT NULL
    AND TRY_CAST(
        REPLACE(
            REPLACE(approved_budget_change, '$', ''),
            ',',
            ''
        ) AS DECIMAL(18, 2)
    ) IS NULL
GROUP BY approved_budget_change
ORDER BY row_count DESC, approved_budget_change;

-- Findings:
-- - The query returned zero rows, meaning no populated approved_budget_change
--   values remained unparseable after removing currency symbols and thousands
--   separators.
-- - This validates the candidate normalization rule for all observed populated
--   values before conversion to an exact numeric type.


-- Next steps:
-- - Begin Investigation 14 by inspecting revised_budget_amount precision and
--   numeric compatibility before selecting a cleaned monetary type.
-- - Validate the relationship among original_budget_amount, normalized
--   approved_budget_change, and revised_budget_amount.
-- - Keep BUD-P057-04's missing original_budget_amount unresolved until the
--   monetary relationship has been validated.
-- - In cleaned data, retain only one BUD-P031-01 row and standardize the four
--   inconsistent cost_category variants.
-- - After completing project_budgets.csv profiling, continue with the remaining
--   four raw CSV files.
-- - Preserve all raw CSV files as immutable source data.

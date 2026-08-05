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


-- Investigation 14A: Inspect revised_budget_amount precision and range
--
-- Purpose:
-- Determine whether revised_budget_amount contains fractional values,
-- missing values, or potentially unreasonable minimum or maximum amounts.
-- Use the results to select an appropriate monetary data type before
-- validating the budget calculation relationship.
SELECT
    COUNT(*) AS row_count,
    MIN(revised_budget_amount) AS minimum_revised_budget_amount,
    MAX(revised_budget_amount) AS maximum_revised_budget_amount,
    COUNT(*) FILTER (
        WHERE revised_budget_amount IS NULL
    ) AS null_count,
    COUNT(*) FILTER (
        WHERE revised_budget_amount <> TRUNC(revised_budget_amount)
    ) AS values_with_fractional_amount
FROM read_csv_auto('data/raw/project_budgets.csv');
-- Findings:
-- - project_budgets.csv contains 674 rows.
-- - revised_budget_amount contains no NULL values.
-- - Values range from 6,957.72 to 886,036.18.
-- - 406 values contain a fractional component, confirming that
--   revised_budget_amount should not be stored as an integer.
-- - A fixed-point DECIMAL type is likely appropriate for cleaned monetary
--   values, but the maximum number of decimal places must still be confirmed
--   before selecting the final precision and scale.


-- Investigation 14B: Inspect decimal precision in revised_budget_amount
--
-- Purpose:
-- - Determine whether any values contain more than two decimal places.
-- - Confirm that the column can be converted to an appropriate DECIMAL type
--   without altering the original monetary values.
SELECT
    revised_budget_amount,
    ROUND(revised_budget_amount, 2) AS rounded_revised_budget_amount
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE revised_budget_amount <> rounded_revised_budget_amount;

-- Findings:
-- - Zero rows were returned, confirming that no revised_budget_amount values
--   changed when rounded to two decimal places.
-- - A scale of 2 can preserve all current values without rounding.
-- - The final DECIMAL precision has not yet been selected.


-- Investigation 15A: Inspect known duplicate and missing-value rows
--
-- Purpose:
-- - Inspect BUD-P031-01 to confirm how the known duplicate behaves in the
--   budget calculation.
-- - Inspect BUD-P057-04 to determine how its missing
--   original_budget_amount affects validation.
-- - Confirm whether these known data-quality issues should be treated as
--   calculation mismatches or handled separately.

SELECT
    budget_line_id,
    original_budget_amount,
    approved_budget_change,
    TRY_CAST(
        REPLACE(
            REPLACE(approved_budget_change, '$', ''),
            ',',
            ''
        ) AS DECIMAL(18, 2)
    ) AS normalized_approved_budget_change,
    revised_budget_amount,
    original_budget_amount
        + normalized_approved_budget_change
        AS calculated_revised_budget_amount
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE budget_line_id IN ('BUD-P057-04', 'BUD-P031-01');

-- Findings:
-- - BUD-P031-01 appears twice with identical monetary values, confirming
--   the previously identified exact duplicate.
-- - Both BUD-P031-01 rows satisfy the expected calculation:
--   original_budget_amount plus approved_budget_change equals
--   revised_budget_amount.
-- - BUD-P057-04 has a NULL original_budget_amount.
-- - Its calculated_revised_budget_amount is therefore also NULL because
--   arithmetic involving NULL produces NULL.
-- - BUD-P057-04 cannot currently be classified as a calculation match or
--   mismatch and must be handled separately during cleaning.


-- Investigation 15B: Identify testable rows with budget calculation mismatches
-- Purpose:
-- - Test whether original_budget_amount plus normalized approved_budget_change
--   equals revised_budget_amount.
-- - Keep zero values because they are valid and testable monetary amounts.
-- - Exclude rows with NULLs in required monetary fields because the expected
--   revised amount cannot be calculated.
-- - Return testable rows where the calculated and recorded revised amounts differ.
WITH normalized_budgets AS (
    SELECT
        budget_line_id,
        CAST(original_budget_amount AS DECIMAL(18, 2))
            AS original_budget_amount,
        approved_budget_change,
        TRY_CAST(
            REPLACE(
                REPLACE(approved_budget_change, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 2)
        ) AS normalized_approved_budget_change,
        CAST(revised_budget_amount AS DECIMAL(18, 2))
            AS revised_budget_amount
    FROM read_csv_auto('data/raw/project_budgets.csv')
),

testable_budgets AS (
    SELECT
        budget_line_id,
        original_budget_amount,
        approved_budget_change,
        normalized_approved_budget_change,
        revised_budget_amount,
        original_budget_amount
            + normalized_approved_budget_change
            AS calculated_revised_budget_amount
    FROM normalized_budgets
    WHERE original_budget_amount IS NOT NULL
      AND normalized_approved_budget_change IS NOT NULL
      AND revised_budget_amount IS NOT NULL
)

SELECT
    budget_line_id,
    original_budget_amount,
    approved_budget_change,
    normalized_approved_budget_change,
    revised_budget_amount,
    calculated_revised_budget_amount,
    revised_budget_amount
        - calculated_revised_budget_amount AS variance_amount
FROM testable_budgets
WHERE revised_budget_amount <> calculated_revised_budget_amount
ORDER BY ABS(variance_amount) DESC, budget_line_id;

-- Findings:
-- - Zero mismatch rows were returned, confirming that all testable rows satisfy
--   original_budget_amount + normalized approved_budget_change
--   = revised_budget_amount.
-- - This result does not validate budget line BUD-P057-04 because its
--   original_budget_amount is NULL, so the row was excluded as untestable.


-- Investigation 15C: Count matching, mismatching, and untestable rows
-- Purpose:
-- - Classify every project_budgets row as matching, mismatching, or untestable.
-- - Matching rows have all required values and satisfy original_budget_amount
--   + normalized approved_budget_change = revised_budget_amount.
-- - Mismatching rows have all required values but do not satisfy the expected
--   budget calculation.
-- - Untestable rows have a missing required value or an approved_budget_change
--   that cannot be normalized to a monetary value.
-- - Confirm that the mutually exclusive category counts sum to all 674 source rows.
WITH normalized_budgets AS (
    SELECT
        CAST(original_budget_amount AS DECIMAL(18, 2))
            AS original_budget_amount,
        TRY_CAST(
            REPLACE(
                REPLACE(approved_budget_change, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 2)
        ) AS normalized_approved_budget_change,
        CAST(revised_budget_amount AS DECIMAL(18, 2))
            AS revised_budget_amount
    FROM read_csv_auto('data/raw/project_budgets.csv')
),

validation_counts AS (
    SELECT
        COUNT(*) FILTER (
            WHERE original_budget_amount IS NOT NULL
              AND normalized_approved_budget_change IS NOT NULL
              AND revised_budget_amount IS NOT NULL
              AND original_budget_amount
                    + normalized_approved_budget_change
                    = revised_budget_amount
        ) AS matching_rows,

        COUNT(*) FILTER (
            WHERE original_budget_amount IS NOT NULL
              AND normalized_approved_budget_change IS NOT NULL
              AND revised_budget_amount IS NOT NULL
              AND original_budget_amount
                    + normalized_approved_budget_change
                    <> revised_budget_amount
        ) AS mismatching_rows,

        COUNT(*) FILTER (
            WHERE original_budget_amount IS NULL
               OR normalized_approved_budget_change IS NULL
               OR revised_budget_amount IS NULL
        ) AS untestable_rows,

        COUNT(*) AS total_rows
    FROM normalized_budgets
)

SELECT
    matching_rows,
    mismatching_rows,
    untestable_rows,
    total_rows,
    matching_rows + mismatching_rows + untestable_rows
        AS classified_rows,
    total_rows
        = matching_rows + mismatching_rows + untestable_rows
        AS counts_reconcile
FROM validation_counts;

-- Findings:
-- - 673 rows were classified as matching.
-- - Zero rows were classified as mismatching.
-- - One row was classified as untestable.
-- - All 674 source rows were classified, and the reconciliation check passed.
-- - This validates the monetary relationship for all testable rows, but it does
--   not automatically justify filling the missing original_budget_amount in
--   BUD-P057-04.


-- Investigation 15D: Assess the missing original budget amount for BUD-P057-04
-- Purpose:
-- - Calculate a candidate original amount using revised_budget_amount
--   minus normalized approved_budget_change.
-- - Treat and document the result as an inferred candidate rather than a
--   confirmed source value.
-- - Preserve the source NULL instead of silently replacing it.
WITH normalized_budget AS (
    SELECT
        budget_line_id,
        project_id,
        cost_category,
        original_budget_amount,
        approved_budget_change AS raw_approved_budget_change,
        TRY_CAST(
            REPLACE(
                REPLACE(approved_budget_change, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 2)
        ) AS normalized_approved_budget_change,
        revised_budget_amount AS raw_revised_budget_amount,
        CAST(revised_budget_amount AS DECIMAL(18, 2))
            AS normalized_revised_budget_amount
    FROM read_csv_auto('data/raw/project_budgets.csv')
    WHERE budget_line_id = 'BUD-P057-04'
)

SELECT
    budget_line_id,
    project_id,
    cost_category,
    original_budget_amount,
    raw_approved_budget_change,
    normalized_approved_budget_change,
    raw_revised_budget_amount,
    normalized_revised_budget_amount,
    normalized_revised_budget_amount
        - normalized_approved_budget_change AS candidate_original_amount
FROM normalized_budget;

-- Findings:
-- - For BUD-P057-04, the normalized revised_budget_amount of 31,672.00
--   minus the normalized approved_budget_change of 0.00 produces an inferred
--   candidate original_budget_amount of 31,672.00.
-- - Preserve the source original_budget_amount as NULL. The candidate may be
--   used for analysis with an inference flag, but it is not an observed value.


-- Investigation 16: Select the final monetary precision
-- Purpose:
-- - Inspect the maximum absolute values of original_budget_amount,
--   normalized approved_budget_change, revised_budget_amount, and the inferred
--   candidate original amount.
-- - Determine the maximum number of digits required before the decimal while
--   preserving the validated scale of 2.
-- - Select a final DECIMAL precision that supports all observed values and
--   provides reasonable headroom for future project budgets.
WITH normalized_budgets AS (
    SELECT
        CAST(original_budget_amount AS DECIMAL(18, 2))
            AS original_budget_amount,
        TRY_CAST(
            REPLACE(
                REPLACE(approved_budget_change, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 2)
        ) AS normalized_approved_budget_change,
        CAST(revised_budget_amount AS DECIMAL(18, 2))
            AS normalized_revised_budget_amount
    FROM read_csv_auto('data/raw/project_budgets.csv')
),

budget_amounts AS (
    SELECT
        original_budget_amount,
        normalized_approved_budget_change,
        normalized_revised_budget_amount,
        CASE
            WHEN original_budget_amount IS NULL
             AND normalized_approved_budget_change IS NOT NULL
             AND normalized_revised_budget_amount IS NOT NULL
            THEN normalized_revised_budget_amount
                 - normalized_approved_budget_change
            ELSE NULL
        END AS candidate_original_amount
    FROM normalized_budgets
)

SELECT
    MAX(ABS(original_budget_amount))
        AS max_abs_original_budget_amount,
    MAX(ABS(normalized_approved_budget_change))
        AS max_abs_approved_budget_change,
    MAX(ABS(normalized_revised_budget_amount))
        AS max_abs_revised_budget_amount,
    MAX(ABS(candidate_original_amount))
        AS max_abs_candidate_original_amount
FROM budget_amounts;

-- Findings:
-- - max_abs_original_budget_amount returned 845,930.00.
-- - max_abs_approved_budget_change returned 104,800.44.
-- - max_abs_revised_budget_amount returned 886,036.18.
-- - max_abs_candidate_original_amount returned 31,672.00.
-- - The observed values require at most six digits before the decimal and
--   the validated scale of two, making DECIMAL(8, 2) the minimum compatible type.
-- - DECIMAL(10, 2) will be used for cleaned project_budgets monetary fields,
--   providing eight integer digits and reasonable future headroom.


-- project_budgets.csv Profiling Conclusion
--
-- Dataset Structure:
-- - The source contains 674 rows and 673 distinct budget_line_id values.
-- - The intended grain is one budget line per project_id and cost_category.
-- - The source contains 673 distinct project_id and cost_category combinations
--   across 97 distinct project_id values.
--
-- Data-Quality Issues:
-- - BUD-P031-01 appears twice as an exact duplicate.
-- - BUD-P057-04 has the only missing original_budget_amount.
-- - Four cost_category values require standardization:
--   "General conditions" to "General Conditions",
--   "Materials " to "Materials",
--   "labor" to "Labor", and
--   "Sub-Contractors" to "Subcontractors".
-- - One approved_budget_change value, "$3,485.49", cannot be converted
--   directly to a numeric type because it contains a currency symbol and
--   thousands separator.
--
-- Monetary Validation:
-- - Removing "$" and "," before applying TRY_CAST successfully converts every
--   populated approved_budget_change value to a monetary value.
-- - revised_budget_amount ranges from 6,957.72 to 886,036.18.
-- - A scale of 2 preserves every observed monetary value without alteration.
-- - The expected relationship is original_budget_amount plus normalized
--   approved_budget_change equals revised_budget_amount.
-- - Of the 674 source rows, 673 are matching, zero are mismatching, and one is
--   untestable. The category counts reconcile to all 674 rows.
-- - BUD-P057-04 is untestable because its original_budget_amount is NULL.
-- - Its inferred candidate original amount is 31,672.00, calculated from a
--   revised amount of 31,672.00 minus an approved change of 0.00. This candidate
--   is not source-confirmed.
--
-- Cleaning Decisions:
-- - Preserve the raw project_budgets.csv file unchanged.
-- - Remove one occurrence of the exact BUD-P031-01 duplicate only in cleaned data.
-- - Standardize the four inconsistent cost_category values to their canonical forms.
-- - Normalize approved_budget_change by removing "$" and "," and then applying
--   TRY_CAST to DECIMAL(10, 2).
-- - Convert all cleaned monetary fields to DECIMAL(10, 2).
-- - Preserve the source NULL for BUD-P057-04. If the inferred candidate is used
--   for analysis, store or expose it separately and flag it as inferred rather
--   than observed.


-- cost_transactions.csv profiling
-- Profiling scope:
-- Inspect column names, inferred data types, row counts, grain, key uniqueness,
-- duplicates, missing values, categorical consistency, date ranges, numeric
-- anomalies, and relationships between files.
-- Data-handling rule:
-- Treat all raw CSV files as immutable source data. Apply any corrections or
-- standardization only in cleaned outputs.


-- Investigation 17: Initial profiling of cost_transactions.csv
-- Purpose:
-- Inspect the inferred schema and sample values, count the rows, and form initial
-- hypotheses about the row-level grain and likely transaction identifier.

-- Inferred schema
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - Eight columns were detected.
-- - transaction_date was inferred as DATE.
-- - The remaining seven columns were inferred as VARCHAR.
-- - amount requires further investigation because DuckDB inferred it as
--   VARCHAR rather than a numeric type.


-- Sample value
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
LIMIT 10;

-- Findings:
-- - transaction_id values are sequential in the sample.
-- - The sample provides tentative support for one row per transaction.
-- - No sampled amount values contain currency symbols or otherwise explain why
--   DuckDB inferred the column as VARCHAR.
-- - Two payment_status values were observed: paid and approved.
-- - The first ten rows are not representative enough to establish file-wide
--   consistency.


-- Row count
SELECT
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - cost_transaction.csv contains 11,204


-- Investigation 17 conclusion:
-- - cost_transactions.csv contains 11,204 rows and eight columns.
-- - transaction_date was inferred as DATE.
-- - transaction_id, project_id, cost_category, vendor_name, description,
--   amount, and payment_status were inferred as VARCHAR.
-- - amount contains numeric-looking sample values but requires further
--   investigation because DuckDB inferred it as VARCHAR.
-- - The expected grain is one row per cost transaction, and transaction_id is
--   the likely unique identifier; both hypotheses require validation.


-- Investigation 18: Validate transaction_id as the unique identifier
-- Purpose:
-- Compare the total row count, non-NULL transaction_id count, and distinct
-- transaction_id count to determine whether every row has a populated,
-- unique transaction identifier.
SELECT
    COUNT(*) AS row_count,
    COUNT(transaction_id) AS non_null_transaction_id,
    COUNT(DISTINCT transaction_id) AS distinct_transaction_id
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - The file contains 11,204 rows and 11,204 non-NULL transaction_id values,
--   indicating that no transaction identifiers are missing.
-- - There are 11,203 distinct transaction_id values.
-- - The difference of one confirms one duplicate occurrence that requires
--   targeted inspection to determine whether the associated rows are identical
--   or conflicting.


-- Investigation 18A: Identify repeated transaction_id values
-- Purpose:
-- Identify transaction_id values that occur more than once and inspect their
-- associated rows to determine whether they are exact duplicates or conflicting
-- records.
SELECT
    transaction_id,
    COUNT(*) AS occurance_count
FROM read_csv_auto('data/raw/cost_transactions.csv')
GROUP BY transaction_id
HAVING COUNT(*) >1;

-- Findings:
-- - transaction_id TX000138 occurs twice.
-- - This explains the one-record difference between 11,204 non-NULL
--   transaction_id values and 11,203 distinct values.
-- - Further investigation is required to determine whether the associated rows
--   are exact duplicates or conflicting transactions.


-- Investigation 18B: Inspect records associated with TX000138
-- Purpose:
-- Inspect and compare all column values for the two records associated with
-- transaction_id TX000138 to determine whether they are exact duplicates or
-- conflicting transactions.
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE transaction_id = 'TX000138';

-- Findings:
-- - The two records associated with transaction_id TX000138 are exact
--   duplicates across all eight columns.
-- - If both records were included in analysis, project P002's Materials costs
--   would be overstated by 14,821.14, causing its profitability to be
--   understated by the same amount.
-- - The raw file will remain unchanged. In the cleaned output, one occurrence
--   will be retained and the duplicate occurrence removed.


-- Investigation 19: Inspect columns for completeness
-- Purpose:
-- Count NULL values in all eight columns and blank or whitespace-only values
-- in the seven VARCHAR columns to determine whether each field is complete.
SELECT
    COUNT(*) AS row_count,

    COUNT(*) FILTER (
        WHERE transaction_id IS NULL
    ) AS null_transaction_id_count,
    COUNT(*) FILTER (
        WHERE TRIM(transaction_id) = ''
    ) AS blank_transaction_id_count,

    COUNT(*) FILTER (
        WHERE project_id IS NULL
    ) AS null_project_id_count,
    COUNT(*) FILTER (
        WHERE TRIM(project_id) = ''
    ) AS blank_project_id_count,

    COUNT(*) FILTER (
        WHERE transaction_date IS NULL
    ) AS null_transaction_date_count,

    COUNT(*) FILTER (
        WHERE cost_category IS NULL
    ) AS null_cost_category_count,
    COUNT(*) FILTER (
        WHERE TRIM(cost_category) = ''
    ) AS blank_cost_category_count,

    COUNT(*) FILTER (
        WHERE vendor_name IS NULL
    ) AS null_vendor_name_count,
    COUNT(*) FILTER (
        WHERE TRIM(vendor_name) = ''
    ) AS blank_vendor_name_count,

    COUNT(*) FILTER (
        WHERE description IS NULL
    ) AS null_description_count,
    COUNT(*) FILTER (
        WHERE TRIM(description) = ''
    ) AS blank_description_count,

    COUNT(*) FILTER (
        WHERE amount IS NULL
    ) AS null_amount_count,
    COUNT(*) FILTER (
        WHERE TRIM(amount) = ''
    ) AS blank_amount_count,

    COUNT(*) FILTER (
        WHERE payment_status IS NULL
    ) AS null_payment_status_count,
    COUNT(*) FILTER (
        WHERE TRIM(payment_status) = ''
    ) AS blank_payment_status_count

FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - cost_transactions.csv contains 11,204 rows.
-- - project_id contains one NULL value and no blank or whitespace-only values.
-- - The remaining seven columns contain no NULL values.
-- - All seven VARCHAR columns contain no blank or whitespace-only values.
-- - The missing project_id requires targeted inspection because the associated
--   transaction cannot currently be assigned to a project, potentially
--   distorting project-level costs and profitability.


-- Investigation 19A: Inspect the transaction with a missing project_id
-- Purpose:
-- - Inspect the affected transaction’s remaining fields for evidence that
--   supports assigning it to a specific project.
-- - If the available evidence does not support a reliable assignment,
--   leave the project_id unresolved rather than inferring a value.
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE project_id IS NULL;

-- Findings:
-- - None of the remaining fields provides reliable evidence connecting
--   transaction TX000316 to a specific project.
-- - The vendor name and description are generic, while the date, category,
--   amount, and payment status do not identify a project.
-- - Preserve project_id as NULL in the cleaned cost_transactions output
--   because the project assignment remains unresolved.


-- Investigation 19B: Evaluate P003 as the probable project assignment
-- Purpose:
-- - Check whether project IDs occur in contiguous transaction_id blocks.
-- - Determine whether TX000316 falls within the block assigned to P003.
-- - Treat the ordering pattern as supporting internal evidence rather than
--   conclusive proof of the project assignment.
SELECT
    transaction_id,
    project_id,
    LAG(project_id) OVER (
        ORDER BY transaction_id
    ) AS previous_project_id
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE project_id IS NOT NULL
QUALIFY project_id IS DISTINCT FROM previous_project_id
ORDER BY transaction_id;

-- Findings:
-- - The dataset contains 97 distinct non-NULL project IDs and 101 project
--   block starts. P007, P014, P047, and P082 appear in multiple blocks.
-- - P003 begins at TX000236, and the next project block begins with P004
--   at TX000360. Therefore, TX000316 falls within P003's transaction range.
-- - The surrounding records also belong to P003, providing strong internal
--   evidence that the missing project_id should be P003.
-- - For this simulated client engagement, the client confirmed that
--   TX000316 belongs to P003.
-- - Assign P003 to TX000316 in the cleaned cost_transactions output while
--   preserving the original NULL in the immutable raw CSV.


-- Investigation 20: Profile amount formatting and numeric parseability
-- Purpose:
-- - Identify the formatting patterns that caused amount to be inferred
--   as VARCHAR rather than a numeric type.
-- - Check for currency symbols and thousands separators.
-- - Validate whether every populated value can be safely normalized and
--   converted to an appropriate monetary type.
SELECT *
    amount,
    TRY_CAST(amount AS DECIMAL(18, 2)) AS direct_parsed_amount
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE direct_parsed_amount IS NULL;

-- Findings:
-- - One populated amount associated with project P015 failed direct
--   conversion to DECIMAL(18, 2).
-- - The raw value is '$46.90'; the raw amount is not NULL, but TRY_CAST()
--   returned NULL because of the currency symbol.
-- - No other amount values failed direct conversion, and no failed values
--   contained thousands separators.
-- - The dollar sign likely caused amount to be inferred as VARCHAR.
-- - The proposed cleaning rule is to remove '$' with REPLACE() before
--   converting amount to a monetary numeric type.
-- - Validate the proposed normalization across all rows before finalizing
--   the cleaning rule and cleaned monetary type.


-- Investigation 20A: Validate amount normalization and numeric parseability
-- Purpose:
-- - Validate that removing the '$' currency symbol with REPLACE() allows
--   every populated amount value to parse successfully as DECIMAL(18, 2).
SELECT
    COUNT(*) AS row_count,
    SUM(
        CASE
            WHEN TRY_CAST(
                REPLACE(
                    REPLACE(amount, '$', ''),
                    ',',
                    ''
                ) AS DECIMAL(18, 2)
            ) IS NULL
            THEN 1
            ELSE 0
        END
    ) AS normalized_parse_failure_count
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - All 11,204 amount values were evaluated after normalization.
-- - The normalized parse failure count was 0, confirming that every value
--   can be converted successfully to DECIMAL(18, 2).
-- - The raw value '$46.90' became parseable after removing the currency symbol.
-- - In the cleaned cost_transactions output, remove '$' and ',' with
--   REPLACE() before converting amount to a monetary numeric type.
-- - DECIMAL(18, 2) was used for parseability testing; final type selection
--   still requires validation of amount range and precision.


-- Investigation 20B: Profile amount range, signs, and decimal precision
-- Purpose:
-- - Profile the minimum and maximum normalized amounts to determine the
--   required number of digits before the decimal point.
-- - Count zero and negative amounts that may represent credits, reversals,
--   or data anomalies requiring further inspection.
-- - Determine the decimal precision present in the source and validate
--   whether a two-decimal monetary type would preserve every value without
--   rounding.
WITH normalized AS (
    SELECT
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 6)
        ) AS normalized_amount
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)
SELECT
    COUNT(*) AS row_count,
    MIN(normalized_amount) AS minimum_amount,
    MAX(normalized_amount) AS maximum_amount,
    COUNT(*) FILTER (
        WHERE normalized_amount = 0
    ) AS zero_amount_count,
    COUNT(*) FILTER (
        WHERE normalized_amount < 0
    ) AS negative_amount_count,
    COUNT(*) FILTER (
        WHERE normalized_amount <> ROUND(normalized_amount, 2)
    ) AS changed_by_two_decimal_rounding_count
FROM normalized;

-- Findings:
-- - All 11,204 normalized amount values were profiled.
-- - The observed range is -1,800.00 to 83,246.69.
-- - No zero amounts were found.
-- - Three negative amounts were found and require further investigation
--   before they can be classified as valid credits, reversals, or anomalies.
-- - The changed_by_two_decimal_rounding_count was 0, confirming that a
--   scale of two decimal places preserves every source amount.
-- - Use DECIMAL(10, 2) for amount in the cleaned cost_transactions output.
--   This allows eight digits before the decimal, provides headroom above
--   the current maximum, and is consistent with the proposed monetary
--   type for project_budgets.


-- Next step:
-- Investigation 20C: Inspect negative amount transactions
-- Purpose:
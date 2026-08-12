-- Projects Data Profiling
-- Source: data/raw/project_budgets.csv
-- Purpose:
-- - Profile the raw project_budgets dataset before cleaning and transformation.
-- - Identify schema, completeness, uniqueness, categorical, date, numeric,
--   and relationship issues that could affect the analysis.
-- Notes:
-- - Preserve the original investigation numbering from the combined profiling file.
-- - Preserve raw source values; document cleaning decisions separately.
-- - Reporting cutoff: 2026-06-30.
--
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
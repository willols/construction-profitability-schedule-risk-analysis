-- Project Updates Data Profiling
-- Source: data/raw/change_orders.csv
-- Purpose:
-- - Profile the raw change_orders dataset before cleaning and transformation.
-- - Identify schema, completeness, uniqueness, categorical, date, numeric,
--   and relationship issues that could affect the analysis.
-- Notes:
-- - Continue the established investigation numbering across profiling files.
-- - Preserve raw source values and document cleaning decisions separately.
-- - Reporting cutoff: 2026-06-30.


-- Investigation 64: Inspect change_orders.csv structure and establish an initial grain hypothesis
-- Purpose:
-- - Inspect the inferred column names, data types, representative records, and total row count.
-- - Identify the candidate row-level identifier and the fields that describe one
--   change-order record.
-- - Form an initial business-grain hypothesis for validation through subsequent
--   completeness and uniqueness testing.

-- Inferred schema
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/change_orders.csv');

-- Representative records
SELECT *
FROM read_csv_auto('data/raw/change_orders.csv')
LIMIT 10;

-- Total row count
SELECT
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - The file contains 12 inferred columns and 146 total rows.
-- - The sample suggests that one row represents one change-order request
--   associated with one project.
-- - Sampled change_order_id values are populated and follow a consistent ID
--   pattern, supporting the column as the candidate row-level identifier;
--   full completeness and uniqueness testing is still required.
-- - requested_revenue_change was inferred as VARCHAR despite the sampled values
--   appearing numeric, requiring conversion-compatibility testing.
-- - estimated_cost_change, approved_revenue_change, and billed_amount were
--   inferred as DOUBLE; their precision and scale require evaluation before
--   selecting cleaned monetary types.


-- Investigation 65: Test change_order_id completeness and uniqueness
-- Purpose:
-- - Compare total rows with populated and distinct change_order_id counts
--   to evaluate identifier completeness and uniqueness.
-- - Determine whether change_order_id supports the hypothesized
--   one-row-per-change-order grain and flag any issues for follow-up.
SELECT
    COUNT(*) AS total_rows,
    COUNT(change_order_id) AS populated_change_order_ids,
    COUNT(DISTINCT change_order_id) AS distinct_change_order_ids,
    COUNT(*) FILTER (
        WHERE change_order_id IS NULL
    ) AS null_change_order_ids
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - All 146 rows contain a populated change_order_id, with zero null
--   identifiers; the candidate identifier therefore passes completeness.
-- - The 146 populated identifiers contain only 145 distinct values,
--   indicating one repeated occurrence and a failure of uniqueness.
-- - The repeated identifier and its associated rows require inspection
--   before validating the one-row-per-change-order grain.


-- Investigation 65A: Identify and inspect the repeated change_order_id
-- Purpose:
-- - Identify any change_order_id occurring more than once and return all
--   associated rows and column values.
-- - Determine whether the repetition represents exact duplicate rows or
--   conflicting records for the same identifier.

-- Identify repeated identifiers
SELECT
    change_order_id,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/change_orders.csv')
GROUP BY change_order_id
HAVING COUNT(*) > 1;

-- Inspect all rows associated with the repeated identifier
SELECT *
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE change_order_id = 'CO0013';

-- Findings:
-- - change_order_id CO0013 appears in two rows.
-- - All 12 column values match exactly, confirming one exact duplicate row.
-- - The raw file therefore contains 146 rows representing 145 distinct
--   change-order records.

-- Cleaning decision:
-- - Preserve one CO0013 row and exclude the additional exact copy when
--   constructing the cleaned analytical output; do not modify the raw file.


-- Investigation 66: Validate the project_id relationship
-- Purpose:
-- - Validate that every change-order row has a populated project_id.
-- - Count the distinct project_id values represented in change_orders.csv.
-- - Test whether every project_id in change_orders.csv also exists in
--   projects.csv and identify any unmatched values for follow-up.
-- Profile project_id completeness and coverage
SELECT
    COUNT(*) AS total_rows,
    COUNT(project_id) AS populated_project_ids,
    COUNT(DISTINCT project_id) AS distinct_project_ids,
    COUNT(*) FILTER (
        WHERE project_id IS NULL
    ) AS null_project_ids
FROM read_csv_auto('data/raw/change_orders.csv');

-- Identify project_id values missing from the projects reference
SELECT DISTINCT
    co.project_id
FROM read_csv_auto('data/raw/change_orders.csv') AS co
ANTI JOIN read_csv_auto('data/raw/projects.csv') AS p
    ON co.project_id = p.project_id;

-- Findings:
-- - All 146 change-order rows contain a populated project_id, with zero nulls.
-- - The file contains 69 distinct project_id values.
-- - The anti-join identified one unmatched project_id: P994.
-- - The project_id relationship therefore fails referential-integrity
--   validation for P994.
-- - P994 requires further investigation; no correction can be made without
--   supporting evidence.


-- Investigation 66A: Investigate the orphan project_id P994
-- Purpose:
-- - Return every change-order row associated with P994 and inspect all
--   available record context.
-- - Determine the scope of the issue and whether the records provide evidence
--   supporting a correction or require stakeholder clarification.
SELECT *
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE project_id = 'P994';

-- Findings:
-- - P994 is associated with one change-order row: CO9999.
-- - CO9999 is a pending additive change order with requested revenue of
--   48,000 and estimated cost of 33,000.
-- - Its approval and billing fields are null, which appears consistent with
--   the pending status, although status-field consistency will be formally
--   tested later.
-- - CO9999 and P994 are unusually high identifiers relative to the observed
--   ID patterns, but this does not prove a specific error or identify a
--   valid replacement project.
-- - The record contains no internal evidence supporting a correction to P994.


-- Investigation 66B: Search the supplied datasets for project_id P994
-- Purpose:
-- - Determine whether P994 appears outside change_orders.csv and has supporting
--   records in any other supplied dataset.
-- - Use the result to decide whether P994 remains classified as an orphan
--   requiring stakeholder clarification.
SELECT
    'projects.csv' AS source_file,
    COUNT(*) AS matching_row_count
FROM read_csv_auto('data/raw/projects.csv')
WHERE project_id = 'P994'

UNION ALL

SELECT
    'project_budgets.csv' AS source_file,
    COUNT(*) AS matching_row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE project_id = 'P994'

UNION ALL

SELECT
    'cost_transactions.csv' AS source_file,
    COUNT(*) AS matching_row_count
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE project_id = 'P994'

UNION ALL

SELECT
    'labor_entries.csv' AS source_file,
    COUNT(*) AS matching_row_count
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE project_id = 'P994'

UNION ALL

SELECT
    'project_updates.csv' AS source_file,
    COUNT(*) AS matching_row_count
FROM read_csv_auto('data/raw/project_updates.csv')
WHERE project_id = 'P994';

-- Findings:
-- - All five searched datasets returned zero records with project_id P994.
-- - P994 is isolated to change_orders.csv among the supplied datasets and
--   remains classified as an orphan project ID.
-- - No authoritative evidence identifies a valid replacement project_id.
-- - Retain P994 unchanged and flag CO9999 for stakeholder clarification in
--   the future cleaned analytical layer.


-- Investigation 67: Identify values preventing numeric inference for requested_revenue_change
-- Purpose:
-- - Use TRY_CAST to test whether populated requested_revenue_change values can
--   be interpreted as numeric data without causing the query to fail.
-- - Inspect any failed conversions to determine why DuckDB inferred the column
--   as VARCHAR.
SELECT
    change_order_id,
    project_id,
    requested_revenue_change AS raw_requested_revenue_change
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE requested_revenue_change IS NOT NULL
  AND TRY_CAST(requested_revenue_change AS DOUBLE) IS NULL;

-- Findings:
-- - Exactly one populated requested_revenue_change value failed direct numeric
--   conversion: CO0064 for project P039, with the raw value '$43,428.72'.
-- - The value contains a currency symbol and thousands separator, which prevent
--   direct conversion even though the underlying amount appears numeric.
-- - Preserve the raw value unchanged. Any normalization will occur only in the
--   future cleaned analytical layer.


-- Investigation 67A: Validate normalization of requested_revenue_change
-- Purpose:
-- - Remove the dollar sign and thousands separator in the query only, then
--   attempt numeric conversion without modifying the raw data.
-- - Confirm that CO0064 normalizes to 43428.72.
SELECT
    requested_revenue_change AS raw_requested_revenue_change,
    REPLACE(
        REPLACE(requested_revenue_change, '$', ''),
        ',',
        ''
    ) AS normalized_requested_revenue_change_text,
    TRY_CAST(
        REPLACE(
            REPLACE(requested_revenue_change, '$', ''),
            ',',
            ''
        ) AS DOUBLE
    ) AS normalized_requested_revenue_change_numeric
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE change_order_id = 'CO0064';

-- Findings:
-- - CO0064 contained the raw value '$43,428.72'.
-- - Removing the dollar sign and thousands separator produced the normalized
--   text value '43428.72'.
-- - TRY_CAST successfully converted the normalized text to the numeric value
--   43428.72.
-- - This validates the proposed normalization for CO0064 only; column-wide
--   numeric compatibility has not yet been confirmed.


-- Investigation 67B: Validate column-wide numeric compatibility after normalization
-- Purpose:
-- - Apply the proposed query-only normalization to every populated
--   requested_revenue_change value and identify any values that still fail
--   numeric conversion with TRY_CAST.
SELECT
    change_order_id,
    project_id,
    requested_revenue_change AS raw_requested_revenue_change
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE requested_revenue_change IS NOT NULL
  AND TRY_CAST(
        REPLACE(
            REPLACE(requested_revenue_change, '$', ''),
            ',',
            ''
        ) AS DOUBLE
      ) IS NULL;

-- Findings:
-- - No populated values failed numeric conversion after normalization.
-- - The proposed formatting cleanup is sufficient for numeric compatibility
--   across the requested_revenue_change column.
-- - No raw values were modified; normalization remains a future cleaned-layer
--   transformation.
-- - The final DECIMAL precision and scale still need to be selected through
--   separate range and fractional-precision profiling.


-- Investigation 68: Profile completeness and range of requested_revenue_change
-- Purpose:
-- - Apply the validated query-only normalization and summarize the column's
--   populated values, NULL values, minimum, maximum, zero values, and negative
--   values.
-- - Use the results to evaluate completeness and numeric range before selecting
--   the final DECIMAL precision and scale.
WITH standardized_change_orders AS (
    SELECT
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',',
                ''
            ) AS DOUBLE) AS standardized_requested_revenue_change
    FROM read_csv_auto('data/raw/change_orders.csv')
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(standardized_requested_revenue_change)
        AS standardized_requested_revenue_change_count,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change IS NULL
    ) AS standardized_requested_revenue_change_null_count,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change = 0
    ) AS standardized_requested_revenue_change_zero_count,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change < 0
    ) AS standardized_requested_revenue_change_negative_count,
    MIN(standardized_requested_revenue_change)
        AS minimum_standardized_requested_revenue_change,
    MAX(standardized_requested_revenue_change)
        AS maximum_standardized_requested_revenue_change
FROM standardized_change_orders;

-- Findings:
-- - All 146 rows contain populated requested_revenue_change values, and all
--   values remain populated after query-only normalization and conversion.
-- - No NULL or zero values were found; 12 values are negative.
-- - Standardized values range from -180146.05 to 201500.62, requiring capacity
--   for at least six integer digits.
-- - Negative values may represent deductive change orders, but their signs must
--   be validated against change_order_type before they are classified as valid.
-- - The observed minimum and maximum do not establish the required decimal
--   scale; a separate column-wide fractional-precision test is still required.


-- Investigation 69: Determine the minimum lossless fractional scale for
-- requested_revenue_change
-- Purpose:
-- - Test every standardized value against rounding to zero, one, two, and three
--   decimal places.
-- - Identify the smallest scale that preserves every populated value without
--   rounding loss, extending the test if three decimal places are insufficient.
-- - Use the result with the six-digit integer requirement to support the final
--   DECIMAL precision and scale selection.
WITH standardized_change_orders AS (
    SELECT
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',',
                ''
            ) AS DOUBLE
        ) AS standardized_requested_revenue_change
    FROM read_csv_auto('data/raw/change_orders.csv')
)
SELECT
    COUNT(*) AS total_rows,
    COUNT(standardized_requested_revenue_change) AS testable_values,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            <> ROUND(standardized_requested_revenue_change, 0)
    ) AS values_changed_at_0_decimals,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            <> ROUND(standardized_requested_revenue_change, 1)
    ) AS values_changed_at_1_decimal,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            <> ROUND(standardized_requested_revenue_change, 2)
    ) AS values_changed_at_2_decimals,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            <> ROUND(standardized_requested_revenue_change, 3)
    ) AS values_changed_at_3_decimals
FROM standardized_change_orders;

-- Findings:
-- - All 146 rows contain testable standardized values, confirming that no
--   values were lost during normalization and conversion.
-- - Rounding to zero decimal places changed 144 values, while rounding to one
--   decimal place changed 128 values.
-- - Rounding to two or three decimal places changed zero values, establishing
--   two decimal places as the minimum lossless scale.
-- - Combined with the six-digit integer requirement established in
--   Investigation 68, DECIMAL(8,2) is the minimum lossless datatype supported
--   by the observed requested_revenue_change values.


-- Investigation 70: Profile completeness and category consistency of
-- change_order_type
-- Purpose:
-- - Profile the total, populated, NULL, and distinct raw change_order_type
--   values.
-- - Review the raw category distribution for unexpected labels, inconsistent
--   capitalization, spelling differences, or surrounding whitespace.
-- - Determine whether query-only standardization is required before using
--   change_order_type to validate requested_revenue_change signs.
SELECT
    change_order_type,
    COUNT(*) AS total_count
FROM read_csv_auto('data/raw/change_orders.csv')
GROUP BY change_order_type
ORDER BY total_count DESC;

-- Findings:
-- - Two raw categories were returned: 134 additive and 12 deductive.
-- - The category counts sum to all 146 rows, with no NULL or unexpected
--   change_order_type values.
-- - Both categories are consistently formatted, so no standardization is
--   required.
-- - The 12 deductive orders match the count of 12 negative
--   requested_revenue_change values, supporting the expected relationship,
--   but a row-level sign comparison is still required for confirmation.


-- Investigation 71: Validate requested_revenue_change signs against
-- change_order_type
-- Purpose:
-- - Apply the validated query-only normalization to requested_revenue_change.
-- - Confirm that all deductive change orders have negative revenue changes and
--   all additive change orders have positive revenue changes.
-- - Identify any row-level sign-and-type mismatches that matching aggregate
--   counts could conceal.
WITH standardized_change_orders AS (
    SELECT
        change_order_type,
        CAST(
            REPLACE(
            REPLACE(requested_revenue_change, '$', ''),
            ',',
            ''
        ) AS DECIMAL(8,2)
        ) AS standardized_requested_revenue_change
    FROM read_csv_auto('data/raw/change_orders.csv')
)

SELECT
    change_order_type,
    COUNT(*) AS total_count,
    COUNT (*) FILTER (
        WHERE standardized_requested_revenue_change > 0
    ) AS positive_count,
    COUNT (*) FILTER (
        WHERE standardized_requested_revenue_change < 0
    ) AS negative_count,
    COUNT (*) FILTER (
        WHERE standardized_requested_revenue_change = 0
    ) AS zero_count
FROM standardized_change_orders
GROUP BY change_order_type;

-- Findings:
-- - All 134 additive change orders have positive requested_revenue_change
--   values, with no negative or zero values.
-- - All 12 deductive change orders have negative requested_revenue_change
--   values, with no positive or zero values.
-- - No row-level sign-and-type mismatches were found.
-- - The 12 negative requested_revenue_change values are valid deductive change
--   orders and require no correction.


-- Investigation 72: Profile completeness and category consistency of reason


-- Investigation 72A: Measure reason completeness
-- Purpose:
-- - Quantify total, NULL, blank or whitespace-only, populated,
--   and distinct raw reason values.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE reason IS NULL
    ) AS null_reason_count,
    COUNT(*) FILTER (
        WHERE reason IS NOT NULL
          AND TRIM(reason) = ''
    ) AS blank_reason_count,
    COUNT(*) FILTER (
        WHERE reason IS NOT NULL
          AND TRIM(reason) <> ''
    ) AS populated_reason_count,
    COUNT(DISTINCT reason) AS distinct_raw_reason_count
FROM read_csv_auto('data/raw/change_orders.csv');


-- Investigation 72B: Review the raw reason distribution
-- Purpose:
-- - Retrieve each distinct raw reason and its frequency to identify unexpected
--   labels, inconsistent capitalization, and spelling differences.
-- - Compare raw and trimmed lengths to detect leading or trailing whitespace.
-- - Determine whether any reason values require standardization in the cleaned
--   layer while preserving the original source values unchanged.
SELECT
    reason,
    LENGTH(reason) AS raw_length,
    LENGTH(TRIM(reason)) AS trimmed_length,
    COUNT(*) AS reason_frequency
FROM read_csv_auto('data/raw/change_orders.csv')
GROUP BY reason
ORDER BY reason_frequency DESC, reason;

-- Findings:
-- - All 146 rows contain populated reason values; no NULL, blank, or
--   whitespace-only values were found.
-- - Six distinct raw reason categories were identified, and their frequencies
--   sum to all 146 rows.
-- - Each category's raw length equals its trimmed length, confirming that no
--   leading or trailing whitespace is present.
-- - No spelling or capitalization inconsistencies were identified, and all six
--   categories appear to be valid business reasons for change orders.
-- Decision:
-- - Preserve all six reason categories unchanged in the cleaned layer; no
--   standardization is required.


-- Investigation 73: Profile completeness and category consistency of status

-- Investigation 73A: Measure status completeness
-- Purpose:
-- - Quantify total, NULL, blank or whitespace-only, populated,
--   and distinct raw status values.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE status IS NULL
    ) AS null_status_count,
    COUNT(*) FILTER (
        WHERE status IS NOT NULL
          AND TRIM(status) = ''
    ) AS blank_status_count,
    COUNT(*) FILTER (
        WHERE status IS NOT NULL
          AND TRIM(status) <> ''
    ) AS populated_status_count,
    COUNT(DISTINCT status) AS distinct_raw_status_count
FROM read_csv_auto('data/raw/change_orders.csv');


-- Investigation 73B: Review the raw status distribution
-- Purpose:
-- - Retrieve each distinct raw status and its frequency to identify unexpected
--   labels, inconsistent capitalization, and spelling differences.
-- - Compare raw and trimmed lengths to detect leading or trailing whitespace.
-- - Determine whether any status values require standardization in the cleaned
--   layer while preserving the original source values unchanged.
SELECT
    status,
    LENGTH(status) AS raw_length,
    LENGTH(TRIM(status)) AS trimmed_length,
    COUNT(*) AS status_frequency
FROM read_csv_auto('data/raw/change_orders.csv')
GROUP BY status
ORDER BY status_frequency DESC, status;

-- Findings:
-- - All 146 rows contain populated status values; no NULL, blank, or
--   whitespace-only values were found.
-- - Six distinct raw status labels were identified, and their frequencies sum
--   to all 146 rows.
-- - Five raw labels have matching raw and trimmed lengths. `PENDING ` is the
--   only label containing trailing whitespace, with a raw length of 8 and a
--   trimmed length of 7.
-- - `Approved` is inconsistent with `approved` because of capitalization.
-- - `PENDING ` is inconsistent with `pending` because of capitalization and
--   trailing whitespace.
-- - The six raw labels represent four intended business statuses: approved,
--   pending, rejected, and withdrawn.
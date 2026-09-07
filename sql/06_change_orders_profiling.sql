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


-- Investigation 73C: Validate query-only status standardization
-- Purpose:
-- - Apply LOWER(TRIM(status)) during query-only profiling to remove
--   capitalization and trailing-whitespace inconsistencies from the raw values.
-- - Confirm that the proposed transformation produces exactly four standardized
--   categories: approved, withdrawn, pending, and rejected.
-- - Verify that the standardized category frequencies reconcile to all 146 rows.
-- - Validate the transformation for use in the future cleaned analytical layer
--   without modifying the raw source values.

WITH standardized_statuses AS (
    SELECT
        LOWER(TRIM(status)) AS standardized_status
    FROM read_csv_auto('data/raw/change_orders.csv')
),

status_frequencies AS (
    SELECT
        standardized_status,
        COUNT(*) AS status_frequency
    FROM standardized_statuses
    GROUP BY standardized_status
)

SELECT
    standardized_status,
    status_frequency,
    COUNT(*) OVER () AS standardized_category_count,
    SUM(status_frequency) OVER () AS reconciled_row_count
FROM status_frequencies
ORDER BY
    status_frequency DESC,
    standardized_status;

-- Findings and cleaning decision:
-- - LOWER(TRIM(status)) reduced the six raw status representations to four
--   standardized categories: approved, withdrawn, pending, and rejected.
-- - The standardized category frequencies reconcile to all 146 source rows,
--   confirming that the transformation did not lose or isolate any values.
-- - Preserve the raw status values unchanged and apply LOWER(TRIM(status))
--   only when creating the future cleaned analytical layer.


-- Investigation 74: Profile estimated_cost_change completeness, special values,
-- and range
-- Purpose:
-- - Measure total, populated, and NULL counts to determine whether every change
--   order contains an estimated cost change.
-- - Count zero and negative values to identify amounts that may require later
--   business-context validation.
-- - Calculate the minimum and maximum values to establish the observed numeric
--   range and identify potentially unexpected extremes.
-- - Use the results to prepare for minimum lossless fractional-scale testing
--   before selecting a candidate exact DECIMAL type.
SELECT
    COUNT(*) AS total_rows,
    COUNT(estimated_cost_change) AS populated_values,
    COUNT(*) FILTER (
        WHERE estimated_cost_change IS NULL
    ) AS null_count,
    COUNT(*) FILTER (
        WHERE estimated_cost_change = 0
    ) AS zero_count,
    COUNT(*) FILTER (
        WHERE estimated_cost_change < 0
    ) AS negative_count,
    MIN(estimated_cost_change) AS minimum_estimated_cost_change,
    MAX(estimated_cost_change) AS maximum_estimated_cost_change
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - estimated_cost_change is populated in all 146 rows, with no NULL or zero
--   values.
-- - Values range from -122,322.75 to 124,992.57.
-- - Twelve values are negative, matching the previously observed count of 12
--   deductive change orders.
-- - The matching counts suggest that negative estimated cost changes may
--   correspond to deductive change orders, but row-level sign alignment has
--   not yet been validated.
-- - Do not classify the negative values as errors based on this profile alone.


-- Investigation 75: Determine the minimum lossless fractional scale for
-- estimated_cost_change
-- Purpose:
-- - Compare each populated estimated_cost_change value with the result of
--   rounding it to zero, one, two, and three decimal places.
-- - Count the values changed at each scale and identify the smallest scale that
--   preserves every populated value without rounding loss, extending the test
--   if three decimal places are insufficient.
-- - Combine the minimum lossless scale with the six-digit integer requirement
--   established by the observed range to select a candidate exact DECIMAL type.
SELECT
    COUNT(*) AS total_rows,
    COUNT(estimated_cost_change) AS testable_values,
    COUNT(*) FILTER (
        WHERE estimated_cost_change <> ROUND(estimated_cost_change, 0)
        ) AS changed_at_0_decimals,
    COUNT(*) FILTER (
        WHERE estimated_cost_change <> ROUND(estimated_cost_change, 1)
        ) AS changed_at_1_decimals,
    COUNT(*) FILTER (
        WHERE estimated_cost_change <> ROUND(estimated_cost_change, 2)
        ) AS changed_at_2_decimals,
    COUNT(*) FILTER (
        WHERE estimated_cost_change <> ROUND(estimated_cost_change, 3)
        ) AS changed_at_3_decimals
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - All 146 estimated_cost_change values were tested.
-- - Rounding to zero decimal places changed 145 values.
-- - Rounding to one decimal place changed 135 values.
-- - Rounding to two or three decimal places changed zero values.
-- - Two decimal places is therefore the minimum lossless fractional scale.
-- - The observed range requires six integer digits, and the data requires two
--   fractional digits.
-- - Select DECIMAL(8,2) as the candidate exact type for estimated_cost_change.


-- Investigation 76: Profile approved_revenue_change completeness, zero and
-- negative values, and observed numeric range
-- Purpose:
-- - Quantify total, populated, and NULL counts to assess completeness without
--   assuming that every workflow status requires an approved revenue change.
-- - Count zero and negative values as profiling observations for later validation
--   against status, change_order_type, and the approval workflow.
-- - Calculate the minimum and maximum values to establish the observed numeric
--   range and identify values that may warrant further investigation.
-- - Because DuckDB infers the column as DOUBLE, focus on numeric profiling rather
--   than text-to-numeric compatibility testing.
-- - Use the results to prepare for minimum lossless fractional-scale testing and
--   selection of a candidate exact DECIMAL type.
-- - Defer final shared monetary-type selection and broader relationship validation
--   until the remaining change-order monetary fields have been profiled.
SELECT
    COUNT(*) AS total_rows,
    COUNT(approved_revenue_change) AS populated_count,
    COUNT(*) FILTER (
        WHERE approved_revenue_change IS NULL
    ) AS null_count,
    COUNT(*) FILTER (
        WHERE approved_revenue_change = 0
    ) AS zero_count,
    COUNT(*) FILTER (
        WHERE approved_revenue_change < 0
    ) AS negative_count,
    MIN(approved_revenue_change) AS minimum_approved_revenue_change,
    MAX(approved_revenue_change) AS maximum_approved_revenue_change
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - approved_revenue_change is populated in 103 of 146 rows, with 43 NULL values,
--   10 negative values, and no zero values.
-- - The 103 populated values match the aggregate count of standardized approved
--   statuses, while the 43 NULLs match the combined count of withdrawn, pending,
--   and rejected statuses.
-- - This aggregate reconciliation does not confirm that the same rows align;
--   row-level workflow validation is deferred until the remaining monetary fields
--   have been profiled.
-- - Populated values range from -177978.63 to 158368.20.
-- - NULL and negative values are profiling observations rather than confirmed
--   errors; their validity depends on later validation against status,
--   change_order_type, and the approval workflow.


-- Investigation 77: Determine the minimum lossless fractional scale for
-- approved_revenue_change
-- Purpose:
-- - Compare each populated approved_revenue_change value with the result of
--   rounding it to zero, one, two, and three decimal places.
-- - Count the values changed at each scale and identify the smallest scale that
--   preserves every populated value without rounding loss, extending the test
--   if three decimal places are insufficient.
-- - Combine the minimum lossless scale with the six-digit integer requirement
--   established by the observed range to select a candidate exact DECIMAL type.
SELECT
    COUNT(*) AS total_rows,
    COUNT(approved_revenue_change) AS testable_values,
    COUNT(*) FILTER (
        WHERE approved_revenue_change <> ROUND(approved_revenue_change, 0)
        ) AS changed_at_0_decimals,
    COUNT(*) FILTER (
        WHERE approved_revenue_change <> ROUND(approved_revenue_change, 1)
        ) AS changed_at_1_decimals,
    COUNT(*) FILTER (
        WHERE approved_revenue_change <> ROUND(approved_revenue_change, 2)
        ) AS changed_at_2_decimals,
    COUNT(*) FILTER (
        WHERE approved_revenue_change <> ROUND(approved_revenue_change, 3)
        ) AS changed_at_3_decimals
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - All 103 populated approved_revenue_change values were tested.
-- - Rounding to zero decimal places changed all 103 populated values.
-- - Rounding to one decimal place changed 97 values.
-- - Rounding to two or three decimal places changed no values.
-- - Two decimal places is therefore the minimum lossless fractional scale
--   supported by the observed data.
-- - The observed range requires six integer digits, while the minimum lossless
--   scale requires two fractional digits.
-- - DECIMAL(8,2) is the minimum candidate exact type supported by the observed
--   approved_revenue_change values.


-- Investigation 78: Profile billed_amount completeness, zero and negative
-- values, and observed numeric range
-- Purpose:
-- - Quantify total, populated, and NULL counts to assess completeness without
--   assuming that every change order or workflow status requires a billed amount.
-- - Count zero and negative values as profiling observations for later validation
--   against status, change_order_type, approved_revenue_change, billed_date, and
--   the billing workflow.
-- - Calculate the minimum and maximum populated values to establish the observed
--   numeric range and identify amounts that may warrant further investigation.
-- - Because DuckDB infers the column as DOUBLE, focus on numeric profiling rather
--   than text-to-numeric compatibility testing.
-- - Use the results to prepare for minimum lossless fractional-scale testing and
--   selection of a candidate exact DECIMAL type.
-- - Defer final shared monetary-type selection and broader relationship validation
--   until all change-order monetary fields have been profiled.
SELECT
    COUNT(*) AS total_rows,
    COUNT(billed_amount) AS populated_count,
    COUNT(*) FILTER (
        WHERE billed_amount IS NULL
    ) AS null_count,
    COUNT(*) FILTER (
        WHERE billed_amount = 0
    ) AS zero_count,
    COUNT(*) FILTER (
        WHERE billed_amount < 0
    ) AS negative_count,
    MIN(billed_amount) AS minimum_billed_amount,
    MAX(billed_amount) AS maximum_billed_amount
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - billed_amount is populated in 103 of 146 rows, with 43 NULL values,
--   24 zero values, and 8 negative values.
-- - The 103 populated values and 43 NULLs match both the aggregate completeness
--   counts for approved_revenue_change and the aggregate split between approved
--   and non-approved statuses.
-- - This aggregate reconciliation does not confirm that the same rows align;
--   row-level relationship and workflow validation is deferred to a later
--   investigation.
-- - Populated values range from -133652.67 to 158368.20.
-- - NULL, zero, and negative values are profiling observations rather than
--   confirmed errors; their validity depends on later validation against status,
--   change_order_type, approved_revenue_change, billed_date, and the billing
--   workflow.


-- Investigation 79: Determine the minimum lossless fractional scale for
-- billed_amount
-- Purpose:
-- - Compare each populated billed_amount value with the result of
--   rounding it to zero, one, two, and three decimal places.
-- - Count the values changed at each scale and identify the smallest scale that
--   preserves every populated value without rounding loss, extending the test
--   if three decimal places are insufficient.
-- - Combine the minimum lossless scale with the six-digit integer requirement
--   established by the observed range to select a candidate exact DECIMAL type.
SELECT
    COUNT(*) AS total_rows,
    COUNT(billed_amount) AS testable_values,
    COUNT(*) FILTER (
        WHERE billed_amount <> ROUND(billed_amount, 0)
        ) AS changed_at_0_decimals,
    COUNT(*) FILTER (
        WHERE billed_amount <> ROUND(billed_amount, 1)
        ) AS changed_at_1_decimals,
    COUNT(*) FILTER (
        WHERE billed_amount <> ROUND(billed_amount, 2)
        ) AS changed_at_2_decimals,
    COUNT(*) FILTER (
        WHERE billed_amount <> ROUND(billed_amount, 3)
        ) AS changed_at_3_decimals
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - All 103 populated billed_amount values were tested.
-- - Rounding to zero decimal places changed 79 values.
-- - Rounding to one decimal place changed 74 values.
-- - Rounding to two or three decimal places changed no values.
-- - Two decimal places is therefore the minimum lossless fractional scale
--   supported by the observed data.
-- - The observed range requires six integer digits, while the minimum lossless
--   scale requires two fractional digits.
-- - DECIMAL(8,2) is the minimum candidate exact type supported by the observed
--   billed_amount values.


-- Investigation 80: Select a shared exact datatype for change-order monetary fields
-- Purpose:
-- - Consolidate the observed integer-width and minimum lossless fractional-scale
--   requirements for requested_revenue_change, estimated_cost_change,
--   approved_revenue_change, and billed_amount.
-- - Identify the greatest integer-width and fractional-scale requirements across
--   the four fields and determine the minimum shared DECIMAL(p,s) type that
--   preserves every observed value exactly.
-- - Compare the minimum observed requirement with existing project monetary
--   datatypes and consider whether additional capacity is appropriate for schema
--   consistency and reasonable future headroom.
-- - Select and document one shared exact datatype for these fields in the future
--   cleaned analytical layer while preserving the raw source values unchanged.
WITH prepared_change_orders AS (
    SELECT
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',',
                ''
            ) AS DOUBLE
        ) AS requested_revenue_change_numeric,
        estimated_cost_change,
        approved_revenue_change,
        billed_amount
    FROM read_csv_auto('data/raw/change_orders.csv')
),

monetary_values AS (
    SELECT
        1 AS field_order,
        'requested_revenue_change' AS monetary_field,
        requested_revenue_change_numeric AS amount
    FROM prepared_change_orders

    UNION ALL

    SELECT
        2 AS field_order,
        'estimated_cost_change' AS monetary_field,
        estimated_cost_change AS amount
    FROM prepared_change_orders

    UNION ALL

    SELECT
        3 AS field_order,
        'approved_revenue_change' AS monetary_field,
        approved_revenue_change AS amount
    FROM prepared_change_orders

    UNION ALL

    SELECT
        4 AS field_order,
        'billed_amount' AS monetary_field,
        billed_amount AS amount
    FROM prepared_change_orders
)

SELECT
    monetary_field,
    COUNT(*) AS total_rows,
    COUNT(amount) AS testable_values,
    MIN(amount) AS minimum_value,
    MAX(amount) AS maximum_value,
    COUNT(*) FILTER (
        WHERE amount <> ROUND(amount, 0)
    ) AS changed_at_0_decimals,
    COUNT(*) FILTER (
        WHERE amount <> ROUND(amount, 1)
    ) AS changed_at_1_decimals,
    COUNT(*) FILTER (
        WHERE amount <> ROUND(amount, 2)
    ) AS changed_at_2_decimals,
    COUNT(*) FILTER (
        WHERE amount <> ROUND(amount, 3)
    ) AS changed_at_3_decimals
FROM monetary_values
GROUP BY
    field_order,
    monetary_field
ORDER BY
    field_order;

-- Findings:
-- - All four change-order monetary fields require a minimum lossless fractional
--   scale of two decimal places.
-- - requested_revenue_change contains the largest absolute observed value,
--   201500.62, establishing a six-digit integer requirement.
-- - Six integer digits and two fractional digits make DECIMAL(8,2) the minimum
--   shared exact type supported by the observed change-order values.
-- - DECIMAL(10,4) fields used elsewhere in project_updates represent
--   precision-sensitive percentages or ratios and do not establish the standard
--   for monetary fields.
-- - Existing project-budget, cost-transaction, and estimated-cost-to-complete
--   monetary fields use DECIMAL(10,2).
-- - Select DECIMAL(10,2) for requested_revenue_change, estimated_cost_change,
--   approved_revenue_change, and billed_amount in the cleaned analytical layer.
-- - This selection preserves all observed values, aligns monetary datatypes
--   across the project, and provides greater integer capacity than the minimum
--   observed requirement.
-- - Preserve the original source values unchanged in the raw layer.


-- Investigation 81: Profile change-order date completeness, ranges, and
-- reporting-cutoff compliance
-- Purpose:
-- - Quantify total, populated, and NULL counts for request_date, approval_date,
--   and billed_date to assess completeness across the change-order lifecycle.
-- - Calculate the earliest and latest populated value for each date field to
--   establish its observed range.
-- - Count dates later than the inclusive June 30, 2026 reporting cutoff to
--   identify records that may fall outside the analysis period.
-- - Because DuckDB infers all three fields as DATE, focus on date profiling
--   rather than text-to-date conversion testing.
-- - Treat missing approval_date and billed_date values as profiling observations
--   rather than confirmed errors.
-- - Defer validation against status and cross-column chronological relationships
--   to the subsequent workflow investigation.
WITH change_orders AS (
    SELECT
        requested_date,
        approval_date,
        billed_date
    FROM read_csv_auto('data/raw/change_orders.csv')
),

date_values AS (
    SELECT
        1 AS field_order,
        'requested_date' AS date_field,
        requested_date AS date_value
    FROM change_orders

    UNION ALL

    SELECT
        2 AS field_order,
        'approval_date' AS date_field,
        approval_date AS date_value
    FROM change_orders

    UNION ALL

    SELECT
        3 AS field_order,
        'billed_date' AS date_field,
        billed_date AS date_value
    FROM change_orders
)

SELECT
    date_field,
    COUNT(*) AS total_rows,
    COUNT(date_value) AS populated_count,
    COUNT(*) FILTER (
        WHERE date_value IS NULL
    ) AS null_count,
    MIN(date_value) AS earliest_date,
    MAX(date_value) AS latest_date,
    COUNT(*) FILTER (
        WHERE date_value > DATE '2026-06-30'
    ) AS after_cutoff_count
FROM date_values
GROUP BY
    field_order,
    date_field
ORDER BY
    field_order;

-- Findings:
-- - requested_date is populated in all 146 rows, with no NULL values. Populated
--   dates range from 2023-04-06 to 2026-06-25, with no dates after the reporting
--   cutoff.
-- - approval_date is populated in 102 rows, with 44 NULL values. Populated dates
--   range from 2023-05-09 to 2026-06-21, with no dates after the reporting cutoff.
-- - billed_date is populated in 79 rows, with 67 NULL values. Populated dates
--   range from 2023-05-19 to 2026-07-09.
-- - The approval_date populated count is one fewer than the aggregate count of
--   103 standardized approved statuses, while the billed_date populated count
--   matches the 79 nonzero billed_amount values.
-- - These aggregate relationships do not confirm that the same rows align.
-- - One billed_date occurs after the inclusive June 30, 2026 reporting cutoff.
--   Missing dates, aggregate relationships, and the post-cutoff value require
--   row-level workflow investigation before they can be classified as valid or
--   erroneous.


-- Investigation 81A: Inspect the single post-cutoff billed_date record
-- Purpose:
-- - Isolate records with a billed_date later than the inclusive June 30, 2026
--   reporting cutoff.
-- - Inspect the complete change-order context, including identifiers, status,
--   type, workflow dates, and monetary values.
-- - Determine whether the post-cutoff date represents valid later billing
--   activity, reporting-cutoff leakage, or a possible source-data issue.
-- - Avoid modifying or excluding the record until the available evidence
--   supports a documented treatment decision.
SELECT
    *
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE billed_date > DATE '2026-06-30';

-- Findings:
-- - CO0119 for project P077 is the only record with a billed_date later than the
--   inclusive June 30, 2026 reporting cutoff.
-- - The deductive change order was requested on 2026-05-11, approved on
--   2026-06-21, and billed on 2026-07-09.
-- - The workflow chronology is logical: requested_date precedes approval_date,
--   and approval_date precedes billed_date.
-- - requested_revenue_change, estimated_cost_change, approved_revenue_change,
--   and billed_amount are all negative, consistent with the deductive
--   change_order_type.
-- - billed_amount equals approved_revenue_change at -36633.22.
-- - The record appears to represent valid post-cutoff billing activity rather
--   than a malformed source value.
-- - Preserve the complete raw record and include the approved change order in
--   the June 30 analysis, but exclude its billed_amount from billed totals
--   calculated as of the reporting cutoff.
-- - Implement the cutoff treatment through a derived cleaned-layer calculation
--   rather than modifying the source billed_amount or billed_date.


-- Investigation 82: Chronological relationships among change-order date fields
-- Purpose:
-- - Verify that requested_date, approval_date, and billed_date follow the
--   expected business sequence: request, approval, then billing.
-- - Count the testable rows for each date comparison and identify three
--   possible violations: approval before request, billing before request,
--   and billing before approval.
SELECT
    COUNT(*) FILTER (
        WHERE requested_date IS NOT NULL
          AND approval_date IS NOT NULL
    ) AS request_approval_testable_count,

    COUNT(*) FILTER (
        WHERE requested_date IS NOT NULL
          AND approval_date IS NOT NULL
          AND approval_date < requested_date
    ) AS approval_before_request_count,

    COUNT(*) FILTER (
        WHERE requested_date IS NOT NULL
          AND billed_date IS NOT NULL
    ) AS request_billing_testable_count,

    COUNT(*) FILTER (
        WHERE requested_date IS NOT NULL
          AND billed_date IS NOT NULL
          AND billed_date < requested_date
    ) AS billed_before_request_count,

    COUNT(*) FILTER (
        WHERE approval_date IS NOT NULL
          AND billed_date IS NOT NULL
    ) AS approval_billing_testable_count,

    COUNT(*) FILTER (
        WHERE approval_date IS NOT NULL
          AND billed_date IS NOT NULL
          AND billed_date < approval_date
    ) AS billed_before_approval_count

FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - Request → approval: 102 testable rows, 0 chronological violations.
-- - Request → billing: 79 testable rows, 0 chronological violations.
-- - Approval → billing: 78 testable rows, 0 chronological violations.
-- - No chronological violations were identified among the testable rows.
-- - The difference between the 79 request-to-billing comparisons and the
--   78 approval-to-billing comparisons indicates that one billed record
--   is missing approval_date.


-- Investigation 82A: Identify the billed change order with a missing approval_date
-- Purpose:
-- - Find the missing approval_date.
SELECT *
FROM read_csv_auto('data/raw/change_orders.csv')
WHERE
    billed_date IS NOT NULL
    AND approval_date IS NULL;

-- Findings:
-- - All 102 rows testable for request-to-approval chronology followed the
--   expected sequence; no approvals occurred before their request dates.
-- - All 79 rows testable for request-to-billing chronology followed the
--   expected sequence; no billings occurred before their request dates.
-- - All 78 rows testable for approval-to-billing chronology followed the
--   expected sequence; no billings occurred before their approval dates.
-- - CO0001 was the only billed change order with a NULL approval_date. Its
--   approved status, approved revenue amount, billed amount, and billed date
--   indicate that approval likely occurred, but its exact date is unknown.
-- - CO0001 cannot be tested for approval-to-billing chronology.

-- Decision:
-- - Preserve CO0001's approval_date as NULL rather than inferring an unsupported
--   date or storing text in a date field.
-- - Flag the missing approval date in the cleaned layer for downstream
--   reporting and data-quality review.


-- Investigation 83: Approval workflow consistency
-- Purpose:
-- - Identify inconsistencies between standardized change-order status and the
--   approval and billing fields.
-- - Check for approved statuses where either approval_date or
--   approved_revenue_change is missing.
-- - Check for non-approved statuses where either approval field is populated.
-- - Check for non-approved statuses with billing evidence, defined as a
--   populated billed_date or a populated, nonzero billed_amount.
SELECT
    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) = 'approved'
    ) AS approved_status_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) = 'approved'
          AND approval_date IS NULL
    ) AS approved_missing_approval_date_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) = 'approved'
          AND approved_revenue_change IS NULL
    ) AS approved_missing_revenue_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) = 'approved'
          AND (
              approval_date IS NULL
              OR approved_revenue_change IS NULL
          )
    ) AS approved_missing_either_field_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
    ) AS nonapproved_status_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
          AND approval_date IS NOT NULL
    ) AS nonapproved_with_approval_date_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
          AND approved_revenue_change IS NOT NULL
    ) AS nonapproved_with_approved_revenue_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
          AND (
              approval_date IS NOT NULL
              OR approved_revenue_change IS NOT NULL
          )
    ) AS nonapproved_with_either_approval_field_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
          AND billed_date IS NOT NULL
    ) AS nonapproved_with_billed_date_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
          AND billed_amount IS NOT NULL
          AND billed_amount <> 0
    ) AS nonapproved_with_nonzero_billed_amount_count,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(status)) <> 'approved'
          AND (
              billed_date IS NOT NULL
              OR (
                  billed_amount IS NOT NULL
                  AND billed_amount <> 0
              )
          )
    ) AS nonapproved_with_either_billing_evidence_count

FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - The standardized status groups account for all 146 change orders:
--   103 approved and 43 non-approved.
-- - One approved change order, CO0001, is missing approval_date.
-- - All 103 approved change orders have a populated
--   approved_revenue_change.
-- - None of the 43 non-approved change orders has approval_date or
--   approved_revenue_change populated.
-- - No non-approved change order has a populated billed_date or a nonzero
--   billed_amount.
-- - CO0001 is the only approval-workflow inconsistency identified.

-- Decision:
-- - Preserve CO0001's approval_date as NULL and flag it in the cleaned layer;
--   do not infer an unsupported approval date.


-- Investigation 84: Estimated-cost sign consistency by change-order type
-- Purpose:
-- - Validate that estimated_cost_change follows the expected sign convention
--   for standardized change_order_type values.
-- - Confirm that additive change orders have positive estimated cost changes
--   and deductive change orders have negative estimated cost changes.
-- - Count zero values and any sign mismatches for follow-up inspection.
SELECT
    COUNT(*) FILTER (
        WHERE change_order_type = 'additive'
          AND estimated_cost_change IS NOT NULL
    ) AS additive_testable_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'additive'
          AND estimated_cost_change IS NOT NULL
          AND estimated_cost_change <= 0
    ) AS additive_nonpositive_estimated_cost_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'deductive'
          AND estimated_cost_change IS NOT NULL
    ) AS deductive_testable_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'deductive'
          AND estimated_cost_change IS NOT NULL
          AND estimated_cost_change >= 0
    ) AS deductive_nonnegative_estimated_cost_count,

    COUNT(*) FILTER (
        WHERE estimated_cost_change = 0
    ) AS zero_estimated_cost_count

FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - All 146 change orders were testable: 134 additive and 12 deductive.
-- - All 134 additive change orders have positive estimated_cost_change values.
-- - All 12 deductive change orders have negative estimated_cost_change values.
-- - No sign mismatches or zero estimated-cost changes were identified.
-- - The relationship between change_order_type and estimated_cost_change is
--   fully consistent with the expected sign convention.

-- Decision:
-- - Preserve the existing estimated_cost_change signs in the cleaned layer;
--   no sign correction or additional exception handling is required.


-- Investigation 85: Validate approved revenue change signs by change order type
-- Purpose:
-- - Validate whether each populated approved_revenue_change has the sign
--   expected for its change_order_type: positive for additive and negative
--   for deductive change orders.
-- - Count testable additive and deductive rows, nonpositive additive exceptions,
--   nonnegative deductive exceptions, and zero approved revenue values.
SELECT
    COUNT(*) FILTER (
        WHERE change_order_type = 'additive'
          AND approved_revenue_change IS NOT NULL
    ) AS additive_testable_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'deductive'
          AND approved_revenue_change IS NOT NULL
    ) AS deductive_testable_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'additive'
          AND approved_revenue_change IS NOT NULL
          AND approved_revenue_change <= 0
    ) AS additive_nonpositive_exception_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'deductive'
          AND approved_revenue_change IS NOT NULL
          AND approved_revenue_change >= 0
    ) AS deductive_nonnegative_exception_count,

    COUNT(*) FILTER (
        WHERE approved_revenue_change IS NOT NULL
          AND approved_revenue_change = 0
    ) AS zero_approved_revenue_change_count
FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - The query returned 93 testable additive rows and 10 testable deductive
--   rows, for a total of 103 populated approved_revenue_change values.
-- - The 103 testable rows reconcile with the earlier populated-value count
--   and the 103 approved statuses identified in Investigation 83.
-- - No additive values were nonpositive, no deductive values were nonnegative,
--   and no zero approved_revenue_change values were found.
--
-- Conclusion:
-- - All 103 populated approved_revenue_change values have signs consistent
--   with their change_order_type.


-- Investigation 86: Validate billed amount signs by change order type
-- Purpose:
-- - Validate whether each populated, nonzero billed_amount has the sign
--   expected for its change_order_type: positive for additive and negative
--   for deductive change orders.
-- - Count testable nonzero additive and deductive rows, negative additive
--   exceptions, positive deductive exceptions, and zero billed_amount values.
SELECT
    COUNT(*) FILTER (
        WHERE change_order_type = 'additive'
          AND billed_amount IS NOT NULL
          AND billed_amount <> 0
    ) AS additive_nonzero_testable_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'deductive'
          AND billed_amount IS NOT NULL
          AND billed_amount <> 0
    ) AS deductive_nonzero_testable_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'additive'
          AND billed_amount IS NOT NULL
          AND billed_amount < 0
    ) AS additive_negative_exception_count,

    COUNT(*) FILTER (
        WHERE change_order_type = 'deductive'
          AND billed_amount IS NOT NULL
          AND billed_amount > 0
    ) AS deductive_positive_exception_count,

    COUNT(*) FILTER (
        WHERE billed_amount = 0
    ) AS zero_billed_amount_count

FROM read_csv_auto('data/raw/change_orders.csv');

-- Findings:
-- - The query returned 71 nonzero additive rows and 8 nonzero deductive rows,
--   for a total of 79 values eligible for sign validation.
-- - The 79 nonzero values plus 24 zero values reconcile with the 103 populated
--   billed_amount values identified during earlier profiling; the remaining
--   43 rows are NULL.
-- - No additive billed amounts were negative, and no deductive billed amounts
--   were positive.
-- - The 24 zero billed amounts were excluded from sign validation and retained
--   for separate billing-status analysis.
--
-- Conclusion:
-- - All 79 nonzero billed_amount values have signs consistent with their
--   change_order_type. The 24 zero values require separate validation against
--   billed_date.


-- Investigation 87: Validate billed_amount and billed_date consistency
-- Purpose:
-- - Check for nonzero billed_amount values with NULL billed_date.
-- - Check for populated billed_date values with NULL billed_amount.
-- - Check for populated billed_date values with zero billed_amount.
-- - Identify potential billing-workflow inconsistencies for review.
-- - Cast billed_amount to the previously selected lossless DECIMAL(10,2).
WITH standardized_change_orders AS (
    SELECT
        TRY_CAST(billed_amount AS DECIMAL(10, 2)
        ) AS standardized_billed_amount,
        billed_date
    FROM read_csv_auto('data/raw/change_orders.csv')
)
SELECT
COUNT(*) AS row_count,
    COUNT(*) FILTER (
        WHERE standardized_billed_amount <> 0
          AND billed_date IS NULL
    ) AS nonzero_amounts_with_null_dates,
    COUNT(*) FILTER (
        WHERE billed_date IS NOT NULL
          AND standardized_billed_amount IS NULL
    ) AS populated_dates_with_null_amounts,
    COUNT(*) FILTER (
        WHERE billed_date IS NOT NULL
          AND standardized_billed_amount = 0
    ) AS populated_dates_with_zero_amounts
FROM standardized_change_orders;

-- Findings:
-- - Evaluated 146 rows.
-- - All nonzero billed_amount values have a populated billed_date.
-- - No populated billed_date is paired with a NULL or zero billed_amount.
-- - No exceptions were found in these three billing-consistency checks.


-- Investigation 88: Compare requested and approved revenue changes
-- Purpose:
-- - Compare rows where both revenue amounts are populated.
-- - Count requested amounts equal to, less than, or greater than
--   approved amounts, grouped by change_order_type.
-- - Remove dollar signs and commas from requested_revenue_change.
-- - Cast both monetary fields to the previously selected
--   lossless DECIMAL(10,2).
WITH standardized_change_orders AS (
    SELECT
        change_order_type,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS standardized_requested_revenue_change,
        TRY_CAST(
            approved_revenue_change AS DECIMAL(10, 2)
        ) AS standardized_approved_revenue_change
    FROM read_csv_auto('data/raw/change_orders.csv')
)
SELECT
    change_order_type,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change IS NOT NULL
          AND standardized_approved_revenue_change IS NOT NULL
    ) AS comparable_rows,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            = standardized_approved_revenue_change
    ) AS requested_equal_to_approved_count,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            < standardized_approved_revenue_change
    ) AS requested_less_than_approved_count,
    COUNT(*) FILTER (
        WHERE standardized_requested_revenue_change
            > standardized_approved_revenue_change
    ) AS requested_greater_than_approved_count
FROM standardized_change_orders
GROUP BY change_order_type;

-- Findings:
-- - 134 additive and 12 deductive rows reconcile to 146 total rows.
-- - Both revenue amounts are populated in 103 rows:
--   93 additive and 10 deductive.
-- - Requested revenue exceeds approved revenue in all 93 comparable
--   additive rows.
-- - Requested revenue is numerically less than approved revenue in
--   all 10 comparable deductive rows, meaning smaller approved deductions.
-- - All 103 approved changes are smaller in magnitude than requested.
-- - The remaining 43 rows have NULL approved revenue and are excluded
--   from the comparison.


-- Investigation 89: Compare approved_revenue_change and billed_amount
-- Purpose:
-- - Classify approved change orders by billing progress.
-- - Unbilled: billed_amount is zero.
-- - Partially billed: billed_amount has a nonzero magnitude smaller
--   than approved_revenue_change.
-- - Fully billed: billed_amount equals approved_revenue_change.
-- - Potentially overbilled: billed_amount has a greater magnitude
--   than approved_revenue_change.
-- - Count NULL billed_amount values separately as missing information.
-- - Cast both monetary fields to the previously selected
--   lossless DECIMAL(10,2).
WITH standardized_change_orders AS (
    SELECT
        change_order_type,
        LOWER(TRIM(status)) AS standardized_status,
        TRY_CAST(
            approved_revenue_change AS DECIMAL(10, 2)
        ) AS standardized_approved_revenue_change,
        TRY_CAST(
            billed_amount AS DECIMAL(10, 2)
        ) AS standardized_billed_amount
    FROM read_csv_auto('data/raw/change_orders.csv')
)
SELECT
    change_order_type,
    COUNT(*) AS approved_rows,
    COUNT(*) FILTER (
        WHERE standardized_approved_revenue_change IS NOT NULL
          AND standardized_billed_amount = 0
    ) AS unbilled_count,
    COUNT(*) FILTER (
        WHERE standardized_approved_revenue_change IS NOT NULL
          AND standardized_billed_amount <> 0
          AND ABS(standardized_billed_amount)
              < ABS(standardized_approved_revenue_change)
    ) AS partially_billed_count,
    COUNT(*) FILTER (
        WHERE standardized_approved_revenue_change IS NOT NULL
          AND standardized_billed_amount
              = standardized_approved_revenue_change
    ) AS fully_billed_count,
    COUNT(*) FILTER (
        WHERE standardized_approved_revenue_change IS NOT NULL
          AND ABS(standardized_billed_amount)
              > ABS(standardized_approved_revenue_change)
    ) AS potentially_overbilled_count,
    COUNT(*) FILTER (
        WHERE standardized_billed_amount IS NULL
    ) AS missing_billed_amount_count,
    COUNT(*) FILTER (
        WHERE standardized_approved_revenue_change IS NULL
    ) AS missing_approved_amount_count
FROM standardized_change_orders
WHERE standardized_status = 'approved'
GROUP BY change_order_type;

-- Findings:
-- - Evaluated 103 approved rows: 93 additive and 10 deductive.
-- - 24 are unbilled: 22 additive and 2 deductive.
-- - 22 are partially billed: 20 additive and 2 deductive.
-- - 57 are fully billed: 51 additive and 6 deductive.
-- - No potentially overbilled rows were found.
-- - No approved rows have missing approved revenue or billed amounts.
-- - Billing categories reconcile to all 103 approved rows.
-- - Results reflect billing as recorded, without applying the
--   June 30, 2026 reporting cutoff.
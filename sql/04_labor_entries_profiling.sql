-- Projects Data Profiling
-- Source: data/raw/labor_entries.csv
-- Purpose:
-- - Profile the raw labor_entries dataset before cleaning and transformation.
-- - Identify schema, completeness, uniqueness, categorical, date, numeric,
--   and relationship issues that could affect the analysis.
-- Notes:
-- - Preserve the original investigation numbering from the combined profiling file.
-- - Preserve raw source values; document cleaning decisions separately.
-- - Reporting cutoff: 2026-06-30.
--
-- Investigation 28: Inspect labor_entries.csv schema and sample rows
-- Purpose:
-- - Identify the file's columns, DuckDB-inferred data types, representative values,
--   and apparent row grain before selecting fields for deeper profiling.
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - labor_entries.csv contains nine columns covering time-entry identification,
--   project and employee references, work date, trade, labor hours, hourly rate,
--   and recorded labor cost.
-- - time_entry_id appears to be the candidate row identifier, but its uniqueness
--   has not yet been validated.
-- - The apparent grain is one recorded labor entry for one employee on one project
--   and work date.
-- - work_date is inferred as VARCHAR even though the sampled values resemble ISO
--   dates, so date parseability and formatting require further investigation.
-- - regular_hours, overtime_hours, hourly_rate, and labor_cost are the primary
--   numeric fields requiring range, precision, and calculation-consistency checks.


-- Investigation 29: Validate time_entry_id as the intended row-level identifier
-- Purpose:
-- - Compare total rows, non-NULL time_entry_id values, and distinct time_entry_id
--   values to determine whether every labor entry has a complete and unique identifier.
SELECT
    COUNT(*) AS total_rows,
    COUNT(time_entry_id) AS non_null_time_entry_ids,
    COUNT(DISTINCT time_entry_id) AS distinct_time_entry_ids
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - All 18,004 rows contain a non-NULL time_entry_id.
-- - Only 18,003 time_entry_id values are distinct.
-- - Therefore, one identifier occurs one additional time and requires investigation
--   before time_entry_id can be accepted as the row-level identifier.


-- Investigation 29A: Identify and inspect the repeated time_entry_id
-- Purpose:
-- - Identify the repeated time_entry_id and inspect its associated rows to determine
--   whether they are exact duplicates or different labor entries sharing the same identifier.
SELECT
    time_entry_id,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/labor_entries.csv')
GROUP BY time_entry_id
HAVING COUNT(*) > 1;

-- Findings:
-- - time_entry_id TE000222 occurs twice.
-- - The associated rows must be inspected to determine whether they are exact
--   duplicates or different labor entries sharing the same identifier.


-- Investigation 29B: Inspect rows associated with time_entry_id TE000222
-- Purpose:
-- - Determine whether the two rows are exact duplicates or different labor
--   entries that incorrectly share the same identifier.
SELECT *
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE time_entry_id = 'TE000222';

-- Findings:
-- - The two rows associated with time_entry_id TE000222 are exact duplicates
--   across all nine columns.
-- - After removing one duplicate occurrence, time_entry_id is complete and unique
--   across the remaining 18,003 labor-entry records.
--
-- Cleaning decision:
-- - Preserve the raw data unchanged.
-- - Retain one TE000222 row in the cleaned analytical layer and use time_entry_id
--   as the row-level identifier.


-- Investigation 30: Profile completeness across all nine labor_entries.csv columns
-- Purpose:
-- - Count missing values across every column, including NULLs and, for text
--   columns, empty or whitespace-only strings.
-- - Identify incomplete records that may require investigation before analysis.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
    WHERE time_entry_id IS NULL
) AS null_time_entry_id_count,

COUNT(*) FILTER (
    WHERE TRIM(time_entry_id) = ''
) AS blank_time_entry_id_count,

COUNT(*) FILTER (
    WHERE project_id IS NULL
) AS null_project_id_count,

COUNT(*) FILTER (
    WHERE TRIM(project_id) = ''
) AS blank_project_id_count,

COUNT(*) FILTER (
    WHERE work_date IS NULL
) AS null_work_date_count,

COUNT(*) FILTER (
    WHERE TRIM(work_date) = ''
) AS blank_work_date_count,

COUNT(*) FILTER (
    WHERE employee_id IS NULL
) AS null_employee_id_count,

COUNT(*) FILTER (
    WHERE TRIM(employee_id) = ''
) AS blank_employee_id_count,

COUNT(*) FILTER (
    WHERE trade IS NULL
) AS null_trade_count,

COUNT(*) FILTER (
    WHERE TRIM(trade) = ''
) AS blank_trade_count,

COUNT(*) FILTER (
    WHERE regular_hours IS NULL
) AS null_regular_hours_count,

COUNT(*) FILTER (
    WHERE overtime_hours IS NULL
) AS null_overtime_hours_count,

COUNT(*) FILTER (
    WHERE hourly_rate IS NULL
) AS null_hourly_rate_count,

COUNT(*) FILTER (
    WHERE labor_cost IS NULL
) AS null_labor_cost_count
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - All text fields contain values; there are no NULL, empty,
--   or whitespace-only strings.
-- - All numeric fields are complete except for one NULL hourly_rate.
-- - labor_cost is present for every row, including the row with the missing
--   hourly_rate.


-- Investigation 30A: Inspect the row with a NULL hourly_rate
-- Purpose:
-- - Inspect all other values in the affected row to understand its context,
--   assess the impact on labor_cost validation, and determine whether there is
--   evidence for a defensible correction.
SELECT *
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE hourly_rate IS NULL;

-- Findings:
-- - TE001843 is the only row affected by a NULL hourly_rate.
-- - The entry belongs to employee E115, project P008, and the Carpenter trade,
--   with a work_date of 2024-03-22.
-- - The row records 43.57 regular hours, zero overtime hours, and labor_cost
--   of 1697.49.
-- - The recorded hours and labor_cost allow an implied hourly rate to be
--   calculated, but employee history is needed to corroborate any correction.


-- Investigation 30B: Evaluate a correction for the missing hourly_rate
-- Purpose:
-- - Calculate the implied hourly_rate from TE001843's regular_hours and
--   labor_cost, then compare it with E115's other recorded rates—especially
--   around the same work_date—to determine whether a correction is supported
--   by consistent evidence.
WITH columns AS (
    SELECT
        time_entry_id,
        employee_id,
        work_date,
        regular_hours,
        labor_cost,
        ROUND(labor_cost / regular_hours, 2) AS calculated_hourly_rate
    FROM read_csv_auto('data/raw/labor_entries.csv')
    WHERE time_entry_id = 'TE001843'
)
SELECT
    time_entry_id,
        employee_id,
        work_date,
        regular_hours,
        labor_cost,
        calculated_hourly_rate,
        ROUND(calculated_hourly_rate * regular_hours, 2) AS calculated_labor_cost_check
FROM columns;

-- Calculation findings:
-- - Dividing labor_cost by regular_hours produces an implied hourly_rate of
--   38.96 for TE001843.
-- - Multiplying 38.96 by 43.57 regular hours reproduces the recorded labor_cost
--   of 1697.49 after rounding to two decimal places.
-- - This confirms that 38.96 is internally consistent with the row, but it does
--   not by itself prove the intended rate; E115's history must provide
--   corroborating evidence.


SELECT
    hourly_rate,
    MIN(work_date) AS first_work_date,
    MAX(work_date) AS last_work_date,
    COUNT(*) AS entry_count
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE employee_id = 'E115'
GROUP BY hourly_rate
ORDER BY first_work_date;

-- Findings:
-- - Employee E115 does not have a stable hourly rate; the employee has many
--   distinct rates across the recorded history.
-- - The target rate of 38.96 appears only once in E115's recorded history.
-- - That occurrence is dated 2026-02-09, whereas the missing rate is from
--   2024-03-22.
-- - Several different rates occur around March 22, 2024, so nearby employee
--   records do not identify one obvious rate.
-- - Therefore, E115's history does not corroborate 38.96 for TE001843, and the
--   missing value should not be filled based on employee history.
-- - Despite the lack of historical corroboration, 38.96 remains internally
--   consistent because it reproduces the recorded labor_cost from regular_hours.
--
-- Decision for 30B:
-- - Defer the correction until dataset-wide labor_cost formula validation
--   determines whether reverse calculation provides sufficient evidence.


-- Investigation 31: Validate work_date format and DATE parseability
-- Purpose:
-- - Test whether every nonmissing work_date can convert to DATE.
-- - Identify and inspect any values that fail conversion.
-- - Determine the cleaning rule required before date-range
--   and reporting-cutoff analysis.
SELECT
    COUNT(*) AS total_rows,
    COUNT(work_date) AS non_null_work_dates,
    COUNT(*) FILTER (
        WHERE TRY_CAST(work_date AS DATE) IS NOT NULL
    ) AS parseable_work_dates,
    COUNT(*) FILTER (
        WHERE work_date IS NOT NULL
          AND TRY_CAST(work_date AS DATE) IS NULL
    ) AS unparseable_work_dates
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - All 18,004 rows have a work_date.
-- - 18,003 values convert successfully to DATE.
-- - Exactly one nonmissing value fails conversion.
-- - That single malformed value is likely why DuckDB inferred the entire
--   column as VARCHAR.
-- - Further inspection is required before determining the cleaning rule.


-- Investigation 31A: Inspect the unparseable work_date
-- Purpose:
-- - Inspect the raw work_date and its associated row to identify the formatting
--   problem and determine whether a defensible correction can be made.
SELECT *
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE work_date IS NOT NULL
  AND TRY_CAST(work_date AS DATE) IS NULL;

-- Findings:
-- - The unparseable work_date belongs to time_entry_id TE002542 and project_id
--   P013.
-- - Its raw value is 5/19/2023, which uses M/D/YYYY formatting.
-- - The value unambiguously represents May 19, 2023 because 19 cannot be a month.
--
-- Cleaning decision:
-- - Preserve the raw CSV unchanged.
-- - In the cleaned analytical layer, parse the M/D/YYYY variant and store the
--   work_date as the DATE value 2023-05-19.


-- Investigation 31B: Validate the proposed work_date parsing rule across all rows
-- Purpose:
-- - Apply the standard DATE conversion first and the M/D/YYYY parser as a
--   fallback, then confirm that every work_date converts successfully without
--   creating additional NULL values.
WITH parsed_dates AS (
    SELECT
        work_date,
        COALESCE(
            TRY_CAST(work_date AS DATE),
            CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
        ) AS standardized_work_date
    FROM read_csv_auto('data/raw/labor_entries.csv')
)
SELECT
    COUNT(*) AS total_rows,
    COUNT(work_date) AS non_null_work_dates,
    COUNT(standardized_work_date) AS successfully_parsed_work_dates,
    COUNT(*) FILTER (
        WHERE work_date IS NOT NULL
          AND standardized_work_date IS NULL
    ) AS unparseable_work_dates
FROM parsed_dates;

-- Findings:
-- - All 18,004 work_date values successfully parse as DATE using the proposed
--   standard-plus-fallback rule.
-- - Zero work_date values remain unparseable.
--
-- Cleaning decision:
-- - Preserve the raw values unchanged.
-- - Apply the validated parsing rule in cleaned_labor_entries and store
--   standardized_work_date as DATE.


-- Investigation 31C: Validate the standardized work_date range and reporting cutoff
-- Purpose:
-- - Calculate the earliest and latest standardized work_date and count entries
--   after the June 30, 2026 reporting cutoff to identify any implausible or
--   out-of-scope labor records.
WITH parsed_dates AS (
    SELECT
        work_date,
        COALESCE(
            TRY_CAST(work_date AS DATE),
            CAST(TRY_STRPTIME(work_date, '%m/%d/%Y') AS DATE)
        ) AS standardized_work_date
    FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    MIN(standardized_work_date) AS earliest_work_date,
    MAX(standardized_work_date) AS latest_work_date,
    COUNT(*) FILTER(
        WHERE standardized_work_date > DATE '2026-06-30'
    ) AS entries_after_cutoff
FROM parsed_dates;

-- Findings:
-- - The standardized work_date range is 2023-01-28 through 2026-06-30.
-- - The latest work_date is exactly the reporting cutoff.
-- - Zero labor entries occur after the June 30, 2026 reporting cutoff.
--
-- Decision:
-- - Retain all labor entries in the reporting period; no date-based exclusions
--   are required.


-- Investigation 32: Profile numeric ranges for all four labor fields
-- Purpose:
-- - Measure the minimum and maximum values and count zero and negative values
--   for regular_hours, overtime_hours, hourly_rate, and labor_cost.
-- - Identify potentially unreasonable values requiring further investigation
--   before evaluating numeric precision and labor-cost calculation consistency.
SELECT
    MIN(regular_hours) AS minimum_regular_hours,
    MAX(regular_hours) AS maximum_regular_hours,
    COUNT(*) FILTER (WHERE regular_hours = 0) AS regular_hour_zero_count,
    COUNT(*) FILTER (WHERE regular_hours < 0) AS regular_hour_negative_count,
    MIN(overtime_hours) AS minimum_overtime_hours,
    MAX(overtime_hours) AS maximum_overtime_hours,
    COUNT(*) FILTER (WHERE overtime_hours = 0) AS overtime_hours_zero_count,
    COUNT(*) FILTER (WHERE overtime_hours < 0) AS overtime_hours_negative_count,
    MIN(hourly_rate) AS minimum_hourly_rate,
    MAX(hourly_rate) AS maximum_hourly_rate,
    COUNT(*) FILTER (WHERE hourly_rate = 0) AS hourly_rate_zero_count,
    COUNT(*) FILTER (WHERE hourly_rate < 0) AS hourly_rate_negative_count,
    MIN(labor_cost) AS minimum_labor_cost,
    MAX(labor_cost) AS maximum_labor_cost,
    COUNT(*) FILTER (WHERE labor_cost = 0) AS labor_cost_zero_count,
    COUNT(*) FILTER (WHERE labor_cost < 0) AS labor_cost_negative_count
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - regular_hours ranged from 0.0973 to 46, with no zero or negative values.
-- - overtime_hours ranged from 0 to 9; 14,033 entries recorded zero overtime,
--   and no negative values were present.
-- - Among non-NULL values, hourly_rate ranged from 27 to 68, with no zero or
--   negative values.
-- - labor_cost ranged from 5.80 to 3,822.02, with no zero or negative values.
-- - The minimum and maximum regular_hours and labor_cost values require
--   row-level inspection before their reasonableness can be determined.
--
-- Decision:
-- - Inspect the complete records associated with these numeric extremes in
--   Investigation 32A before evaluating precision and labor-cost consistency.


-- Investigation 32A: Inspect records associated with numeric extremes
-- Purpose:
-- - Retrieve complete records matching the observed minimum and maximum
--   regular_hours values (0.0973 and 46) and labor_cost values (5.80 and 3,822.02).
-- - Compare their identifiers, dates, hours, rates, and costs to determine whether
--   the flagged extremes are internally consistent or require further investigation.
WITH labor_data AS (
    SELECT *
    FROM read_csv_auto('data/raw/labor_entries.csv')
),

extremes AS (
    SELECT
        MIN(regular_hours) AS minimum_regular_hours,
        MAX(regular_hours) AS maximum_regular_hours,
        MIN(labor_cost) AS minimum_labor_cost,
        MAX(labor_cost) AS maximum_labor_cost
    FROM labor_data
)

SELECT labor_data.*
FROM labor_data
CROSS JOIN extremes
WHERE labor_data.regular_hours = extremes.minimum_regular_hours
    OR labor_data.regular_hours = extremes.maximum_regular_hours
    OR labor_data.labor_cost = extremes.minimum_labor_cost
    OR labor_data.labor_cost = extremes.maximum_labor_cost;

-- Findings:
-- - Six rows were returned because four entries tied at the maximum of
--   46 regular hours.
-- - TE014656 contained both minimum values. Multiplying 0.0973 hours by
--   its 59.64 hourly rate produces 5.802972, which rounds to 5.80.
-- - TE011416's regular and overtime pay calculation produces 3,822.0216,
--   which rounds to its recorded labor cost of 3,822.02.
-- - All four 46-hour entries recorded zero overtime. Their treatment remains
--   unresolved because E312 also has an entry with recorded overtime.
--
-- Decision:
-- - Retain the flagged values unchanged pending further investigation.
-- - In Investigation 32B, quantify entries above 40 regular hours and compare
--   the occurrence of zero and positive overtime.


-- Investigation 32B: Quantify entries above 40 regular hours and compare
-- zero and positive overtime
-- Purpose:
-- - Count entries with more than 40 regular hours and categorize them by
--   whether overtime_hours is zero or positive.
-- - Determine whether the zero-overtime pattern among high-hour entries is
--   isolated or widespread before evaluating its validity.
SELECT
    COUNT(*) FILTER (
        WHERE regular_hours > 40
    ) AS regular_hours_over_40_count,
    COUNT(*) FILTER (
        WHERE regular_hours > 40
          AND overtime_hours = 0
    ) AS over_40_zero_overtime_count,
    COUNT(*) FILTER (
        WHERE regular_hours > 40
          AND overtime_hours > 0
    ) AS over_40_positive_overtime_count
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - 6,727 entries recorded more than 40 regular hours.
-- - Of those entries, 5,178 (76.97%) recorded zero overtime and
--   1,549 (23.03%) recorded positive overtime.
-- - The two overtime categories reconcile to the complete population of
--   entries above 40 regular hours.
-- - High regular hours combined with zero overtime are widespread and are
--   not isolated to the four entries at the 46-hour maximum.
-- - The available fields do not explain the time period represented by each
--   entry or the business rules governing regular and overtime classification.
--
-- Decision:
-- - Do not reclassify hours or alter labor costs without an authoritative
--   business rule from the data owner.
-- - Retain the recorded values unchanged and document the classification
--   ambiguity as a data limitation requiring stakeholder clarification.
-- - Continue with numeric-precision and labor-cost calculation-consistency
--   profiling.


-- Investigation 33: Assess numeric precision across labor fields
-- Purpose:
-- - Determine whether regular_hours, overtime_hours, hourly_rate, and labor_cost
--   contain meaningful precision beyond two decimal places.
-- - Count non-NULL values that differ from their two-decimal rounded equivalents.
-- - Use the results to select cleaned numeric types without introducing
--   unintended rounding or loss of source precision.
SELECT
    COUNT(*) FILTER (
    WHERE regular_hours IS NOT NULL
      AND regular_hours <> ROUND(regular_hours, 2)
) AS regular_hours_changed_at_2dp_count,
        COUNT(*) FILTER (
        WHERE overtime_hours IS NOT NULL
        AND overtime_hours <> ROUND(overtime_hours, 2)
    ) AS overtime_hours_changed_at_2dp_count,
        COUNT(*) FILTER (
        WHERE hourly_rate IS NOT NULL
        AND hourly_rate <> ROUND(hourly_rate, 2)
    ) AS hourly_rate_changed_at_2dp_count,
        COUNT(*) FILTER (
        WHERE labor_cost IS NOT NULL
        AND labor_cost <> ROUND(labor_cost, 2)
    ) AS labor_cost_changed_at_2dp_count
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - Rounding regular_hours to two decimal places would alter 94 values.
-- - Rounding overtime_hours, hourly_rate, and labor_cost to two decimal
--   places would alter zero non-NULL values.
-- - Two-decimal scale preserves the observed source precision of
--   overtime_hours, hourly_rate, and labor_cost.
-- - Two-decimal scale is insufficient to preserve all regular_hours values.
--
-- Decision:
-- - Use two decimal places as the required scale for overtime_hours,
--   hourly_rate, and labor_cost; determine total DECIMAL precision separately
--   when cleaned numeric types are finalized.
-- - Do not round regular_hours to two decimal places.
-- - Continue with Investigation 33A to determine the minimum scale that
--   preserves every regular_hours value.


-- Investigation 33A: Determine the minimum scale required for regular_hours
-- Purpose:
-- - Identify the smallest number of decimal places that preserves every
--   non-NULL regular_hours value without rounding or loss of source precision.
-- - Compare values at three- and four-decimal scales and test additional
--   scales only if four decimal places remain insufficient.
SELECT
    COUNT(*) FILTER (
    WHERE regular_hours IS NOT NULL
      AND regular_hours <> ROUND(regular_hours, 3)
) AS regular_hours_changed_at_3dp_count,
    COUNT(*) FILTER (
    WHERE regular_hours IS NOT NULL
      AND regular_hours <> ROUND(regular_hours, 4)
) AS regular_hours_changed_at_4dp_count
FROM read_csv_auto('data/raw/labor_entries.csv');

-- Findings:
-- - Rounding regular_hours to three decimal places would alter 82 non-NULL
--   values.
-- - Rounding regular_hours to four decimal places would alter zero values.
-- - Four decimal places are therefore the minimum scale required to preserve
--   every observed regular_hours value.
--
-- Decision:
-- - Preserve regular_hours at four-decimal scale in the cleaned analytical
--   layer.
-- - Do not round regular_hours to two or three decimal places.
-- - Select a cleaned DECIMAL type with a scale of four; determine its total
--   precision when the cleaned schema is implemented.


-- Investigation 34: Validate the dataset-wide labor_cost calculation relationship
-- Purpose:
-- - Calculate expected labor_cost as regular pay plus overtime pay at 1.5 times
--   the hourly rate, rounded to two decimal places.
-- - Compare calculated labor costs with recorded labor_cost values across all
--   rows containing a non-NULL hourly_rate.
-- - Count testable, untestable, matching, and mismatching rows.
-- - Determine whether the relationship is consistent enough to support
--   reverse-calculating TE001843's missing hourly_rate.
WITH labor_cost_check AS (
    SELECT
        *,
        ROUND(
            (regular_hours * hourly_rate)
            + (overtime_hours * hourly_rate * 1.5),
            2
        ) AS expected_labor_cost
    FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    COUNT(*) AS total_row_count,
    COUNT(*) FILTER (
        WHERE hourly_rate IS NOT NULL
    ) AS testable_row_count,
    COUNT(*) FILTER (
        WHERE hourly_rate IS NULL
    ) AS untestable_row_count,
    COUNT(*) FILTER (
        WHERE expected_labor_cost = labor_cost
    ) AS matching_rows,
    COUNT(*) FILTER (
        WHERE expected_labor_cost <> labor_cost
    ) AS mismatch_rows
FROM labor_cost_check;

-- Findings:
-- - Of 18,004 labor rows, 18,003 were testable and one was untestable because
--   hourly_rate was NULL.
-- - The candidate labor-cost formula matched 17,850 testable rows (99.15%)
--   and mismatched 153 rows (0.85%).
-- - The formula is highly consistent but not universal across the dataset.
-- - The mismatches must be characterized before determining whether the
--   formula reliably supports reverse-calculating TE001843's missing rate.
--
-- Decision:
-- - Do not resolve TE001843's missing hourly_rate yet.
-- - Continue with Investigation 34A to measure the size and direction of the
--   153 cost differences and determine whether they follow a rounding pattern.


-- Investigation 34A: Characterize labor_cost formula mismatches
-- Purpose:
-- - Isolate testable rows where expected labor_cost differs from recorded
--   labor_cost.
-- - Calculate each difference as recorded labor_cost minus expected labor_cost.
-- - Summarize the minimum, maximum, direction, and frequency of the differences.
-- - Determine whether the mismatches reflect a consistent rounding pattern or
--   potentially substantive calculation differences.
WITH labor_cost_check AS (
    SELECT
        *,
        ROUND(
            (regular_hours * hourly_rate)
            + (overtime_hours * hourly_rate * 1.5),
            2
        ) AS expected_labor_cost
    FROM read_csv_auto('data/raw/labor_entries.csv')
),

mismatch_labor_cost AS (
    SELECT *
    FROM labor_cost_check
    WHERE expected_labor_cost <> labor_cost
)

SELECT
    ROUND(labor_cost - expected_labor_cost, 2) AS cost_difference,
    COUNT(*) AS mismatch_count
FROM mismatch_labor_cost
GROUP BY cost_difference
ORDER BY cost_difference;

-- Findings:
-- - The 153 formula mismatches ranged from -0.01 to 125.00.
-- - For 152 rows, recorded labor_cost was 0.01 lower than expected labor_cost.
-- - One row recorded labor_cost 125.00 higher than expected labor_cost.
-- - The one-cent differences may reflect an alternative rounding sequence,
--   but this has not yet been confirmed.
--
-- Decision:
-- - Do not alter any recorded labor_cost values during standardization.
-- - Inspect the 125.00 outlier in Investigation 34B.
-- - Test an alternative component-rounding formula for the 152 one-cent
--   differences in a subsequent follow-up.


-- Investigation 34B: Inspect the $125 labor-cost mismatch
-- Purpose:
-- - Retrieve the complete labor entry whose recorded labor_cost exceeds the
--   expected labor_cost by 125.00.
-- - Compare its regular hours, overtime hours, hourly rate, calculated pay
--   components, and recorded labor cost.
-- - Determine whether the difference is explainable, represents a data-quality
--   issue, or requires stakeholder clarification before any correction.
WITH labor_cost_check AS (
    SELECT
        *,
        ROUND(
            (regular_hours * hourly_rate)
            + (overtime_hours * hourly_rate * 1.5),
            2
        ) AS expected_labor_cost
    FROM read_csv_auto('data/raw/labor_entries.csv')
)
SELECT
    *
FROM labor_cost_check
WHERE ROUND(labor_cost - expected_labor_cost, 2) = 125;

-- Findings:
-- - TE003191 is the only row whose recorded labor_cost exceeds expected
--   labor_cost by 125.00.
-- - Its 30.26 regular hours multiplied by its 46.46 hourly rate produces
--   1,405.8796, which rounds to the expected cost of 1,405.88.
-- - The recorded labor_cost is 1,530.88, exactly 125.00 higher.
-- - The row records zero overtime, and its hours and hourly rate fall within
--   the observed dataset ranges.
-- - No available field explains the additional 125.00.
--
-- Decision:
-- - Retain TE003191 unchanged and flag the 125.00 difference for stakeholder
--   clarification rather than assuming an adjustment or correcting the row.
-- - Treat TE003191 as an unresolved exception to the labor-cost formula.
-- - Continue by testing whether alternative component rounding explains the
--   remaining 152 one-cent mismatches.


-- Investigation 34C: Test component-level rounding for one-cent mismatches
-- Purpose:
-- - Calculate expected labor_cost by rounding regular pay and overtime pay
--   separately to two decimal places before adding them.
-- - Compare the component-rounded result with recorded labor_cost across all
--   testable rows, including the 152 one-cent mismatches.
-- - Determine whether component-level rounding resolves those differences
--   without creating new mismatches and provides a more reliable dataset-wide
--   calculation rule.
WITH component_rounding_check AS (
    SELECT
        hourly_rate,
        labor_cost,
        ROUND(
            ROUND(regular_hours * hourly_rate, 2)
            + ROUND(overtime_hours * hourly_rate * 1.5, 2),
            2
        ) AS expected_component_labor_cost
    FROM read_csv_auto('data/raw/labor_entries.csv')
)

SELECT
    COUNT(*) AS testable_row_count,
    COUNT(*) FILTER (
        WHERE labor_cost = expected_component_labor_cost
    ) AS matching_row_count,
    COUNT(*) FILTER (
        WHERE labor_cost <> expected_component_labor_cost
    ) AS mismatching_row_count
FROM component_rounding_check
WHERE hourly_rate IS NOT NULL;

-- Findings:
-- - The component-level rounding formula was testable for 18,003 rows.
-- - It matched 16,957 rows (94.19%) and mismatched 1,046 rows (5.81%).
-- - The combined-total formula performed better, matching 17,850 rows (99.15%)
--   and mismatching only 153 rows (0.85%).
-- - Component-level rounding increased the mismatch count by 893 rows and
--   therefore does not provide a more reliable dataset-wide calculation rule.
-- - These aggregate counts do not reveal whether component rounding resolved
--   any of the original 152 one-cent differences while creating mismatches
--   elsewhere.
--
-- Decision:
-- - Reject component-level rounding as the primary dataset-wide labor-cost
--   calculation rule.
-- - Retain combined-total rounding as the better-supported candidate formula.
-- - Do not yet conclude that component rounding explains the 152 one-cent
--   differences.
-- - Compare both formula outcomes at the row level in Investigation 34D before
--   resolving the remaining calculation pattern or TE001843's missing rate.


-- Investigation 34D: Compare labor-cost formula outcomes by row
-- Purpose:
-- - Compare the combined-total and component-level labor-cost formulas
--   for every testable labor entry.
-- - Classify each row as matching both formulas, the combined-total formula
--   only, the component-level formula only, or neither formula.
-- - Determine whether component-level rounding reproduces the recorded
--   labor cost for the 152 one-cent combined-total mismatches.
-- - Quantify how many rows that match the combined-total formula become
--   mismatches when component-level rounding is applied.
-- - Use the overlap results to confirm which formula is better supported
--   as the primary labor-cost calculation.
WITH formula_comparison AS (
SELECT
    labor_cost,
    ROUND(
    ROUND(regular_hours * hourly_rate, 2)
    + ROUND(overtime_hours * hourly_rate * 1.5, 2),
    2) AS component_level,
    ROUND(
        (regular_hours * hourly_rate)
        + (overtime_hours * hourly_rate * 1.5),
        2) AS combined_total
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE hourly_rate IS NOT NULL
)

SELECT
    COUNT(*) AS testable_rows,

    COUNT(*) FILTER (
        WHERE component_level = labor_cost
          AND combined_total = labor_cost
    ) AS matches_both,

    COUNT(*) FILTER (
        WHERE combined_total = labor_cost
          AND component_level <> labor_cost
    ) AS combined_total_only,

    COUNT(*) FILTER (
        WHERE component_level = labor_cost
          AND combined_total <> labor_cost
    ) AS component_level_only,

    COUNT(*) FILTER (
        WHERE component_level <> labor_cost
          AND combined_total <> labor_cost
    ) AS neither_match

FROM formula_comparison;

-- Findings:
-- - All four categories account for the 18,003 testable rows.
-- - 16,948 rows match both formulas.
-- - 902 rows match only the combined-total formula.
-- - 9 rows match only the component-level formula.
-- - 144 rows match neither formula.
-- - Combined-total matches 17,850 rows, compared with 16,957 rows
--   for component-level rounding.
-- - Component-level rounding fixes only 9 combined-total mismatches
--   but creates 902 new mismatches, producing 893 fewer matches overall.
-- - Therefore, combined-total remains the better-supported primary
--   labor-cost validation formula.


-- Investigation 34E: Characterize component-level-only and neither-match rows
-- Purpose:
-- - Inspect the 9 component-level-only rows and the 144 rows that match
--   neither formula by comparing their recorded and expected labor costs.
-- - Determine whether the component-level-only rows explain one-cent
--   combined-total differences.
-- - Verify whether the neither-match rows consist of the remaining one-cent
--   differences plus TE003191's unexplained $125.00 difference.
WITH formula_comparison AS (
    SELECT
        time_entry_id,
        regular_hours,
        overtime_hours,
        hourly_rate,
        labor_cost,
        ROUND(
        ROUND(regular_hours * hourly_rate, 2)
        + ROUND(overtime_hours * hourly_rate * 1.5, 2),
        2) AS component_level,
        ROUND(
        (regular_hours * hourly_rate)
        + (overtime_hours * hourly_rate * 1.5),
        2) AS combined_total
    FROM read_csv_auto('data/raw/labor_entries.csv')
    WHERE hourly_rate IS NOT NULL
),

outcome_classification AS (
    SELECT
        time_entry_id,
        regular_hours,
        overtime_hours,
        hourly_rate,
        labor_cost,
        component_level,
        combined_total,

        ROUND(labor_cost - combined_total, 2)
            AS combined_total_difference,

        ROUND(labor_cost - component_level, 2)
            AS component_level_difference,

        CASE
            WHEN component_level = labor_cost
             AND combined_total = labor_cost
                THEN 'matches_both'

            WHEN combined_total = labor_cost
             AND component_level <> labor_cost
                THEN 'combined_total_only'

            WHEN component_level = labor_cost
             AND combined_total <> labor_cost
                THEN 'component_level_only'

            WHEN component_level <> labor_cost
             AND combined_total <> labor_cost
                THEN 'neither_match'
        END AS formula_outcome
    FROM formula_comparison
)

SELECT
    time_entry_id,
    regular_hours,
    overtime_hours,
    hourly_rate,
    labor_cost,
    combined_total,
    component_level,
    combined_total_difference,
    component_level_difference,
    formula_outcome
FROM outcome_classification
WHERE formula_outcome IN (
    'component_level_only',
    'neither_match'
)
ORDER BY
    ABS(combined_total_difference) DESC,
    formula_outcome,
    time_entry_id;

-- Findings:
-- - The inspection returned 153 rows: 9 component-level-only rows
--   and 144 rows that match neither formula.
-- - All 9 component-level-only rows contain overtime hours.
-- - For those 9 rows, combined-total is $0.01 higher than the recorded
--   labor cost, while component-level rounding reproduces it exactly.
-- - Of the 144 neither-match rows, 143 have both formulas producing
--   the same result, $0.01 above the recorded labor cost.
-- - TE003191 is the remaining neither-match row; both formulas produce
--   $1,405.88, which is $125.00 below its recorded labor cost of $1,530.88.
-- - Component-level rounding therefore explains only 9 of the 152
--   one-cent combined-total differences, or 5.92%.
-- - The remaining 143 one-cent differences, or 94.08%, are not explained
--   by either tested rounding method.
-- - These results reinforce combined-total rounding as the better-supported
--   primary labor-cost validation formula.


-- Investigation 35: Evaluate formula-based imputation for TE001843
-- Purpose:
-- - Test whether $38.96 reproduces TE001843's recorded labor cost
--   using the combined-total formula.
-- - Determine whether $38.96 is the only two-decimal rate within
--   the observed $27.00–$68.00 range that produces the recorded cost.
-- - Use the result to decide whether to leave the missing rate unresolved
--   or impute $38.96 in the cleaned output while preserving the raw NULL.
WITH target_entry AS (
    SELECT
        time_entry_id,
        regular_hours,
        overtime_hours,
        labor_cost
    FROM read_csv_auto('data/raw/labor_entries.csv')
    WHERE time_entry_id = 'TE001843'
),

candidate_rates AS (
    SELECT
        candidate_rate_cents / 100.0 AS candidate_hourly_rate
    FROM range(2700, 6801)
        AS generated_rates(candidate_rate_cents)
),

candidate_costs AS (
    SELECT
        time_entry_id,
        regular_hours,
        overtime_hours,
        candidate_hourly_rate,
        labor_cost,
        ROUND(
            (regular_hours * candidate_hourly_rate)
            + (overtime_hours * candidate_hourly_rate * 1.5),
            2
        ) AS expected_labor_cost
    FROM target_entry
    CROSS JOIN candidate_rates
),

matching_candidates AS (
    SELECT *
    FROM candidate_costs
    WHERE expected_labor_cost = labor_cost
)

SELECT
    COUNT(*) OVER () AS matching_candidate_count,
    time_entry_id,
    regular_hours,
    overtime_hours,
    candidate_hourly_rate,
    labor_cost,
    expected_labor_cost
FROM matching_candidates
ORDER BY candidate_hourly_rate;

-- Findings:
-- - TE001843 has 43.57 regular hours, zero overtime hours, a recorded
--   labor cost of $1,697.49, and a missing hourly rate.
-- - Testing every two-decimal hourly rate from $27.00 through $68.00
--   produced one matching candidate.
-- - An hourly rate of $38.96 reproduces the recorded labor cost exactly
--   under the combined-total formula.
-- - No other two-decimal rate within the observed range produces the
--   recorded labor cost.
-- - The result supports imputing $38.96 as the hourly rate in the cleaned
--   output while preserving the raw NULL and flagging the value as imputed.
-- - Because the rate is derived from the recorded hours and labor cost,
--   it should be treated as a formula-based estimate rather than a
--   confirmed original payroll rate.


-- Investigation 36: Profile trade values and frequencies
-- Purpose:
-- - Identify the distinct trade values and their row counts.
-- - Detect capitalization, spelling, or whitespace inconsistencies that
--   could split equivalent trades into separate categories.
-- - Determine whether trade values require standardization in the
--   cleaned output.
SELECT
    trade,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/labor_entries.csv')
GROUP BY trade
ORDER BY row_count DESC;

-- Findings:
-- - The dataset contains 6 distinct raw trade values.
-- - Four consistently formatted, high-frequency trade values account
--   for 18,002 of the 18,004 rows.
-- - The value 'carpenter ' occurs once and is a confirmed formatting
--   variant of 'Carpenter' due to lowercase text and trailing whitespace.
-- - The value 'General Labor' also occurs once and may represent a
--   semantic variant of 'Laborer'.
-- - The 'General Labor' row requires contextual inspection before a
--   cleaning rule is established.


-- Investigation 36A: Inspect unusual trade values
-- Purpose:
-- - Inspect the complete labor entries associated with the one-row
--   'carpenter ' and 'General Labor' trade values.
-- - Confirm whether 'carpenter ' should be standardized to 'Carpenter'.
-- - Gather contextual evidence to determine whether 'General Labor'
--   should be standardized to an established trade category.
SELECT *
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE trade = 'General Labor'
   OR (
        LOWER(TRIM(trade)) = 'carpenter'
        AND trade <> 'Carpenter' );

-- Findings:
-- - TE000917 contains the one-row 'carpenter ' formatting variant,
--   which differs from 'Carpenter' by capitalization and trailing whitespace.
-- - The cleaned output should standardize TE000917's trade value
--   to 'Carpenter' while preserving the raw source value unchanged.
-- - TE001216 is the only row containing the trade value 'General Labor'.
-- - The row itself does not provide sufficient evidence to determine
--   whether 'General Labor' should be standardized to 'Laborer'.
-- - E401's trade history requires further investigation before a
--   cleaning decision is established for 'General Labor'.

-- Investigation 36B: Inspect E401's trade history
-- Purpose:
-- - Review all raw trade values recorded for employee E401.
-- - Determine whether the one-row General Labor value is inconsistent
--   with an otherwise established Laborer history.
-- - Use the employee-level evidence to decide whether General Labor
--   should be standardized to Laborer or remain unresolved.
WITH e401_entries AS (
    SELECT *
    FROM read_csv_auto('data/raw/labor_entries.csv')
    WHERE employee_id = 'E401'
)
SELECT
    trade,
    COUNT(*) AS row_count
FROM e401_entries
GROUP BY trade
ORDER BY row_count DESC;

-- Findings:
-- - E401 has 948 entries recorded as Finisher and one entry recorded
--   as General Labor.
-- - E401 has no entries recorded as Laborer, so the employee's trade
--   history does not support standardizing General Labor to Laborer.
-- - The one General Labor entry may represent a legitimate temporary
--   assignment or a data-quality error; the available evidence cannot
--   distinguish between these explanations.
-- - Preserve TE001216's raw General Labor value and flag the entry as
--   unresolved pending stakeholder clarification.


-- Investigation 37: Profile employee_id values
-- Purpose:
-- - Count the number of distinct employees represented in the dataset.
-- - Determine whether every employee_id follows the expected format
--   of E followed by three digits.
-- - Identify employee IDs with unusually few entries, which could
--   indicate a typo or stray value.
SELECT
    employee_id,
    regexp_full_match(employee_id, '^E[0-9]{3}$')
        AS matches_expected_format,
    COUNT(*) AS entry_count
FROM read_csv_auto('data/raw/labor_entries.csv')
GROUP BY employee_id
ORDER BY entry_count ASC;

-- Findings:
-- - 19 distinct employees.
-- - Every ID matches E followed by exactly three digits.
-- - Entry counts range from 633 to 1,216.
-- - There are no isolated low-frequency values suggesting a typo
--   or stray ID.
-- - No employee_id cleaning or correction rule is required.


-- Investigation 38: Validate labor project IDs
-- Purpose:
-- - Compare the project_id values in labor_entries.csv with the valid
--   project IDs recorded in projects.csv.
-- - Identify labor entries whose project_id does not match an existing
--   project.
-- - Determine whether any labor costs would be excluded from or incorrectly
--   assigned in project-level profitability analysis.
WITH valid_projects AS (
    SELECT DISTINCT project_id
    FROM read_csv_auto('data/raw/projects.csv')
)
SELECT
    l.project_id,
    COUNT(*) AS labor_entry_count
FROM read_csv_auto('data/raw/labor_entries.csv') AS l
LEFT JOIN valid_projects AS p
    ON l.project_id = p.project_id
WHERE p.project_id IS NULL
GROUP BY l.project_id
ORDER BY labor_entry_count DESC;

-- Findings:
-- - One labor entry references project_id P996, which does not exist
--   in the valid project list from projects.csv.
-- - This labor entry cannot yet be assigned reliably in project-level
--   profitability analysis.
-- - Further investigation is required to determine whether P996 can
--   be corrected to an existing project or must remain unresolved.


-- Investigation 38A: Inspect unmatched labor project_id P996
-- Purpose:
-- - Inspect all raw fields for the labor entry referencing P996.
-- - Look for contextual evidence that may identify the intended project_id.
-- - Determine whether P996 can be corrected using available evidence
--   or must remain unresolved.
SELECT *
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE project_id = 'P996';

-- Findings:
-- - TE000408 is the only labor entry referencing P996.
-- - Its employee, trade, hours, hourly rate, and labor cost appear internally
--   plausible, and its recorded labor cost matches the expected formula.
-- - The row itself provides no evidence identifying the intended project_id.
-- - Inspecting neighboring time entries is required before deciding whether
--   P996 can be corrected or must remain unresolved.


-- Investigation 38B: Inspect time entries neighboring TE000408
-- Purpose:
-- - Inspect the project_id pattern in time entries surrounding TE000408.
-- - Determine whether P996 interrupts an otherwise consistent sequence
--   of entries assigned to a single valid project.
-- - Assess whether the neighboring records provide sufficient evidence
--   to correct P996 or whether it must remain unresolved.
SELECT
    time_entry_id,
    project_id,
    work_date,
    employee_id,
    trade
FROM read_csv_auto('data/raw/labor_entries.csv')
WHERE time_entry_id BETWEEN 'TE000403' AND 'TE000413'
ORDER BY time_entry_id;

-- Findings:
-- - TE000408's P996 value interrupts a continuous block of P003 entries:
--   the five neighboring entries before it and the five after it all
--   reference P003.
-- - This pattern provides strong evidence that P996 is an erroneous
--   project_id and that TE000408 was intended to reference P003.
-- - Preserve P996 in the raw data, correct the project_id to P003 in the
--   cleaned output, and flag the record as a source-data correction.


-- Investigation 39: Validate labor dates against project timelines
-- Purpose:
-- - Compare each parsed labor work_date with the associated project's
--   baseline and actual start and completion dates.
-- - Count entries recorded before the baseline or actual start, after the
--   baseline or actual completion, or beyond the reporting cutoff.
-- - Distinguish schedule variance from potential date inconsistencies that
--   require further investigation.
WITH ranked_labor AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY time_entry_id
            ORDER BY time_entry_id
        ) AS duplicate_rank
    FROM read_csv_auto('data/raw/labor_entries.csv')
),
labor_dates AS (
    SELECT
        time_entry_id,
        project_id AS raw_project_id,
        CASE
            WHEN project_id = 'P996' THEN 'P003'
            ELSE project_id
        END AS corrected_project_id,
        TRY_CAST(work_date AS DATE) AS parsed_work_date
    FROM ranked_labor
    WHERE duplicate_rank = 1
),
ranked_projects AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY project_id
            ORDER BY project_id
        ) AS duplicate_rank
    FROM read_csv_auto('data/raw/projects.csv')
),
project_dates AS (
    SELECT
        project_id,
        TRY_CAST(baseline_start_date AS DATE)
            AS parsed_baseline_start_date,
        TRY_CAST(baseline_completion_date AS DATE)
            AS parsed_baseline_completion_date,
        TRY_CAST(actual_start_date AS DATE)
            AS parsed_actual_start_date,
        TRY_CAST(actual_completion_date AS DATE)
            AS parsed_actual_completion_date
    FROM ranked_projects
    WHERE duplicate_rank = 1
),
labor_project_timeline AS (
    SELECT
        ld.time_entry_id,
        ld.raw_project_id,
        ld.corrected_project_id,
        ld.parsed_work_date,
        pd.parsed_baseline_start_date,
        pd.parsed_baseline_completion_date,
        pd.parsed_actual_start_date,
        pd.parsed_actual_completion_date
    FROM labor_dates AS ld
    LEFT JOIN project_dates AS pd
        ON ld.corrected_project_id = pd.project_id
)
SELECT
    COUNT(*) AS total_labor_entries,

    COUNT(*) FILTER (
        WHERE parsed_work_date < parsed_baseline_start_date
    ) AS work_before_baseline_start,

    COUNT(*) FILTER (
        WHERE parsed_work_date < parsed_actual_start_date
    ) AS work_before_actual_start,

    COUNT(*) FILTER (
        WHERE parsed_work_date > parsed_baseline_completion_date
    ) AS work_after_baseline_completion,

    COUNT(*) FILTER (
        WHERE parsed_work_date > parsed_actual_completion_date
    ) AS work_after_actual_completion,

    COUNT(*) FILTER (
        WHERE parsed_work_date > DATE '2026-06-30'
    ) AS work_after_cutoff

FROM labor_project_timeline;

-- Findings:
-- - 18,003 cleaned labor entries were evaluated, confirming that the
--   duplicate time entry was removed.
-- - 52 entries occurred before baseline start, but none occurred before
--   actual start. This suggests legitimate early project starts rather
--   than impossible labor dates.
-- - 2,818 entries occurred after baseline completion, indicating that labor
--   continued beyond planned completion and providing evidence of schedule
--   overruns.
-- - No labor entries occurred after an available actual completion date.
--   Projects with NULL actual completion dates were not testable for this rule.
-- - No labor entries occurred after the June 30, 2026 reporting cutoff.


-- Investigation 39A: Summarize post-baseline labor by project
-- Purpose:
-- - Determine whether the 2,818 labor entries recorded after baseline
--   completion are concentrated in a few projects or distributed broadly.
-- - Measure how far labor activity continued beyond each project's
--   baseline completion date.
WITH ranked_labor AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY time_entry_id
            ORDER BY time_entry_id
        ) AS duplicate_rank
    FROM read_csv_auto('data/raw/labor_entries.csv')
),
labor_dates AS (
    SELECT
        time_entry_id,
        project_id AS raw_project_id,
        CASE
            WHEN project_id = 'P996' THEN 'P003'
            ELSE project_id
        END AS corrected_project_id,
        TRY_CAST(work_date AS DATE) AS parsed_work_date
    FROM ranked_labor
    WHERE duplicate_rank = 1
),
ranked_projects AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY project_id
            ORDER BY project_id
        ) AS duplicate_rank
    FROM read_csv_auto('data/raw/projects.csv')
),
project_dates AS (
    SELECT
        project_id,
        TRY_CAST(baseline_start_date AS DATE)
            AS parsed_baseline_start_date,
        TRY_CAST(baseline_completion_date AS DATE)
            AS parsed_baseline_completion_date,
        TRY_CAST(actual_start_date AS DATE)
            AS parsed_actual_start_date,
        TRY_CAST(actual_completion_date AS DATE)
            AS parsed_actual_completion_date
    FROM ranked_projects
    WHERE duplicate_rank = 1
),
labor_project_timeline AS (
    SELECT
        ld.time_entry_id,
        ld.raw_project_id,
        ld.corrected_project_id,
        ld.parsed_work_date,
        pd.parsed_baseline_start_date,
        pd.parsed_baseline_completion_date,
        pd.parsed_actual_start_date,
        pd.parsed_actual_completion_date
    FROM labor_dates AS ld
    LEFT JOIN project_dates AS pd
        ON ld.corrected_project_id = pd.project_id
)
SELECT
    corrected_project_id AS project_id,
    parsed_baseline_completion_date,
    COUNT(*) AS post_baseline_labor_entries,
    MIN(parsed_work_date) AS first_post_baseline_work_date,
    MAX(parsed_work_date) AS latest_post_baseline_work_date,
    DATE_DIFF(
        'day',
        parsed_baseline_completion_date,
        MAX(parsed_work_date)
    ) AS days_labor_extended_beyond_baseline
FROM labor_project_timeline
WHERE parsed_work_date > parsed_baseline_completion_date
GROUP BY
    corrected_project_id,
    parsed_baseline_completion_date
ORDER BY post_baseline_labor_entries DESC;

-- Findings:
-- - 2,818 post-baseline labor entries are distributed across 78 projects.
-- - P026 has the most post-baseline entries at 126, representing approximately
--   4.5% of the total.
-- - The ten highest-count projects account for 973 entries, or approximately
--   34.5% of the total.
-- - P090 has the longest observed extension, with labor continuing 209 days
--   beyond its baseline completion date.
-- - The post-baseline labor is broadly distributed rather than driven by a
--   small number of anomalous projects.
-- - Preserve these records as valid schedule-variance evidence for later
--   project-level schedule-risk analysis.


-- Investigation 40: Determine labor-entry grain and overtime interpretability
-- Purpose:
-- - Determine whether employees can have multiple labor entries on the same
--   work_date and whether those entries span multiple projects.
-- - Inspect whether work_date follows a consistent weekday pattern that could
--   indicate a weekly time-entry or pay-period convention.
-- - Assess whether the available fields provide enough evidence to validate
--   the classification of regular and overtime hours.
-- - Avoid treating regular_hours above 40 as erroneous without a documented
--   workweek definition or confirmed row grain.
WITH ranked_labor AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY time_entry_id
            ORDER BY time_entry_id
        ) AS duplicate_rank
    FROM read_csv_auto('data/raw/labor_entries.csv')
),
cleaned_labor AS (
    SELECT
        employee_id,
        TRY_CAST(work_date AS DATE) AS parsed_work_date,
        project_id,
        regular_hours,
        overtime_hours
    FROM ranked_labor
    WHERE duplicate_rank = 1
)
SELECT
    employee_id,
    parsed_work_date,
    COUNT(*) AS labor_entry_count,
    COUNT(DISTINCT project_id) AS distinct_project_count,
    SUM(regular_hours) AS total_regular_hours,
    SUM(overtime_hours) AS total_overtime_hours
FROM cleaned_labor
GROUP BY
    employee_id,
    parsed_work_date
HAVING COUNT(*) > 1
ORDER BY
    labor_entry_count DESC,
    employee_id,
    parsed_work_date;
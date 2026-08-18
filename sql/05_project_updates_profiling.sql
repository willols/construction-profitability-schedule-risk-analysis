-- Project Updates Data Profiling
-- Source: data/raw/project_updates.csv
-- Purpose:
-- - Profile the raw project_updates dataset before cleaning and transformation.
-- - Identify schema, completeness, uniqueness, categorical, date, numeric,
--   and relationship issues that could affect the analysis.
-- Notes:
-- - Continue the established investigation numbering across profiling files.
-- - Preserve raw source values and document cleaning decisions separately.
-- - Reporting cutoff: 2026-06-30.


-- Investigation 41: Inspect project_updates.csv structure and identify candidate grain
-- Purpose:
-- - Inspect the inferred column names, data types, and representative values.
-- - Identify the likely row-level identifier and the fields that describe one
--   project update.
-- - Form an initial grain hypothesis for validation through subsequent
--   completeness and uniqueness testing.
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/project_updates.csv');

-- Preliminary findings:
-- - The dataset contains nine columns.
-- - update_id, project_id, primary_delay_reason, and submitted_by were inferred
--   as VARCHAR, which is reasonable for identifier and categorical fields.
-- - update_id is the candidate row-level identifier, while project_id appears
--   to link each update to the projects dataset; both relationships require
--   validation.
-- - report_date was inferred as VARCHAR even though its business meaning
--   suggests a DATE field, so its formatting and parseability require
--   investigation.
-- - planned_pct_complete was inferred as DOUBLE, while actual_pct_complete was
--   inferred as VARCHAR. Their formats, scales, ranges, and numeric
--   compatibility require comparison.
-- - estimated_cost_to_complete was inferred as DOUBLE but requires range and
--   precision testing before selecting an appropriate monetary DECIMAL type.
-- - forecast_completion_date was inferred as TIMESTAMP. Its raw values must be
--   inspected to determine whether a meaningful time component exists or
--   whether DATE is more appropriate.
-- - The DESCRIBE null and key metadata does not confirm actual completeness or
--   uniqueness because the data is being read directly from a CSV file.


-- Investigation 41A: Inspect sample project update records
-- Purpose:
-- - Inspect actual value formats and relationships among the columns.
-- - Refine the initial row-grain hypothesis.
-- - Identify fields requiring targeted profiling and validation.
SELECT *
FROM read_csv_auto('data/raw/project_updates.csv')
LIMIT 10;

-- Findings:
-- - The ten-row sample contains nine sequential updates for P001 and one update
--   for P002, confirming that projects can have multiple update records over
--   time.
-- - update_id appears to identify an individual update, while the combination
--   of project_id and report_date is a plausible business-grain candidate;
--   both require dataset-wide uniqueness testing.
-- - P001's report dates occur approximately every four weeks, suggesting a
--   periodic reporting cadence, although the sample is insufficient to confirm
--   that pattern across all projects.
-- - planned_pct_complete and actual_pct_complete appear to use a 0-to-100
--   percentage scale and progress over time in the sampled records.
-- - The sampled actual_pct_complete values appear numeric despite the column's
--   VARCHAR inference, indicating that inconsistent formatting may occur
--   elsewhere in the dataset.
-- - All sampled report_date values use ISO YYYY-MM-DD formatting despite the
--   column's VARCHAR inference, so date compatibility requires dataset-wide
--   validation.
-- - The sampled forecast_completion_date values contain midnight timestamps,
--   suggesting that the field may represent a calendar date without a
--   meaningful time component.
-- - No obvious row-level errors appear in the sample, but completeness,
--   uniqueness, valid ranges, and formatting consistency cannot be concluded
--   from ten rows.


-- Investigation 42: Validate update_id as the row-level key
-- Purpose:
-- - Compare total rows, non-NULL update_id values, and distinct update_id
--   values.
-- - Count NULL, empty, and whitespace-only identifiers.
-- - Determine whether duplicate identifiers exist and whether update_id can
--   be confirmed as the row-level key.
SELECT
    COUNT(*) AS total_row_count,
    COUNT(update_id) AS non_null_update_id_count,
    COUNT(DISTINCT update_id) AS distinct_update_id_count,
    COUNT(*) FILTER (
        WHERE update_id IS NULL
    ) AS null_update_id_count,
    COUNT(*) FILTER (
        WHERE update_id IS NOT NULL
          AND TRIM(update_id) = ''
    ) AS blank_update_id_count,
    COUNT(update_id) - COUNT(DISTINCT update_id)
        AS duplicate_update_id_occurrence_count
FROM read_csv_auto('data/raw/project_updates.csv');

-- Findings:
-- - All 726 records contain a non-NULL, nonblank update_id.
-- - The dataset contains 725 distinct update_id values, indicating one
--   duplicate occurrence.
-- - update_id is complete but cannot yet be confirmed as the row-level key
--   because it is not unique in the raw dataset.
-- - Further investigation is required to determine whether the duplicated ID
--   represents exact duplicate rows or distinct updates that incorrectly share
--   the same identifier.


-- Investigation 42A: Inspect the duplicated update_id
-- Purpose:
-- - Identify the update_id that appears more than once.
-- - Retrieve and compare every row associated with that identifier.
-- - Determine whether the rows are exact duplicates or distinct project updates
--   sharing the same update_id before establishing a cleaning rule.
SELECT
    update_id,
    COUNT(*) as row_count
FROM read_csv_auto('data/raw/project_updates.csv')
GROUP BY update_id
HAVING COUNT(*) > 1;

-- Findings:
-- - UPD00655 is the only update_id that occurs more than once, appearing in two rows.
-- - The grouped count does not establish whether these rows are exact duplicates
--   or distinct project updates sharing the same identifier.


-- Investigation 42B: Compare the records sharing update_id UPD00655
-- Purpose:
-- - Retrieve and compare all columns for the two records associated with UPD00655.
-- - Determine whether they are exact duplicate rows or distinct project updates
--   sharing the same identifier.
SELECT *
FROM read_csv_auto('data/raw/project_updates.csv')
WHERE update_id = 'UPD00655';

-- Findings:
-- - The two rows associated with UPD00655 are exact duplicates, matching across
--   all columns.
-- - update_id is not unique in the raw data, but it becomes the project-update
--   row-level key after the exact duplicate is removed.
-- - Preserve project_updates.csv unchanged and remove one repeated UPD00655 row
--   only in the cleaned analytical layer.


-- Investigation 43A: Revalidate the project-update business grain using
-- standardized report dates
-- Purpose:
-- - Revalidate whether one distinct update_id exists per project_id and
--   standardized_report_date.
-- - Prevent different raw date formats representing the same calendar date from
--   being treated as separate project-date combinations.
-- - Identify standardized project-date combinations associated with multiple
--   distinct update_id values.
-- - Count distinct update_id values so the repeated UPD00655 occurrence does not
--   create a false grain violation.
-- - Confirm or revise the candidate business grain of one project update per
--   project and standardized reporting date.
WITH standardized_updates AS (
    SELECT
        project_id,
        update_id,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS standardized_report_date
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    project_id,
    standardized_report_date,
    COUNT(DISTINCT update_id) AS distinct_update_count
FROM standardized_updates
GROUP BY
    project_id,
    standardized_report_date
HAVING COUNT(DISTINCT update_id) > 1
ORDER BY
    distinct_update_count DESC,
    project_id,
    standardized_report_date;

-- Findings:
-- - No (project_id, standardized_report_date) combination contains more than one
--   distinct update_id.
-- - Standardizing report_date values did not reveal any project-date combinations
--   that were hidden by inconsistent raw date formats.
-- - The repeated UPD00655 occurrence does not create a false grain violation
--   because both records share the same update_id.
-- - Therefore, the observed business grain is one project update per project and
--   standardized reporting date.
-- - update_id remains the cleaned row-level identifier.


-- Investigation 44: Assess project-update column completeness
-- Purpose:
-- - Count the total source rows and the NULL values in each column.
-- - Determine which fields are fully populated and which contain missing values
--   requiring further investigation or a cleaning decision.
SELECT
    COUNT(*) AS row_count,

    COUNT(*) FILTER (
    WHERE update_id IS NULL
    ) AS null_update_id_count,

    COUNT(*) FILTER (
    WHERE project_id IS NULL
    ) AS null_project_id_count,

    COUNT(*) FILTER (
    WHERE report_date IS NULL
    ) AS null_report_date_count,

    COUNT(*) FILTER (
    WHERE planned_pct_complete IS NULL
    ) AS null_planned_pct_complete_count,

    COUNT(*) FILTER (
    WHERE actual_pct_complete IS NULL
    ) AS null_actual_pct_complete_count,

    COUNT(*) FILTER (
    WHERE estimated_cost_to_complete IS NULL
    ) AS null_estimated_cost_to_complete_count,

    COUNT(*) FILTER (
    WHERE forecast_completion_date IS NULL
    ) AS null_forecast_completion_date_count,

    COUNT(*) FILTER (
    WHERE primary_delay_reason IS NULL
    ) AS null_primary_delay_reason_count,

    COUNT(*) FILTER (
    WHERE submitted_by IS NULL
    ) AS null_submitted_by_count

FROM read_csv_auto('data/raw/project_updates.csv');

-- Findings:
-- - The raw source contains 726 rows.
-- - Eight of the nine columns contain no NULL values.
-- - forecast_completion_date contains one NULL value.
-- - The associated record requires row-level inspection before determining
--   whether the missing value is valid or requires treatment.
-- - These results assess NULL completeness only; blank and whitespace-only text
--   values have not yet been tested.


-- Investigation 44A: Inspect the missing forecast_completion_date
-- Purpose:
-- - Retrieve all columns for the record with a NULL forecast_completion_date.
-- - Review the project and update context before determining whether the missing
--   forecast date is valid or requires treatment.
SELECT *
FROM read_csv_auto('data/raw/project_updates.csv')
WHERE forecast_completion_date IS NULL;

-- Findings:
-- - The UPD00664 record contains no conclusive evidence explaining why
--   forecast_completion_date is NULL.
-- - No defensible replacement date can be inferred from this record alone;
--   related updates for project P088 require inspection.


-- Follow-up: Inspect related updates for project P088
-- Purpose:
-- - Retrieve all project-update records for P088 in chronological order.
-- - Determine whether its other forecast dates provide context for the missing
--   forecast_completion_date in UPD00664.
-- - Assess whether a replacement date can be supported without assuming that
--   the missing value is imputable.
SELECT *
FROM read_csv_auto('data/raw/project_updates.csv')
WHERE project_id = 'P088'
ORDER BY report_date;

-- Findings:
-- - Project P088 contains four project-update records.
-- - Its first two updates contain a forecast_completion_date of 2026-07-27,
--   while the third contains 2026-07-28.
-- - These three updates list Owner decision / change order as the
--   primary_delay_reason.
-- - The fourth update, UPD00664, changes the primary_delay_reason to
--   Subcontractor availability and contains a NULL forecast_completion_date.
-- - The earlier forecast date cannot be carried forward reliably because the
--   new subcontractor delay introduces an unknown scheduling impact.
--
-- Cleaning decision:
-- - Preserve the NULL forecast_completion_date in the cleaned analytical layer
--   and flag it for business clarification. Keep the raw CSV unchanged.


-- Investigation 44B: Check text fields for blank or whitespace-only values
-- Purpose:
-- - Check each VARCHAR field for non-NULL values that become empty after
--   whitespace is removed.
-- - Determine whether blank or whitespace-only strings create additional
--   completeness issues not detected by the NULL-value assessment.
SELECT
    COUNT(*) AS row_count,

    COUNT(*) FILTER (
    WHERE update_id IS NOT NULL
      AND TRIM(update_id) = ''
    ) AS blank_or_whitespace_update_id_count,

    COUNT(*) FILTER (
        WHERE project_id IS NOT NULL
        AND TRIM(project_id) = ''
    ) AS blank_or_whitespace_project_id_count,

    COUNT(*) FILTER (
        WHERE primary_delay_reason IS NOT NULL
        AND TRIM(primary_delay_reason) = ''
    ) AS blank_or_whitespace_primary_delay_reason_count,

    COUNT(*) FILTER (
        WHERE submitted_by IS NOT NULL
        AND TRIM(submitted_by) = ''
    ) AS blank_or_whitespace_submitted_by_count

FROM read_csv_auto('data/raw/project_updates.csv');

-- Findings:
-- - None of the four VARCHAR fields contain blank or whitespace-only values.
-- - This check does not assess leading or trailing whitespace surrounding
--   otherwise populated text values.


-- Investigation 44C: Check text fields for leading or trailing whitespace
-- Purpose:
-- - Compare each populated VARCHAR value with its trimmed version.
-- - Identify values containing unwanted whitespace before or after meaningful
--   text that may require normalization in the cleaned analytical layer.
SELECT
    COUNT(*) AS row_count,

    COUNT(*) FILTER (
    WHERE update_id IS NOT NULL
      AND update_id <> TRIM(update_id)
    ) AS surrounding_whitespace_update_id_count,

    COUNT(*) FILTER (
    WHERE project_id IS NOT NULL
      AND project_id <> TRIM(project_id)
    ) AS surrounding_whitespace_project_id_count,

    COUNT(*) FILTER (
    WHERE primary_delay_reason IS NOT NULL
      AND primary_delay_reason <> TRIM(primary_delay_reason)
    ) AS surrounding_whitespace_primary_delay_reason_count,

    COUNT(*) FILTER (
    WHERE submitted_by IS NOT NULL
      AND submitted_by <> TRIM(submitted_by)
    ) AS surrounding_whitespace_submitted_by_count

FROM read_csv_auto('data/raw/project_updates.csv');

-- Findings:
-- - The source contains 726 rows.
-- - None of the populated values across the four VARCHAR columns changed after
--   applying TRIM().
-- - No leading- or trailing-whitespace normalization is currently required.
-- - Internal spaces were intentionally not tested because they may be legitimate
--   parts of populated values.


-- Investigation 45: Validate report_date formatting, parseability, and range
-- Purpose:
-- - Determine why report_date was inferred as VARCHAR by inspecting its raw
--   formats and testing whether every populated value can be parsed as a date.
-- - Identify format variations or invalid values requiring standardization.
-- - Establish the earliest and latest successfully parsed report dates and
--   identify any records after the 2026-06-30 reporting cutoff.
SELECT
    COUNT(*) AS row_count,

    COUNT(*) FILTER (
        WHERE TRY_CAST(report_date AS DATE) IS NOT NULL
    ) AS direct_parse_count,

    COUNT(*) FILTER (
        WHERE TRY_CAST(report_date AS DATE) IS NULL
          AND TRY_STRPTIME(report_date, '%m/%d/%Y') IS NOT NULL
    ) AS mdy_fallback_count,

    COUNT(*) FILTER (
        WHERE COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) IS NULL
    ) AS failed_both_methods_count

FROM read_csv_auto('data/raw/project_updates.csv');

-- Findings:
-- - 725 report_date values parse directly as DATE.
-- - One value requires the %m/%d/%Y fallback.
-- - No values fail both accepted parsing methods.
-- - All 726 populated values can therefore be standardized as DATE.
-- - The single fallback-parsed value likely explains why DuckDB inferred
--   report_date as VARCHAR and requires row-level inspection.


-- Investigation 45A: Inspect the fallback-parsed report date
-- Purpose:
-- - Retrieve the record whose report_date fails direct DATE conversion but
--   succeeds with the %m/%d/%Y fallback.
-- - Compare the raw value with its standardized DATE and confirm the format
--   variation responsible for the VARCHAR inference.
SELECT
    *,
    COALESCE(
        TRY_CAST(report_date AS DATE),
        CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
    ) AS standardized_report_date

FROM read_csv_auto('data/raw/project_updates.csv')

WHERE TRY_CAST(report_date AS DATE) IS NULL
  AND TRY_STRPTIME(report_date, '%m/%d/%Y') IS NOT NULL;

-- Findings:
-- - UPD00045 for project P006 is the only record requiring fallback parsing.
-- - Its raw report_date of 8/31/2024 standardizes to 2024-08-31.
-- - The value is a valid date recorded in a different format, not an invalid
--   date.
-- - This mixed date formatting explains why report_date was inferred as VARCHAR.
--
-- Cleaning decision:
-- - Standardize report_date as DATE using direct conversion with the
--   %m/%d/%Y fallback.
-- - Preserve the raw CSV unchanged.


-- Investigation 45B: Validate the standardized report_date range and cutoff
-- Purpose:
-- - Calculate the earliest and latest standardized report dates.
-- - Count records with report dates after the 2026-06-30 reporting cutoff.
-- - Confirm that the project-update history does not include reporting activity
--   beyond the authorized analysis period.
WITH standardized AS (
    SELECT
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS standardized_report_date
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    COUNT(*) AS row_count,
    MIN(standardized_report_date) AS earliest_report_date,
    MAX(standardized_report_date) AS latest_report_date,
    COUNT(*) FILTER (
        WHERE standardized_report_date > DATE '2026-06-30'
    ) AS report_dates_after_cutoff_count
FROM standardized;

-- Findings:
-- - Across 726 raw source rows, the earliest standardized report_date is
--   2023-02-25 and the latest is 2026-06-30.
-- - The latest report date equals the established reporting cutoff.
-- - No project-update records occur after the 2026-06-30 cutoff.
-- - The observed range raises no standalone concern, although report dates must
--   still be validated against individual project timelines later.


-- Investigation 46: Validate the forecast_completion_date data type
-- Purpose:
-- - Inspect the time components of all populated forecast_completion_date
--   values.
-- - Determine whether any records contain a meaningful non-midnight time.
-- - Decide whether TIMESTAMP precision carries useful information or whether
--   DATE is the more appropriate type for the cleaned analytical layer.
SELECT
    COUNT(*) AS total_rows,
    COUNT(forecast_completion_date) AS populated_forecast_date_count,
    COUNT(*) FILTER (
        WHERE forecast_completion_date IS NOT NULL
        AND CAST(forecast_completion_date AS TIME) = TIME '00:00:00'
        ) AS midnight_timestamp_count,
    COUNT(*) FILTER (
        WHERE forecast_completion_date IS NOT NULL
        AND CAST(forecast_completion_date AS TIME) <> TIME '00:00:00'
    ) AS non_midnight_timestamp_count
FROM read_csv_auto('data/raw/project_updates.csv');

-- Findings:
-- - The dataset contains 726 total rows, including 725 populated
--   forecast_completion_date values and one NULL value.
-- - All 725 populated values contain midnight timestamps, and zero contain
--   non-midnight time values.
-- - The counts reconcile: 725 populated values equal 725 midnight timestamps
--   plus zero non-midnight timestamps.
-- - The one-row difference between the total and populated counts is caused by
--   the known NULL forecast_completion_date for UPD00664 identified in
--   Investigation 44.
-- - Because the time component contains no additional information in the
--   observed data, convert forecast_completion_date to DATE in the cleaned
--   analytical layer while preserving UPD00664 as NULL.


-- Investigation 47: Validate the forecast-date range and its relationship to
-- the reporting date
-- Purpose:
-- - Identify the minimum and maximum populated forecast_completion_date values.
-- - Classify populated forecast dates as before, equal to, or after the
--   corresponding standardized report_date.
-- - Count forecast dates extending beyond the June 30, 2026 reporting cutoff.
-- - Identify date relationships requiring further investigation without
--   automatically classifying them as data errors.
-- - Preserve the known NULL forecast date for UPD00664 and exclude it from
--   populated-date relationship counts.
WITH standardized_updates AS (
    SELECT
        update_id,
        project_id,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS standardized_report_date,
        CAST(forecast_completion_date AS DATE)
            AS standardized_forecast_completion_date
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(standardized_forecast_completion_date)
        AS populated_forecast_date_count,
    COUNT(*) FILTER (
        WHERE standardized_forecast_completion_date IS NULL
    ) AS null_forecast_date_count,
    MIN(standardized_forecast_completion_date)
        AS earliest_forecast_completion_date,
    MAX(standardized_forecast_completion_date)
        AS latest_forecast_completion_date,
    COUNT(*) FILTER (
        WHERE standardized_forecast_completion_date < standardized_report_date
    ) AS forecast_before_report_date_count,
    COUNT(*) FILTER (
        WHERE standardized_forecast_completion_date = standardized_report_date
    ) AS forecast_on_report_date_count,
    COUNT(*) FILTER (
        WHERE standardized_forecast_completion_date > standardized_report_date
    ) AS forecast_after_report_date_count,
    COUNT(*) FILTER (
        WHERE standardized_forecast_completion_date > DATE '2026-06-30'
    ) AS forecast_after_cutoff_count
FROM standardized_updates;

-- Findings:
-- - The dataset contains 726 total rows, including 725 populated forecast dates
--   and the known NULL value for UPD00664.
-- - The observed forecast-date range is May 14, 2023 through January 23, 2027.
-- - Of the 725 populated forecasts, 40 occur before their report date, 75 occur
--   on their report date, and 610 occur after their report date.
-- - The relationship counts reconcile to all 725 populated forecast dates.
-- - The 40 forecasts preceding their report date require row-level investigation
--   but are not classified as data errors based on this result alone.
-- - Sixty-nine forecasts extend beyond the June 30, 2026 reporting cutoff. This
--   is not inherently problematic because forecasts may represent future
--   completion dates.


-- Investigation 47A: Inspect forecast dates preceding their report dates
-- Purpose:
-- - Inspect the 40 records where the standardized forecast completion date
--   precedes the standardized report date.
-- - Quantify how many days each forecast precedes its report date.
-- - Review project identifiers, percentage-completion values, and primary delay
--   reasons for business context and recurring patterns.
-- - Distinguish potentially overdue or stale forecasts from possible
--   data-quality problems without correcting or reclassifying any records.
WITH standardized_updates AS (
    SELECT
        update_id,
        project_id,
        planned_pct_complete,
        actual_pct_complete,
        primary_delay_reason,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS standardized_report_date,
        CAST(forecast_completion_date AS DATE)
            AS standardized_forecast_completion_date
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    update_id,
    project_id,
    standardized_report_date,
    standardized_forecast_completion_date,
    DATE_DIFF(
        'day',
        standardized_forecast_completion_date,
        standardized_report_date
    ) AS days_forecast_precedes_report_date,
    planned_pct_complete,
    actual_pct_complete,
    primary_delay_reason
FROM standardized_updates
WHERE standardized_forecast_completion_date < standardized_report_date
ORDER BY
    days_forecast_precedes_report_date DESC,
    project_id,
    standardized_report_date,
    update_id;

-- Findings:
-- - Forty records across eight projects have forecast completion dates preceding
--   their corresponding report dates.
-- - The affected projects are P076, P077, P083, P084, P085, P090, P091, and
--   P092.
-- - The forecast-to-report gaps range from 1 to 165 days.
-- - All 40 records contain a planned_pct_complete value of 100.
-- - The raw actual_pct_complete values show that some updates report 100%
--   completion while others remain below 100%.
-- - The pattern may represent a combination of post-completion reporting and
--   overdue or stale forecasts.
-- - Preserve all 40 records because this evidence does not establish a
--   data-quality error.
-- - Validate the percentage fields and compare these records with project status
--   and actual completion dates before assigning a final business classification.


-- Investigation 48: Determine why actual_pct_complete is inferred as VARCHAR
-- Purpose:
-- - Inspect the raw actual_pct_complete values and identify any formatting or
--   content that prevents consistent numeric type inference.
-- - Test whether all populated values can be converted directly to a numeric
--   type without normalization.
-- - Identify and inspect any values that fail numeric conversion.
-- - Evaluate the observed range and precision before selecting an appropriate
--   cleaned numeric type.
SELECT
    TYPEOF(actual_pct_complete) AS inferred_type,
    COUNT(*) AS total_rows,
    COUNT(actual_pct_complete) AS populated_value_count,
    COUNT(
        TRY_CAST(actual_pct_complete AS DECIMAL(10, 4))
    ) AS successful_conversion_count,
    COUNT(*) FILTER (
        WHERE actual_pct_complete IS NOT NULL
          AND TRY_CAST(
              actual_pct_complete AS DECIMAL(10, 4)
          ) IS NULL
    ) AS failed_conversion_count
FROM read_csv_auto('data/raw/project_updates.csv')
GROUP BY
    TYPEOF(actual_pct_complete);

-- Findings:
-- - DuckDB infers actual_pct_complete as VARCHAR.
-- - All 726 rows contain a populated actual_pct_complete value.
-- - Of the 726 populated values, 725 convert successfully to DECIMAL(10,4)
--   without normalization and one fails conversion.
-- - The single incompatible value likely caused DuckDB to infer the complete
--   column as VARCHAR rather than a numeric type.
-- - Inspect the failed value before defining a normalization rule or selecting
--   the final cleaned numeric type.


-- Investigation 48A: Inspect the failed actual_pct_complete conversion
-- Purpose:
-- - Identify the record and raw actual_pct_complete value that fails direct
--   conversion to DECIMAL(10,4).
-- - Review the affected update_id, project_id, report date, planned completion
--   percentage, and related project-update context.
-- - Determine whether the failure is caused by a formatting inconsistency or a
--   genuinely invalid percentage value.
-- - Avoid defining a normalization rule until the raw value has been inspected.
SELECT
    update_id,
    project_id,
    report_date,
    forecast_completion_date,
    planned_pct_complete,
    actual_pct_complete,
    primary_delay_reason
FROM read_csv_auto('data/raw/project_updates.csv')
WHERE actual_pct_complete IS NOT NULL
  AND TRY_CAST(actual_pct_complete AS DECIMAL(10, 4)) IS NULL
ORDER BY
    update_id;

-- Findings:
-- - The failed conversion occurs in update_id UPD00164 for project P022.
-- - Its raw actual_pct_complete value is 89.7%.
-- - The percent symbol prevents direct conversion of the complete string to
--   DECIMAL(10,4).
-- - Removing the percent symbol produces 89.7, which is consistent with the
--   apparent 0-to-100 scale used by the other percentage values.
-- - Treat the value as a formatting inconsistency rather than an invalid
--   percentage, pending validation of the normalization rule across all rows.
-- - Preserve the raw CSV value and apply any validated normalization only in the
--   cleaned analytical layer.


-- Investigation 48B: Validate percent-symbol normalization
-- Purpose:
-- - Test whether removing the percent symbol from actual_pct_complete allows all
--   populated values to convert successfully to DECIMAL(10,4).
-- - Count the values containing a percent symbol before normalization.
-- - Confirm that the normalization resolves UPD00164 without altering the
--   numeric meaning or scale of the value.
-- - Identify any conversion failures remaining after normalization.
-- - Preserve the raw CSV and apply the validated rule only in the cleaned
--   analytical layer.
WITH standardized_percentages AS (
    SELECT
        actual_pct_complete,
        TRY_CAST(
            REPLACE(actual_pct_complete, '%', '')
            AS DECIMAL(10, 4)
        ) AS standardized_actual_pct_complete
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(actual_pct_complete) AS populated_value_count,
    COUNT(*) FILTER (
        WHERE STRPOS(actual_pct_complete, '%') > 0
    ) AS percent_symbol_value_count,
    COUNT(standardized_actual_pct_complete)
        AS successful_standardization_count,
    COUNT(*) FILTER (
        WHERE actual_pct_complete IS NOT NULL
          AND standardized_actual_pct_complete IS NULL
    ) AS failed_standardization_count
FROM standardized_percentages;

-- Findings:
-- - All 726 actual_pct_complete values are populated, and exactly one raw value
--   contains a percent symbol.
-- - Removing the percent symbol allows all 726 values to convert successfully to
--   DECIMAL(10,4), with zero remaining conversion failures.
-- - UPD00164 standardizes from 89.7% to 89.7 without changing the percentage
--   scale.
-- - Remove percent symbols when standardizing actual_pct_complete in the cleaned
--   project-updates layer.
-- - Preserve the original value in the raw CSV.
-- - DECIMAL(10,4) is currently a diagnostic conversion type; select the final
--   cleaned numeric type after validating the standardized range and precision.


-- Investigation 49: Profile the standardized actual_pct_complete range and
-- precision
-- Purpose:
-- - Apply the validated percent-symbol normalization before evaluating the
--   percentage values numerically.
-- - Identify the minimum and maximum standardized actual_pct_complete values.
-- - Count values below 0 or above 100 that violate the expected percentage
--   range and require further investigation.
-- - Count values equal to the boundary values of 0 and 100.
-- - Test whether rounding to zero, one, or two decimal places changes any
--   observed values.
-- - Use the range and precision evidence to select an appropriate cleaned
--   DECIMAL type without altering the raw data.
WITH standardized_percentages AS (
    SELECT
        actual_pct_complete,
        TRY_CAST(
            REPLACE(actual_pct_complete, '%', '')
            AS DECIMAL(10, 4)
        ) AS standardized_actual_pct_complete
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    COUNT(standardized_actual_pct_complete)
        AS populated_actual_pct_count,
    MIN(standardized_actual_pct_complete)
        AS minimum_actual_pct,
    MAX(standardized_actual_pct_complete)
        AS maximum_actual_pct,
    COUNT(*) FILTER (
        WHERE standardized_actual_pct_complete < 0
    ) AS actual_pct_below_zero_count,
    COUNT(*) FILTER (
        WHERE standardized_actual_pct_complete > 100
    ) AS actual_pct_above_100_count,
    COUNT(*) FILTER (
        WHERE standardized_actual_pct_complete = 0
    ) AS actual_pct_at_zero_count,
    COUNT(*) FILTER (
        WHERE standardized_actual_pct_complete = 100
    ) AS actual_pct_at_100_count
FROM standardized_percentages;

-- Findings:
-- - All 726 actual_pct_complete values standardize successfully to numeric
--   values.
-- - The observed standardized range is 7.5 through 105.
-- - Zero values are below 0, and zero values are equal to 0.
-- - One value exceeds the expected maximum of 100.
-- - The single above-range value is 105 because it is also the observed maximum.
-- - A total of 108 values are equal to 100.
-- - Inspect the 105 value and its project-update context before classifying it as
--   a data-quality error or defining a cleaning decision.


-- Investigation 49A: Inspect the actual_pct_complete value exceeding 100
-- Purpose:
-- - Identify the update_id and project_id associated with the standardized
--   actual_pct_complete value above 100.
-- - Review its raw and standardized percentage values, planned completion,
--   report date, forecast completion date, and delay context.
-- - Inspect neighboring updates for the same project to determine whether the
--   value is isolated or part of a broader progression pattern.
-- - Determine whether the value reflects a formatting issue, an unexpected
--   business definition, or a probable data-entry error.
-- - Avoid correcting or capping the value until the surrounding evidence has
--   been reviewed.
WITH standardized_percentages AS (
    SELECT
        update_id,
        project_id,
        report_date,
        forecast_completion_date,
        planned_pct_complete,
        actual_pct_complete,
        primary_delay_reason,
        TRY_CAST(
            REPLACE(actual_pct_complete, '%', '')
            AS DECIMAL(10, 4)
        ) AS standardized_actual_pct_complete
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    update_id,
    project_id,
    report_date,
    forecast_completion_date,
    planned_pct_complete,
    actual_pct_complete,
    standardized_actual_pct_complete,
    primary_delay_reason
FROM standardized_percentages
WHERE standardized_actual_pct_complete > 100;

-- Preliminary findings:
-- - The above-range value occurs in update_id UPD00313 for project P040.
-- - The update was reported on July 10, 2024, with a forecast completion date of
--   September 27, 2024.
-- - planned_pct_complete is 65.4, while actual_pct_complete is 105.
-- - The reported actual value exceeds both the expected 100% maximum and the
--   planned value by 39.6 percentage points.
-- - The primary delay reason is Labor availability.
-- - This context increases suspicion that 105 is erroneous, but it does not
--   establish the intended replacement value.
-- - Inspect P040's update history before making a cleaning decision.


-- Next step:
-- Investigation 49B: Inspect project P040's update progression
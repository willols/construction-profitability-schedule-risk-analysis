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


-- Investigation 43: Validate the project-update business grain
-- Purpose:
-- - Test whether each deduplicated record represents one project update per
--   project_id and report_date.
-- - Identify project-date combinations associated with multiple distinct
--   update_id values.
-- - Determine whether (project_id, report_date) defines the business grain or
--   whether multiple updates can occur for the same project on the same date.
-- - Exclude the exact UPD00655 duplicate so it does not create a false grain
--   violation.
SELECT
    project_id,
    report_date,
    COUNT(DISTINCT update_id) AS distinct_update_count
FROM read_csv_auto('data/raw/project_updates.csv')
GROUP BY
    project_id,
    report_date
HAVING COUNT(DISTINCT update_id) > 1
ORDER BY
    distinct_update_count DESC,
    project_id,
    report_date;

-- Findings:
-- - No (project_id, report_date) combination is associated with more than one
--   distinct update_id.
-- - After removing the exact UPD00655 duplicate, each row represents one project
--   update for one project on one report date.
-- - Therefore, (project_id, report_date) defines the observed business grain,
--   while update_id serves as the cleaned row-level identifier.


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

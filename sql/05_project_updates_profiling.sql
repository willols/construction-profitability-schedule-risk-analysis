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


-- Next step:
-- Investigation 42A: Inspect the duplicated update_id
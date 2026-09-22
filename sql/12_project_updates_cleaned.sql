-- Purpose:
-- Apply documented cleaning rules to project_updates.csv
-- to create a reusable view for progress and schedule-risk analysis.

-- Grain:
-- One row per project and standardized report date.
-- update_id uniquely identifies each row after exact duplicate removal.

-- Cleaning rules:
-- 1. Remove exact duplicate rows, retaining one UPD00655 record. ^
-- 2. Convert report_date to DATE using standard parsing followed by
--    the validated M/D/YYYY fallback.
--    UPD00045's date converts from 8/31/2024 to 2024-08-31.
-- 3. Convert forecast_completion_date to DATE.
--    Preserve missing values and retain future forecasts.
-- 4. Remove % from actual_pct_complete and convert to DECIMAL(4,1).
-- 5. Convert planned_pct_complete directly to DECIMAL(4,1).
-- 6. Convert estimated_cost_to_complete to DECIMAL(10,2),
--    preserving recorded values, including zeros.
-- 7. Preserve project IDs, delay-reason labels, and submitter values.

-- Source preservation:
-- Leave the raw CSV unchanged.
-- Retain original columns alongside cleaned values and exception flags.

-- Exception handling:
-- Preserve and flag UPD00664's missing forecast date.
-- Preserve and flag UPD00313's actual completion of 105; do not cap it.
-- Preserve and flag orphan UPD99999 / P995 and its Unknown submitter.
-- Preserve progress decreases and stale or inconsistent forecasts;
-- flag these concerns for clarification rather than correcting values.
-- Preserve the None delay-reason label; do not interpret it as no delay.
-- Document its unresolved meaning for stakeholder clarification.


-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Cleaning step 1: Remove exact duplicate rows while preserving raw columns.
SELECT DISTINCT *
FROM read_csv_auto('data/raw/project_updates.csv');

-- Validation 1: Count unique_update_ids.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT update_id) AS unique_update_ids
FROM deduplicated;

-- PASS: Both rows returned 725.


-- Cleaning step 2: Convert report_date to DATE followed by validated M/D/YYYY fallback.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    *,
    COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean
FROM deduplicated;

-- Validation 2: Check for populated report dates that failed conversion.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
                TRY_CAST(report_date AS DATE),
                CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
            ) AS report_date_clean
    FROM deduplicated
)

SELECT *
FROM cleaned_project_updates
WHERE
    report_date IS NOT NULL
      AND report_date_clean IS NULL;

-- PASS: Zero rows returned.


-- Cleaning step 3: Convert forecast_completion_date to DATE
-- and flag missing forecast dates.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    *,
    CAST(forecast_completion_date AS DATE)
        AS forecast_completion_date_clean,
    (forecast_completion_date IS NULL) AS forecast_completion_date_missing_flag
FROM deduplicated;

-- Validation 3: Check that populated source forecast dates
-- remain populated after conversion.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean
    FROM deduplicated
)

SELECT
    *
FROM cleaned_project_updates
WHERE
    forecast_completion_date IS NOT NULL
      AND forecast_completion_date_clean IS NULL;

-- PASS: Zero rows returned.

-- Validation 3A: Check for flagged missing forecast dates.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL) AS forecast_completion_date_missing_flag
    FROM deduplicated
)

SELECT
    *
FROM cleaned_project_updates
WHERE forecast_completion_date_missing_flag = TRUE;

-- PASS: Only UPD00664 returned; raw and cleaned forecast dates
-- are NULL, and forecast_completion_date_missing_flag is TRUE.


-- Cleaning step 4: Remove percentage symbols from actual_pct_complete
-- and convert to DECIMAL(4,1).
-- Preserve out-of-range values and add actual_pct_complete_out_of_range_flag.
-- Known exception: UPD00313 records 105 percent.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    *,
    TRY_CAST(
            REPLACE(actual_pct_complete, '%', '')
            AS DECIMAL(4, 1)
        ) AS actual_pct_complete_clean,
    (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
    AS actual_pct_complete_out_of_range_flag
FROM deduplicated;

-- Validation 4: Check for populated actual percentages that failed conversion.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
SELECT
    *,
    TRY_CAST(
            REPLACE(actual_pct_complete, '%', '')
            AS DECIMAL(4, 1)
        ) AS actual_pct_complete_clean
FROM deduplicated
)

SELECT *
FROM cleaned_project_updates
WHERE
    actual_pct_complete IS NOT NULL
    AND actual_pct_complete_clean IS NULL;

-- PASS: Zero rows returned.

-- Validation 4A: Check values with actual_pct_complete_out_of_range_flag IS TRUE.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),
cleaned_project_updates AS (
    SELECT
        *,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag
    FROM deduplicated
)

SELECT *
FROM cleaned_project_updates
WHERE actual_pct_complete_out_of_range_flag = TRUE;

-- PASS: Only UPD00313 returned; raw value is '105',
-- cleaned value is 105.0, and the out-of-range flag is TRUE.


-- Cleaning step 5: Convert planned_pct_complete to DECIMAL(4,1).
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    *,
    TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
      AS planned_pct_complete_clean
FROM deduplicated;

-- Validation 5: Check for populated planned percentages that failed conversion.
WITH Deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean
    FROM deduplicated
)

SELECT *
FROM cleaned_project_updates
WHERE
    planned_pct_complete IS NOT NULL
    AND planned_pct_complete_clean IS NULL;

-- PASS: Zero rows returned.


-- Cleaning step 6: Convert estimated_cost_to_complete to DECIMAL(10,2).
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
)

SELECT
    *,
    TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
      AS estimated_cost_to_complete_clean
FROM deduplicated;

-- Validation 6: Check for populated ETC values that failed conversion.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
)

SELECT *
FROM cleaned_project_updates
WHERE
    estimated_cost_to_complete IS NOT NULL
    AND estimated_cost_to_complete_clean IS NULL;

-- PASS: Zero rows returned.


-- Cleaning step 7: Combine transformations and add exception flags.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
)

SELECT
    pu.*,
    (p.project_id IS NULL) AS unmatched_project_id_flag,
    (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
    (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
      AS progress_decrease_flag,
    (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
FROM progress_history AS pu
LEFT JOIN construction.cleaned_projects AS p
    ON pu.project_id = p.project_id;

-- Validation 7: Check counts after JOIN.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT update_id) AS unique_update_id
FROM cleaned_output;

-- PASS: Both total and unique update ID counts returned 725.


-- Validation 7A: Check true flag count.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT
    COUNT(*) AS row_count,
    COUNT(*) FILTER (
        WHERE forecast_completion_date_missing_flag IS TRUE
    ) AS forecast_completion_date_missing_flag_count,
    COUNT(*) FILTER (
        WHERE actual_pct_complete_out_of_range_flag IS TRUE
    ) AS actual_pct_complete_out_of_range_flag_count,
    COUNT(*) FILTER (
        WHERE unmatched_project_id_flag IS TRUE
    ) AS unmatched_project_id_flag_count,
    COUNT(*) FILTER (
        WHERE unknown_submitter_flag IS TRUE
    ) AS unknown_submitter_flag_count,
    COUNT(*) FILTER (
        WHERE progress_decrease_flag IS TRUE
    ) AS progress_decrease_flag_count,
    COUNT(*) FILTER (
        WHERE forecast_before_report_flag IS TRUE
    ) AS forecast_before_report_flag_count
FROM cleaned_output;

-- PASS: ALl six flag counts match expected.


-- Validation 7B: Check flags indentify the correct rows.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT
    update_id,
    project_id,
    submitted_by
FROM cleaned_output
WHERE
    unmatched_project_id_flag = TRUE
    OR unknown_submitter_flag = TRUE;

-- PASS: Flags match the correct row.


-- Validation 7C: Check data types.
DESCRIBE
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT *
FROM cleaned_outputs;

-- PASS: All cleaned outputs match the data types intended.


-- Validation 7D: Check that recorded zeros remain zero after cleaning.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT
    update_id,
    actual_pct_complete,
    actual_pct_complete_clean,
    planned_pct_complete,
    planned_pct_complete_clean,
    estimated_cost_to_complete,
    estimated_cost_to_complete_clean
FROM cleaned_output
WHERE (
    TRY_CAST(actual_pct_complete AS DECIMAL(4,1)) = 0
    AND actual_pct_complete_clean IS DISTINCT FROM 0
)
OR (
    TRY_CAST(planned_pct_complete AS DECIMAL(4,1)) = 0
    AND planned_pct_complete_clean IS DISTINCT FROM 0
)
OR (
    TRY_CAST(estimated_cost_to_complete AS DECIMAL(10,2)) = 0
    AND estimated_cost_to_complete_clean IS DISTINCT FROM 0
);

-- PASS: No zero values changed.


-- Validation 7E: Validate that the ETC total is preserved after cleaning.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT
    source_etc_total,
    cleaned_etc_total,
    cleaned_etc_total - source_etc_total AS etc_difference
FROM (
    SELECT
        (
            SELECT SUM(
                TRY_CAST(estimated_cost_to_complete AS DECIMAL(10,2))
            )
            FROM deduplicated
        ) AS source_etc_total,
        (
            SELECT SUM(estimated_cost_to_complete_clean)
            FROM cleaned_output
        ) AS cleaned_etc_total
) AS etc_totals;

-- PASS: Reconcilliation passed. Zero difference.


-- Create project updates view.
CREATE OR REPLACE VIEW construction.cleaned_project_updates AS
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_updates.csv')
),

cleaned_project_updates AS (
    SELECT
        *,
        COALESCE(
            TRY_CAST(report_date AS DATE),
            CAST(TRY_STRPTIME(report_date, '%m/%d/%Y') AS DATE)
        ) AS report_date_clean,
        CAST(forecast_completion_date AS DATE)
            AS forecast_completion_date_clean,
        (forecast_completion_date IS NULL)
        AS forecast_completion_date_missing_flag,
        TRY_CAST(
                REPLACE(actual_pct_complete, '%', '')
                AS DECIMAL(4, 1)
            ) AS actual_pct_complete_clean,
        (actual_pct_complete_clean > 100 OR actual_pct_complete_clean < 0)
        AS actual_pct_complete_out_of_range_flag,
        TRY_CAST(planned_pct_complete AS DECIMAL (4,1))
        AS planned_pct_complete_clean,
        TRY_CAST(estimated_cost_to_complete AS DECIMAL (10,2))
        AS estimated_cost_to_complete_clean
    FROM deduplicated
),

progress_history AS (
    SELECT
        *,
        LAG(actual_pct_complete_clean) OVER (
            PARTITION BY project_id
            ORDER BY report_date_clean
        ) AS previous_actual_pct_complete
    FROM cleaned_project_updates
),

cleaned_output AS (
    SELECT
        pu.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (pu.submitted_by = 'Unknown') AS unknown_submitter_flag,
        (pu.actual_pct_complete_clean < pu.previous_actual_pct_complete)
        AS progress_decrease_flag,
        (pu.forecast_completion_date_clean < pu.report_date_clean) AS forecast_before_report_flag
    FROM progress_history AS pu
    LEFT JOIN construction.cleaned_projects AS p
        ON pu.project_id = p.project_id
)

SELECT *
FROM cleaned_output;


-- View validation 1: Check view counts.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT update_id) AS unique_update_count
FROM construction.cleaned_project_updates;

-- PASS: both returned 725.


-- This dashboard is designed for Rachel Kim, Director of Operations, and project managers involved
-- in follow-up. It helps Rachel prioritize active projects for review as of June 30, 2026,
-- using forecast budget variance, progress gap in percentage points, and usable forecast
-- delay in days. Findings from the five priority-project reviews guide follow-up
-- questions and recommended actions.
--
-- Source: construction.project_summary; June 30, 2026 snapshot.
-- Scope: Active projects only.
-- Grain: One row per project; expected 18 rows and 18 unique project IDs.
-- Preserve NULL forecast delays: NULL means unknown or unusable, not zero.


-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Query 1: Select dashboard metrics for the 18 active projects.
SELECT
    project_id,
    forecast_budget_variance,
    progress_gap_pp,
    forecast_delay_days
FROM construction.project_summary
WHERE project_status_clean = 'active';

-- Validation: 18 rows, 18 unique project IDs;
-- 9 usable forecast delays and 9 NULL forecast delays.


-- Export active-project dashboard metrics to CSV for Tableau.
COPY (
    SELECT
        project_id,
        forecast_budget_variance,
        progress_gap_pp,
        forecast_delay_days
    FROM construction.project_summary
    WHERE project_status_clean = 'active'
)
TO 'outputs/active_project_dashboard_2026-06-30.csv'
(FORMAT CSV, HEADER);
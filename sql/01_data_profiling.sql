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
-- Data-handling rule:
-- Treat all raw CSV files as immutable source data. Apply any corrections or
-- standardization only in cleaned outputs.
--
-- Profiling scope:
-- Inspect column names, inferred data types, row counts, grain, key uniqueness,
-- duplicates, missing values, categorical consistency, date ranges, numeric
-- anomalies, and relationships between files..


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
-- Next steps:
-- Draft the findings for Investigation 3.
-- Inspect the record with a missing project_type.
-- Compare rows with missing actual_completion_date values against project_status
-- to determine whether the missingness is expected for incomplete projects.
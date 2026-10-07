-- SECTION 1: REPORT PURPOSE AND DEFINITIONS


-- Report: Budget versus actual.
--
-- Purpose: Compare recorded incurred costs with the budget and
-- identify project cost categories where spending needs attention.
--
-- Row grain: One row per project and cost category.
--
-- Reporting cutoff: June 30, 2026.
-- Include transaction dates and employee work dates on or before the cutoff.
-- Budget date limitation is documented below.

-- Revised budget:
-- Sum revised_budget_amount_clean for each project and cleaned
-- cost category.
-- Use the supplied revised budget amounts.
-- The budget file has no effective date or version history, so
-- its validity as of June 30, 2026 has not been verified.

-- Incurred cost:
-- Sum amount_clean from cleaned_cost_transactions where
-- payment_status_clean is paid, approved, or applied, plus
-- labor_cost_clean from cleaned_labor_entries.
-- Include transaction dates and work dates on or before June 30, 2026.
-- Retain applied credits as negative amounts.
-- Map employee labor from all trades to the Labor budget category.

-- Pending exposure:
-- Sum amount_clean where payment_status_clean is pending.
-- Show separately from incurred cost.

-- Budget remaining:
-- Revised budget minus recorded incurred cost.
-- Pending exposure is not subtracted here.
-- Budget remaining is not an estimate of the cost to finish.

-- No matching cost records:
-- Show zero incurred cost and pending exposure when neither a
-- transaction group nor an employee labor group matches.
-- Preserve no_matching_cost_records_flag for these rows.
-- This does not confirm that no spending occurred outside the data.

-- Missing original budget:
-- Retain P057 Equipment's reported revised budget of 31,672.00.
-- Its original budget is missing; do not replace it with zero.
-- The original-plus-change calculation cannot be verified.
-- Preserve the missing-original-budget flag.

-- Orphan budgets:
-- Retain budget records with unmatched project IDs, including P997.
-- Preserve the orphan-project flag so these records remain visible.

-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;

-- SECTION 2: STANDALONE BUDGET SUMMARY

-- Aggregate budget lines to one row per project and cost category.
-- Preserve both data-quality flags across each group.

SELECT
    project_id,
    cost_category_clean,
    SUM(revised_budget_amount_clean) AS revised_budget,
    BOOL_OR(original_budget_missing_flag) AS original_budget_missing_flag,
    BOOL_OR(orphan_project_flag) AS orphan_project_flag
FROM construction.cleaned_project_budgets
GROUP BY
    project_id,
    cost_category_clean;

-- Observed result: 673 project/category groups.



-- SECTION 3: STANDALONE TRANSACTION-COST SUMMARY

-- Aggregate transactions to one row per cleaned project ID
-- and cleaned cost category.
-- Calculate pending exposure and incurred cost separately.

SELECT
    project_id_clean,
    cost_category_clean,
    SUM(
        CASE
            WHEN payment_status_clean = 'pending'
                THEN amount_clean
            ELSE 0
        END
    ) AS pending_exposure,
    SUM(
        CASE
            WHEN payment_status_clean IN ('paid', 'approved', 'applied')
                THEN amount_clean
            ELSE 0
        END
    ) AS incurred_cost
FROM construction.cleaned_cost_transactions
WHERE transaction_date <= DATE '2026-06-30'
GROUP BY
    project_id_clean,
    cost_category_clean;

-- Observed result: 576 project/category groups.


-- SECTION 4: BUDGET-VERSUS-ACTUAL REPORT VIEW

-- Summarize budgets, transaction costs, and employee labor separately.
-- Map all employee trades to the Labor budget category.
-- Combine costs using a FULL OUTER JOIN on project ID and cost category,
-- then FULL OUTER JOIN combined costs to budgets to retain unmatched groups.
-- Treat an absent cost source as zero; pending exposure is transactions only.
-- Calculate budget remaining as revised budget minus total incurred cost.
-- Preserve no_matching_cost_records_flag when neither cost source matches.
-- Keep available project/category keys for unmatched groups.
-- LEFT JOIN project details without removing orphan records.
-- Apply the June 30, 2026 cutoff to transaction dates and work dates.
-- Save the report as a reusable view for validation and Excel export.
-- The view reruns the report query against its underlying sources;
-- it does not store a frozen snapshot of the results.
CREATE OR REPLACE VIEW construction.budget_vs_actual_report AS
WITH budget_summary AS (
    SELECT
        project_id,
        cost_category_clean,
        SUM(revised_budget_amount_clean) AS revised_budget,
        BOOL_OR(original_budget_missing_flag) AS original_budget_missing_flag,
        BOOL_OR(orphan_project_flag) AS orphan_project_flag
    FROM construction.cleaned_project_budgets
    GROUP BY
        project_id,
        cost_category_clean
),

cost_summary AS (
    SELECT
        project_id_clean,
        cost_category_clean,
        SUM(
            CASE
                WHEN payment_status_clean = 'pending'
                    THEN amount_clean
                ELSE 0
            END
        ) AS pending_exposure,
        SUM(
            CASE
                WHEN payment_status_clean IN ('paid', 'approved', 'applied')
                    THEN amount_clean
                ELSE 0
            END
        ) AS incurred_cost
    FROM construction.cleaned_cost_transactions
    WHERE transaction_date <= DATE '2026-06-30'
    GROUP BY
        project_id_clean,
        cost_category_clean
),
-- Summarize employee labor costs by cleaned project ID through June 30, 2026.
-- Map all trades to the Labor budget category so the summary can be
-- matched using both project ID and cost category.
labor_summary AS (
    SELECT
        project_id_clean,
        SUM(labor_cost_clean) AS total_labor_cost,
        'Labor' AS cost_category_clean
    FROM construction.cleaned_labor_entries
    WHERE work_date_clean <= DATE '2026-06-30'
    GROUP BY project_id_clean
),
-- Combine transaction and employee labor summaries by project and category.
-- Preserve groups from either source and treat an absent source as zero.
-- Pending exposure comes from transactions only.
combined_cost_summary AS (
    SELECT
        COALESCE(c.project_id_clean, l.project_id_clean) AS project_id_clean,
        COALESCE(c.cost_category_clean, l.cost_category_clean) AS cost_category_clean,
        COALESCE(c.pending_exposure, 0) AS pending_exposure,
        COALESCE(c.incurred_cost, 0)
            + COALESCE(l.total_labor_cost, 0) AS incurred_cost
    FROM cost_summary AS c
    FULL OUTER JOIN labor_summary AS l
        ON c.project_id_clean = l.project_id_clean
        AND c.cost_category_clean = l.cost_category_clean
)

SELECT
    COALESCE(b.project_id, c.project_id_clean) AS project_id,
    p.project_name,
    COALESCE(b.cost_category_clean, c.cost_category_clean) AS cost_category,
    b.revised_budget,
    b.original_budget_missing_flag,
    b.orphan_project_flag,
    CASE
        WHEN c.project_id_clean IS NULL THEN 0
        ELSE c.pending_exposure
    END AS pending_exposure,
    CASE
        WHEN c.project_id_clean IS NULL THEN 0
        ELSE c.incurred_cost
    END AS incurred_cost,
    b.revised_budget - CASE
        WHEN c.project_id_clean IS NULL THEN 0
        ELSE c.incurred_cost
    END AS budget_remaining,
    c.project_id_clean IS NULL AS no_matching_cost_records_flag
FROM budget_summary AS b
FULL OUTER JOIN combined_cost_summary AS c
    ON b.project_id = c.project_id_clean
    AND b.cost_category_clean = c.cost_category_clean
LEFT JOIN construction.cleaned_projects AS p
    ON COALESCE(b.project_id, c.project_id_clean) = p.project_id;


-- SECTION 5: INSPECTION AND VALIDATION

-- 5A: INSPECT THE MISSING ORIGINAL BUDGET

-- Inspect the source fields and cleaned values for the flagged line.

SELECT *
FROM construction.cleaned_project_budgets
WHERE original_budget_missing_flag = TRUE;

-- Observed:
-- BUD-P057-04 / P057 / Equipment.
-- Original budget is NULL; reported revised budget is 31,672.00.


-- 5B: CHECK CURRENT REPORT COVERAGE
-- Inspect total rows and budget/cost matching coverage after adding labor.
-- revised_budget IS NULL identifies rows without a supplied budget amount;
-- inspect any such rows before treating them as unmatched budget groups.
SELECT
    COUNT(*) AS report_rows,
    COUNT(*) FILTER (
        WHERE revised_budget IS NOT NULL
          AND no_matching_cost_records_flag = FALSE
    ) AS budget_and_cost_rows,
    COUNT(*) FILTER (
        WHERE revised_budget IS NOT NULL
          AND no_matching_cost_records_flag = TRUE
    ) AS budget_only_rows,
    COUNT(*) FILTER (
        WHERE revised_budget IS NULL
    ) AS rows_without_budget_amount
FROM construction.budget_vs_actual_report;

-- Pending: Run the updated coverage check and record observed counts.


-- 5C: CALCULATE THE BUDGET TOTAL BEFORE JOINING

-- Include all cleaned budget records, including orphan budgets.

SELECT
    SUM(revised_budget_amount_clean) AS revised_budget_total_before
FROM construction.cleaned_project_budgets;

-- Observed total: 119,564,833.67.


-- 5D: CALCULATE EXPECTED INCURRED COST FROM BOTH SOURCES
-- Apply the same status rules and cutoff used in the report.
WITH transaction_total AS (
    SELECT
        SUM(amount_clean) AS transaction_incurred_total
    FROM construction.cleaned_cost_transactions
    WHERE transaction_date <= DATE '2026-06-30'
      AND payment_status_clean IN ('paid', 'approved', 'applied')
),
labor_total AS (
    SELECT
        SUM(labor_cost_clean) AS employee_labor_total
    FROM construction.cleaned_labor_entries
    WHERE work_date_clean <= DATE '2026-06-30'
)
SELECT
    t.transaction_incurred_total,
    l.employee_labor_total,
    t.transaction_incurred_total
        + l.employee_labor_total AS expected_incurred_total
FROM transaction_total AS t
CROSS JOIN labor_total AS l;

-- Passed: Transaction incurred cost = 80,468,439.22;
-- employee labor = 30,917,634.47;
-- combined expected incurred cost = 111,386,073.69, matching 5F.


-- 5E: INSPECT TRANSACTIONS EXCLUDED BY THE CUTOFF

-- Find transactions dated after June 30, 2026 or with a NULL date.
SELECT *
FROM construction.cleaned_cost_transactions
WHERE transaction_date > DATE '2026-06-30'
  OR transaction_date IS NULL;

-- Passed: 0 transactions dated after the cutoff or with a NULL date.
-- The cutoff filter excludes no transactions from the current dataset.


-- 5E (continued): INSPECT LABOR ENTRIES EXCLUDED BY THE CUTOFF
SELECT *
FROM construction.cleaned_labor_entries
WHERE work_date_clean > DATE '2026-06-30'
   OR work_date_clean IS NULL;

-- Pending: Record labor entries after the cutoff or with a NULL work date.


-- 5F: CHECK TOTALS FROM THE UPDATED REPORT

-- Verify that the report preserves revised budget, incurred cost,
-- and pending exposure totals after the project join and cutoff filter.
SELECT
    SUM(revised_budget) AS revised_budget_total,
    SUM(pending_exposure) AS pending_exposure_total,
    SUM(incurred_cost) AS incurred_cost_total
FROM construction.budget_vs_actual_report;

-- Passed: All three totals match the previously validated totals.
-- Revised budget: 119,564,833.67, including orphan budgets.
-- Pending exposure: 7,961,647.60.
-- Incurred cost: 111,386,073.69, matching the combined source total in 5D.


-- 5G: CHECK FOR DUPLICATE PROJECT/COST_CATEGORY.

-- Validate that there are no duplicate project/cost_category groups
-- within budget_vs_actual_report.
SELECT
    project_id,
    cost_category,
    COUNT(*) AS row_total
FROM construction.budget_vs_actual_report
GROUP BY
    project_id,
    cost_category
HAVING COUNT(*) > 1;

-- Passed: Zero duplicate project/cost-category groups returned.


-- 5H: CHECK DATA-QUALITY FLAG COUNTS

-- Count rows flagged for missing original budgets, orphan projects,
-- and no matching cost records.
SELECT
    COUNT(*) FILTER (
        WHERE original_budget_missing_flag = TRUE
    ) AS original_budget_missing_flag_true_count,
    COUNT(*) FILTER (
        WHERE orphan_project_flag = TRUE
    ) AS orphan_project_flag_true_count,
    COUNT(*) FILTER (
        WHERE no_matching_cost_records_flag = TRUE
    ) AS no_matching_cost_records_flag_true_count
FROM construction.budget_vs_actual_report;


-- Confirmed: Missing original budget = 1; orphan project = 1;
-- no matching cost records = 1 (P997, Labor).


-- 5I: RECONCILE PROJECT INCURRED TOTALS WITH PROJECT_SUMMARY
-- Compare totals for projects in project_summary; orphan report IDs
-- remain visible in the report and are outside this comparison.
WITH report_project_totals AS (
    SELECT
        project_id,
        SUM(incurred_cost) AS incurred_cost_total
    FROM construction.budget_vs_actual_report
    GROUP BY project_id
)

SELECT
    p.project_id,
    p.total_incurred_cost,
    r.incurred_cost_total
FROM construction.project_summary AS p
LEFT JOIN report_project_totals AS r
    ON p.project_id = r.project_id
WHERE p.total_incurred_cost IS DISTINCT FROM
    r.incurred_cost_total;

-- Passed: Zero incurred-cost mismatches for projects in project_summary.


-- 5J: RECONCILE P093 INCURRED COST
-- Validate P093's total incurred cost after adding employee labor.
-- Sum incurred_cost across its report categories.
-- Expected: 1,720,860.62, matching project_summary.total_incurred_cost.
SELECT
    SUM(incurred_cost) AS incurred_cost
FROM construction.budget_vs_actual_report
WHERE project_id = 'P093';

-- Passed: P093 incurred cost = 1,720,860.62, matching project_summary.


-- SECTION 6: EXPORT FOR EXCEL

-- Export the validated budget-versus-actual report to CSV
-- for reviewing and presenting budget and cost comparisons in Excel.
COPY construction.budget_vs_actual_report
TO 'outputs/budget_vs_actual_2026-06-30.csv'
(FORMAT CSV, HEADER);



-- 6A: Validate the exported CSV totals.
SELECT
    SUM(revised_budget) AS revised_budget_total,
    SUM(pending_exposure) AS pending_exposure_total,
    SUM(incurred_cost) AS incurred_cost_total
FROM read_csv_auto ('outputs/budget_vs_actual_2026-06-30.csv');

-- Expected: Revised budget = 119,564,833.67; pending exposure = 7,961,647.60;
-- incurred cost = 111,386,073.69.
-- Pending: Re-export the updated view, run this check, and record results.

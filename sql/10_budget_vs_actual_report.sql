-- SECTION 1: REPORT PURPOSE AND DEFINITIONS


-- Report: Budget versus actual.
--
-- Purpose: Compare recorded incurred costs with the budget and
-- identify project cost categories where spending needs attention.
--
-- Row grain: One row per project and cost category.
--
-- Transaction reporting cutoff: June 30, 2026.
-- Include transactions dated on or before the cutoff.
-- Budget date limitation is documented below.

-- Revised budget:
-- Sum revised_budget_amount_clean for each project and cleaned
-- cost category.
-- Use the supplied revised budget amounts.
-- The budget file has no effective date or version history, so
-- its validity as of June 30, 2026 has not been verified.

-- Incurred cost:
-- Sum amount_clean where payment_status_clean is paid, approved,
-- or applied. Retain applied credits as negative amounts.

-- Pending exposure:
-- Sum amount_clean where payment_status_clean is pending.
-- Show separately from incurred cost.

-- Budget remaining:
-- Revised budget minus recorded incurred cost.
-- Pending exposure is not subtracted here.
-- Budget remaining is not an estimate of the cost to finish.

-- No matching transactions:
-- Show zero recorded incurred cost and pending exposure when
-- no transaction group matches. Preserve a flag for these rows.
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
GROUP BY
    project_id_clean,
    cost_category_clean;

-- Observed result: 576 project/category groups.


-- SECTION 4: BUDGET-VERSUS-ACTUAL REPORT VIEW

-- - Summarize budgets and costs separately before joining.
-- - Match on both project ID and cleaned cost category.
-- - Use a FULL OUTER JOIN to retain unmatched rows from either side.
-- - Show zero recorded costs when no transaction group matches.
-- - Preserve a no-matching-transactions flag.
-- - Calculate budget remaining as revised budget minus recorded incurred cost.
-- - Use zero incurred cost when no transaction group matches.
-- - Show one project ID and one cost category using the available
--   budget-side or cost-side value, including unmatched rows.
-- - Add matching project details with a LEFT JOIN while preserving
--   every budget-and-cost report row, including orphan records.
-- - Include only transactions dated on or before June 30, 2026.
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
    c.project_id_clean IS NULL AS no_matching_transactions_flag
FROM budget_summary AS b
FULL OUTER JOIN cost_summary AS c
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


-- 5B: RECORD COMPLETED JOIN-COUNT CHECKS

-- Checks previously run against the Section 4 join:
-- Total joined rows: 673.
-- Matched budget and cost groups: 576.
-- Budget-only groups: 97.
-- Cost-only groups: 0.
--
-- These checks establish matching coverage within the supplied data.
-- They do not establish completeness of real-world expenses.


-- 5C: CALCULATE THE BUDGET TOTAL BEFORE JOINING

-- Include all cleaned budget records, including orphan budgets.

SELECT
    SUM(revised_budget_amount_clean) AS revised_budget_total_before
FROM construction.cleaned_project_budgets;

-- Observed total: 119,564,833.67.


-- 5D: CHECK ALL THREE TOTALS AFTER JOINING

-- Verify that joining the summaries preserves incurred cost,
-- pending exposure, and revised budget totals.
-- Run this entire statement from WITH to the final semicolon.

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
    GROUP BY
        project_id_clean,
        cost_category_clean
)

SELECT
    SUM(c.incurred_cost) AS incurred_cost_total,
    SUM(c.pending_exposure) AS pending_exposure_total,
    SUM(b.revised_budget) AS revised_budget_total_after
FROM budget_summary AS b
FULL OUTER JOIN cost_summary AS c
    ON b.project_id = c.project_id_clean
    AND b.cost_category_clean = c.cost_category_clean;

-- Passed:
-- Incurred cost = 80,468,439.22.
-- Pending exposure = 7,961,647.60.
-- Both match the previously validated transaction totals.
--
-- Revised budget after joining = 119,564,833.67.
-- Matches the before-join budget total; difference = 0.00.
-- Includes orphan budget records.


-- 5E: INSPECT TRANSACTIONS EXCLUDED BY THE CUTOFF

-- Find transactions dated after June 30, 2026 or with a NULL date.
SELECT *
FROM construction.cleaned_cost_transactions
WHERE transaction_date > DATE '2026-06-30'
  OR transaction_date IS NULL;

-- Passed: 0 transactions dated after the cutoff or with a NULL date.
-- The cutoff filter excludes no transactions from the current dataset.


-- 5F: CHECK TOTALS FROM THE UPDATED REPORT

-- Verify that the report preserves revised budget, incurred cost,
-- and pending exposure totals after the project join and cutoff filter.
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

budget_vs_actual AS (
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
        c.project_id_clean IS NULL AS no_matching_transactions_flag
    FROM budget_summary AS b
    FULL OUTER JOIN cost_summary AS c
        ON b.project_id = c.project_id_clean
        AND b.cost_category_clean = c.cost_category_clean
    LEFT JOIN construction.cleaned_projects AS p
        ON COALESCE(b.project_id, c.project_id_clean) = p.project_id
)

SELECT
    SUM(revised_budget) AS revised_budget_total,
    SUM(pending_exposure) AS pending_exposure_total,
    SUM(incurred_cost) AS incurred_cost_total
FROM budget_vs_actual;

-- Passed: All three totals match the previously validated totals.
-- Revised budget: 119,564,833.67, including orphan budgets.
-- Pending exposure: 7,961,647.60.
-- Incurred cost: 80,468,439.22.


-- 5G: CHECK FOR DUPLICATE PROJECT/COST_CATEGORY.

-- Validate that there are no duplicate project/cost_category groups
-- within budget_vs_actual.
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

budget_vs_actual AS (
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
        c.project_id_clean IS NULL AS no_matching_transactions_flag
    FROM budget_summary AS b
    FULL OUTER JOIN cost_summary AS c
        ON b.project_id = c.project_id_clean
        AND b.cost_category_clean = c.cost_category_clean
    LEFT JOIN construction.cleaned_projects AS p
        ON COALESCE(b.project_id, c.project_id_clean) = p.project_id
)

SELECT
    project_id,
    cost_category,
    COUNT(*) AS row_count
FROM budget_vs_actual
GROUP BY
    project_id,
    cost_category
HAVING COUNT(*) > 1;

-- Passed: 0 duplicate project/category groups.
-- The report retains one row per project and cost category.


-- 5H: CHECK DATA-QUALITY FLAG COUNTS

-- Count rows flagged for missing original budgets, orphan projects,
-- and no matching transactions.
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

budget_vs_actual AS (
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
        c.project_id_clean IS NULL AS no_matching_transactions_flag
    FROM budget_summary AS b
    FULL OUTER JOIN cost_summary AS c
        ON b.project_id = c.project_id_clean
        AND b.cost_category_clean = c.cost_category_clean
    LEFT JOIN construction.cleaned_projects AS p
        ON COALESCE(b.project_id, c.project_id_clean) = p.project_id
)

SELECT
    COUNT(*) FILTER (
        WHERE original_budget_missing_flag = TRUE
    ) AS original_budget_missing_flag_true_count,
    COUNT(*) FILTER (
        WHERE orphan_project_flag = TRUE
    ) AS orphan_project_flag_true_count,
    COUNT(*) FILTER (
        WHERE no_matching_transactions_flag = TRUE
    ) AS no_matching_transactions_flag_true_count
FROM budget_vs_actual;

-- Passed: Missing original budget = 1; orphan project = 1;
-- no matching transactions = 97.


-- 5I: Validate the budget_vs_actual view totals.
SELECT
    SUM(revised_budget) AS revised_budget_total,
    SUM(pending_exposure) AS pending_exposure_total,
    SUM(incurred_cost) AS incurred_cost_total
FROM construction.budget_vs_actual_report;
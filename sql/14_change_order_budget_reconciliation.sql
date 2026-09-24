-- Purpose: Compare estimated costs of approved change orders with
-- supplied budget adjustments to investigate whether those costs
-- are already reflected in revised budgets.
--
-- Sources:
--   construction.cleaned_change_orders
--   construction.cleaned_project_budgets
--
-- Comparison grain: One row per project_id.
--
-- Scope: All supplied approved change orders, without an approval-date
-- cutoff, compared with supplied budget adjustments.
--
-- Limitations:
-- Matching project totals do not prove inclusion of individual change
-- orders or their allocation across budget cost categories.
-- Budget effective dates are unavailable, so this comparison cannot
-- establish budget validity as of June 30, 2026.


-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Investigation 1: Sum supplied approved budget adjustments by project.
-- This establishes the budget-side total for comparison.
SELECT
    project_id,
    SUM(approved_budget_change_clean) AS approved_budget_change_total
FROM construction.cleaned_project_budgets
GROUP BY project_id
ORDER BY project_id;


-- Investigation 2: Sum estimated cost changes for approved change
-- orders by project. This establishes the change-order-side total.
SELECT
    project_id,
    SUM(estimated_cost_change_clean) AS estimated_cost_change_total
FROM construction.cleaned_change_orders
WHERE status_clean = 'approved'
GROUP BY project_id
ORDER BY project_id;


-- Investigation 3: Compare both totals at one row per project.
-- Aggregate each source before joining to prevent row multiplication.
-- Retain unmatched projects and preserve missing totals as NULL.
-- Difference direction: budget adjustment minus change-order cost.
WITH budget_adjustments AS (
    SELECT
        project_id,
        SUM(approved_budget_change_clean) AS approved_budget_change_total
    FROM construction.cleaned_project_budgets
    GROUP BY project_id
),
approved_change_orders AS (
    SELECT
        project_id,
        SUM(estimated_cost_change_clean) AS estimated_cost_change_total
    FROM construction.cleaned_change_orders
    WHERE status_clean = 'approved'
    GROUP BY project_id
)
SELECT
    COALESCE(ba.project_id, aco.project_id) AS project_id,
    ba.approved_budget_change_total,
    aco.estimated_cost_change_total,
    ba.approved_budget_change_total
        - aco.estimated_cost_change_total AS budget_minus_change_order_cost
FROM budget_adjustments AS ba
FULL OUTER JOIN approved_change_orders AS aco
    ON ba.project_id = aco.project_id
ORDER BY project_id;


-- Validation 1: Identify nonzero differences between comparable totals.
-- NULL comparisons are excluded; unmatched projects are checked below.
-- Expected result: 0 rows.
WITH budget_adjustments AS (
    SELECT
        project_id,
        SUM(approved_budget_change_clean) AS approved_budget_change_total
    FROM construction.cleaned_project_budgets
    GROUP BY project_id
),
approved_change_orders AS (
    SELECT
        project_id,
        SUM(estimated_cost_change_clean) AS estimated_cost_change_total
    FROM construction.cleaned_change_orders
    WHERE status_clean = 'approved'
    GROUP BY project_id
)
SELECT
    COALESCE(ba.project_id, aco.project_id) AS project_id,
    ba.approved_budget_change_total,
    aco.estimated_cost_change_total,
    ba.approved_budget_change_total
        - aco.estimated_cost_change_total AS budget_minus_change_order_cost
FROM budget_adjustments AS ba
FULL OUTER JOIN approved_change_orders AS aco
    ON ba.project_id = aco.project_id
WHERE ba.approved_budget_change_total
    <> aco.estimated_cost_change_total
ORDER BY project_id;


-- Validation 2: Inspect projects present on only one side.
-- Expected result: 38 rows, each with a budget adjustment of 0
-- and no matching approved-change-order total.
WITH budget_adjustments AS (
    SELECT
        project_id,
        SUM(approved_budget_change_clean) AS approved_budget_change_total
    FROM construction.cleaned_project_budgets
    GROUP BY project_id
),
approved_change_orders AS (
    SELECT
        project_id,
        SUM(estimated_cost_change_clean) AS estimated_cost_change_total
    FROM construction.cleaned_change_orders
    WHERE status_clean = 'approved'
    GROUP BY project_id
)
SELECT
    COALESCE(ba.project_id, aco.project_id) AS project_id,
    ba.approved_budget_change_total,
    aco.estimated_cost_change_total,
    ba.approved_budget_change_total
        - aco.estimated_cost_change_total AS budget_minus_change_order_cost
FROM budget_adjustments AS ba
FULL OUTER JOIN approved_change_orders AS aco
    ON ba.project_id = aco.project_id
WHERE ba.project_id IS NULL
   OR aco.project_id IS NULL
ORDER BY project_id;


-- Findings:
-- 1. No nonzero differences were found between comparable project totals.
-- 2. All 38 unmatched projects have zero supplied budget adjustments
--    and no matching approved change orders.
--
-- Interpretation:
-- Project-level totals support treating estimated costs of approved
-- change orders as already reflected in supplied budget adjustments.
-- Aggregate agreement does not establish individual change-order
-- inclusion or allocation across budget cost categories.
--
-- Analytical decision:
-- Use supplied revised budgets without adding estimated costs of
-- approved change orders again, which would duplicate adjustments
-- under this interpretation.
--
-- Reporting limitation:
-- This comparison uses all supplied approved change orders without
-- an approval-date cutoff. Budget effective dates are unavailable,
-- so agreement does not establish budget validity as of June 30, 2026.

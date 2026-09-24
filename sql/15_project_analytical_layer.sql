-- Purpose:
-- Build a project-level analytical layer to help identify
-- which active projects need attention.

-- Grain:
-- One row per project ID from cleaned_projects.
-- Retain all projects; filter to active projects for this question.

-- Reporting cutoff:
-- June 30, 2026.

-- Cost approach:
-- Include non-payroll transactions dated on or before the cutoff
-- with payment statuses of paid, approved, or applied.
-- Include employee labor costs for work performed on or before
-- the cutoff. Keep pending transaction exposure separate.
-- Aggregate each cost source separately by cleaned project ID
-- before joining, preventing row multiplication.
-- Add the two project-level totals to calculate incurred cost.


-- Step 1: Aggregate non-payroll incurred costs by project
-- through June 30, 2026.
SELECT
    project_id_clean,
    SUM(amount_clean) AS non_payroll_incurred_cost
FROM construction.cleaned_cost_transactions
WHERE payment_status_clean IN ('paid', 'approved', 'applied')
AND transaction_date <= DATE '2026-06-30'
GROUP BY project_id_clean;


-- Step 2: Aggregate labor incurred costs by project
-- through June 30, 2026.
SELECT
    project_id_clean,
    SUM(labor_cost_clean) AS labor_incurred_cost
FROM construction.cleaned_labor_entries
WHERE work_date_clean <= DATE '2026-06-30'
GROUP BY project_id_clean;


-- Step 3: Anchor analytical layer to cleaned_projects.
WITH non_payroll_costs AS (
    SELECT
        project_id_clean,
        SUM(amount_clean) AS non_payroll_incurred_cost
    FROM construction.cleaned_cost_transactions
    WHERE payment_status_clean IN ('paid', 'approved', 'applied')
    AND transaction_date <= DATE '2026-06-30'
    GROUP BY project_id_clean
),

labor_cost AS (
    SELECT
        project_id_clean,
        SUM(labor_cost_clean) AS labor_incurred_cost
    FROM construction.cleaned_labor_entries
    WHERE work_date_clean <= DATE '2026-06-30'
    GROUP BY project_id_clean
)

SELECT
    cp.project_id,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean;


-- Step 4: Aggregate the revised budget by project.
SELECT
    project_id,
    SUM(revised_budget_amount_clean) AS revised_budget_total
FROM construction.cleaned_project_budgets
GROUP BY project_id;


-- Step 5: Left join project-level revised budgets to the analytical
-- query, retaining all authoritative projects.
WITH non_payroll_costs AS (
    SELECT
        project_id_clean,
        SUM(amount_clean) AS non_payroll_incurred_cost
    FROM construction.cleaned_cost_transactions
    WHERE payment_status_clean IN ('paid', 'approved', 'applied')
    AND transaction_date <= DATE '2026-06-30'
    GROUP BY project_id_clean
),

labor_cost AS (
    SELECT
        project_id_clean,
        SUM(labor_cost_clean) AS labor_incurred_cost
    FROM construction.cleaned_labor_entries
    WHERE work_date_clean <= DATE '2026-06-30'
    GROUP BY project_id_clean
),

project_budget AS (
    SELECT
        project_id,
        SUM(revised_budget_amount_clean) AS revised_budget_total
    FROM construction.cleaned_project_budgets
    GROUP BY project_id
)

SELECT
    cp.project_id,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id;


-- Step 6: Check whether each active project has an update
-- dated June 30, 2026.
SELECT
    cp.project_id,
    pu.update_id,
    pu.report_date_clean,
    pu.estimated_cost_to_complete_clean
FROM construction.cleaned_projects AS cp
LEFT JOIN construction.cleaned_project_updates AS pu
    ON cp.project_id = pu.project_id
      AND pu.report_date_clean = DATE '2026-06-30'
WHERE cp.project_status_clean = 'active';


-- Step 7: Select remaining-cost estimates reported on June 30, 2026.
SELECT
    project_id,
    report_date_clean,
    estimated_cost_to_complete_clean
FROM construction.cleaned_project_updates
WHERE report_date_clean = DATE '2026-06-30';

-- Check for multiple updates per project on June 30, 2026.
SELECT
    project_id,
    COUNT(*) AS update_count
FROM construction.cleaned_project_updates
WHERE report_date_clean = DATE '2026-06-30'
GROUP BY project_id
HAVING COUNT(*) > 1;
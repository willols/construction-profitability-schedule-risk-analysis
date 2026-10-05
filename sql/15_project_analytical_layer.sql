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

-- Column definitions:
--
-- Total incurred cost:
-- Non-payroll incurred cost plus employee labor cost through June 30, 2026.
--
-- Estimated cost to complete (ETC):
-- The June 30 estimate of costs required to finish the remaining work.
-- Fictional-case assumption: includes all remaining costs, including labor,
-- and excludes costs already incurred at the update date.
-- Missing ETC remains NULL; it is not treated as zero.
--
-- Forecast final cost:
-- Total incurred cost plus ETC.
-- An estimate of the project's total cost at completion, not a final result.
--
-- Forecast budget variance:
-- Forecast final cost minus revised budget.
-- Positive = forecast over budget; negative = forecast under budget.
-- Zero = forecast exactly on budget.
--
-- Forecast budget variance percentage:
-- Forecast budget variance divided by revised budget, multiplied by 100.
-- Shows the forecast overrun or underrun relative to the project's budget.
-- A zero revised budget returns NULL because the percentage is undefined.
-- Missing inputs also leave the percentage NULL.

-- Original contract value (original_contract_value_clean):
-- Cleaned contract value before change-order revenue adjustments.
--
-- Total revenue change (total_revenue_change):
-- Sum of revenue changes approved on or before June 30, 2026.
-- Zero when no qualifying changes exist; missing approval dates are excluded.
--
-- Revised contract revenue (revised_contract_revenue):
-- Original contract value plus total qualifying approved revenue changes.
--
-- Forecast profit (forecast_profit):
-- Revised contract revenue minus forecast final cost.
-- Positive means forecast profit; negative means forecast loss.
-- NULL means the forecast cannot be calculated from available inputs.
--
-- Approved change missing date flag (approved_change_missing_date_flag):
-- TRUE when a project has an approved change order with no approval date.
-- That change is excluded from cutoff revenue and needs review.
--
-- Forecast profit margin (forecast_profit_margin_pct):
-- forecast_profit / revised_contract_revenue * 100.
-- With positive revenue: positive means profit; zero means breaking even;
-- negative means loss.
-- NULL when revenue is zero or missing, or forecast profit is missing.

-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


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

-- Step 7A: Check for multiple updates per project on June 30, 2026.
SELECT
    project_id,
    COUNT(*) AS update_count
FROM construction.cleaned_project_updates
WHERE report_date_clean = DATE '2026-06-30'
GROUP BY project_id
HAVING COUNT(*) > 1;


-- Step 7B: Join cutoff updates to retain all projects, leaving
-- ETC NULL when no cutoff update exists.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
)

SELECT
    cp.project_id,
    cp.project_status_clean,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total,
    cu.report_date_clean,
    cu.estimated_cost_to_complete_clean
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id
LEFT JOIN cutoff_updates AS cu
    ON cp.project_id = cu.project_id;


-- Step 7C: Validate the joined output after adding cutoff updates.
-- Expect 96 rows, 96 distinct project IDs, and 18 active projects.
-- Expect no active projects missing a June 30 update or ETC.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
),

project_summary AS (
    SELECT
        cp.project_id,
        cp.project_status_clean,
        npc.non_payroll_incurred_cost,
        lc.labor_incurred_cost,
        npc.non_payroll_incurred_cost +
        lc.labor_incurred_cost AS total_incurred_cost,
        pb.revised_budget_total,
        cu.report_date_clean,
        cu.estimated_cost_to_complete_clean
    FROM construction.cleaned_projects AS cp
    LEFT JOIN non_payroll_costs AS npc
        ON cp.project_id = npc.project_id_clean
    LEFT JOIN labor_cost AS lc
        ON cp.project_id = lc.project_id_clean
    LEFT JOIN project_budget AS pb
        ON cp.project_id = pb.project_id
    LEFT JOIN cutoff_updates AS cu
        ON cp.project_id = cu.project_id
)

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT project_id) AS unique_project_id_count,
    COUNT(*) FILTER (
        WHERE project_status_clean = 'active'
    ) AS active_projects,
    COUNT(*) FILTER (
        WHERE project_status_clean = 'active'
        AND (report_date_clean IS NULL
        OR estimated_cost_to_complete_clean IS NULL)
    ) AS active_projects_missing_cutoff_data
FROM project_summary;


-- PASS: 96 unique projects retained,
-- with cutoff data available for all 18 active projects.


-- Step 8: Calculate forecast final cost by adding total incurred cost
-- through June 30 to the estimated cost to complete at that date.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
)

SELECT
    cp.project_id,
    cp.project_status_clean,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total,
    cu.report_date_clean,
    cu.estimated_cost_to_complete_clean,
    total_incurred_cost + estimated_cost_to_complete_clean
    AS forecast_final_cost,
    forecast_final_cost - revised_budget_total
    AS forecast_budget_variance
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id
LEFT JOIN cutoff_updates AS cu
    ON cp.project_id = cu.project_id;



-- Step 8A: Identify active projects forecast to finish over revised budget.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
)

SELECT
    cp.project_id,
    cp.project_status_clean,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total,
    cu.report_date_clean,
    cu.estimated_cost_to_complete_clean,
    total_incurred_cost + estimated_cost_to_complete_clean
    AS forecast_final_cost,
    forecast_final_cost - revised_budget_total
    AS forecast_budget_variance
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id
LEFT JOIN cutoff_updates AS cu
    ON cp.project_id = cu.project_id
WHERE
    cp.project_status_clean = 'active'
    AND forecast_budget_variance > 0
ORDER BY forecast_budget_variance DESC;


-- Step 8B: Calculate forecast budget variance as a percentage.
-- Divide forecast_budget_variance by revised_budget_total and multiply by 100.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
)

SELECT
    cp.project_id,
    cp.project_status_clean,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total,
    cu.report_date_clean,
    cu.estimated_cost_to_complete_clean,
    total_incurred_cost + estimated_cost_to_complete_clean
    AS forecast_final_cost,
    forecast_final_cost - revised_budget_total
    AS forecast_budget_variance,
    ROUND((forecast_budget_variance /
    NULLIF(revised_budget_total, 0)) * 100.0, 2
    ) AS forecast_budget_variance_pct
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id
LEFT JOIN cutoff_updates AS cu
    ON cp.project_id = cu.project_id;


-- Step 9: Reconcile non-payroll incurred costs.
-- Compare eligible source transactions with the all-project analytical output.
-- Both queries use paid, approved, and applied transactions through June 30, 2026.
-- Account for unmatched project costs separately before closing reconciliation.


-- Step 9A: Calculate the eligible source transaction total.
SELECT
    SUM(amount_clean) AS non_payroll_total
FROM construction.cleaned_cost_transactions
WHERE payment_status_clean IN ('paid', 'approved', 'applied')
AND transaction_date <= DATE '2026-06-30';


-- Step 9B: Rebuild the all-project analytical output and total its
-- non-payroll incurred costs. Do not filter by status or forecast variance.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
),

project_summary AS (
    SELECT
        cp.project_id,
        cp.project_status_clean,
        npc.non_payroll_incurred_cost,
        lc.labor_incurred_cost,
        npc.non_payroll_incurred_cost +
        lc.labor_incurred_cost AS total_incurred_cost,
        pb.revised_budget_total,
        cu.report_date_clean,
        cu.estimated_cost_to_complete_clean,
        total_incurred_cost + estimated_cost_to_complete_clean
        AS forecast_final_cost,
        forecast_final_cost - revised_budget_total
        AS forecast_budget_variance,
        ROUND((forecast_budget_variance /
        NULLIF(revised_budget_total, 0)) * 100.0, 2
        ) AS forecast_budget_variance_pct
    FROM construction.cleaned_projects AS cp
    LEFT JOIN non_payroll_costs AS npc
        ON cp.project_id = npc.project_id_clean
    LEFT JOIN labor_cost AS lc
        ON cp.project_id = lc.project_id_clean
    LEFT JOIN project_budget AS pb
        ON cp.project_id = pb.project_id
    LEFT JOIN cutoff_updates AS cu
        ON cp.project_id = cu.project_id
)
-- Calculate the non-payroll total retained after the project joins.
SELECT
    SUM(non_payroll_incurred_cost) AS non_payroll_incurred_cost_total
FROM project_summary;

-- Observed results:
-- Eligible source total: 80,468,439.22.
-- Analytical output total: 80,468,439.22.
-- Difference: 0.00.
-- Overall totals match; see the unmatched-project check below.


-- Step 9C: Check whether any eligible cost transactions belong to project IDs
-- missing from cleaned_projects
SELECT
    ct.project_id_clean,
    ct.amount_clean
FROM construction.cleaned_cost_transactions AS ct
LEFT JOIN construction.cleaned_projects AS cp
    ON ct.project_id_clean = cp.project_id
WHERE payment_status_clean IN ('paid', 'approved', 'applied')
AND transaction_date <= DATE '2026-06-30'
AND cp.project_id IS NULL;

-- Result: 0 unmatched eligible transactions.
-- Non-payroll source and analytical totals reconcile with a 0.00 difference.


-- Step 10: Reconcile employee labor costs.
-- Compare eligible source labor costs with the all-project analytical output.
-- Both queries include work_date_clean on or before June 30, 2026.
-- Account for unmatched project labor costs separately before closing reconciliation.


-- Step 10A: Calculate the eligible source labor cost total.
SELECT
    SUM(labor_cost_clean) AS labor_incurred_cost
FROM construction.cleaned_labor_entries
WHERE work_date_clean <= DATE '2026-06-30';


-- Step 10B: Sum the labor_incurred_cost from project_summary.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
),

project_summary AS (
    SELECT
        cp.project_id,
        cp.project_status_clean,
        npc.non_payroll_incurred_cost,
        lc.labor_incurred_cost,
        npc.non_payroll_incurred_cost +
        lc.labor_incurred_cost AS total_incurred_cost,
        pb.revised_budget_total,
        cu.report_date_clean,
        cu.estimated_cost_to_complete_clean,
        total_incurred_cost + estimated_cost_to_complete_clean
        AS forecast_final_cost,
        forecast_final_cost - revised_budget_total
        AS forecast_budget_variance,
        ROUND((forecast_budget_variance /
        NULLIF(revised_budget_total, 0)) * 100.0, 2
        ) AS forecast_budget_variance_pct
    FROM construction.cleaned_projects AS cp
    LEFT JOIN non_payroll_costs AS npc
        ON cp.project_id = npc.project_id_clean
    LEFT JOIN labor_cost AS lc
        ON cp.project_id = lc.project_id_clean
    LEFT JOIN project_budget AS pb
        ON cp.project_id = pb.project_id
    LEFT JOIN cutoff_updates AS cu
        ON cp.project_id = cu.project_id
)
-- Calculate the labor cost total retained after the project joins.
SELECT
    SUM(labor_incurred_cost) AS labor_incurred_cost_total
FROM project_summary;

-- Observed results:
-- Eligible source total: 30917634.47.
-- Analytical output total: 30917634.47.
-- Difference: 0.00.
-- Overall totals match; see the unmatched-project check below.


-- Step 10C: check for unmatched labor project IDs
SELECT
    le.project_id_clean,
    le.labor_cost_clean
FROM construction.cleaned_labor_entries AS le
LEFT JOIN construction.cleaned_projects AS cp
    ON le.project_id_clean = cp.project_id
WHERE work_date_clean <= DATE '2026-06-30'
AND cp.project_id IS NULL;

-- Result reported during the session: 0 unmatched eligible labor entries.
-- Source and analytical labor totals both equal 30,917,634.47.
-- Difference: 0.00.


-- Step 11: Reconcile revised budgets.
-- Compare all supplied revised budgets with the all-project analytical output.
-- No date filter is applied: budget effective dates are unavailable.
-- Source total = retained analytical total + unmatched budget amounts.


-- Step 11A: Calculate the source revised-budget total.
SELECT
    SUM(revised_budget_amount_clean) AS source_revised_budget_total
FROM construction.cleaned_project_budgets;


-- Step 11B: Compare retained budgets with the source total, accounting
-- separately for budget rows whose project IDs have no authoritative match.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
),

project_summary AS (
    SELECT
        cp.project_id,
        cp.project_status_clean,
        npc.non_payroll_incurred_cost,
        lc.labor_incurred_cost,
        npc.non_payroll_incurred_cost +
        lc.labor_incurred_cost AS total_incurred_cost,
        pb.revised_budget_total,
        cu.report_date_clean,
        cu.estimated_cost_to_complete_clean,
        total_incurred_cost + estimated_cost_to_complete_clean
        AS forecast_final_cost,
        forecast_final_cost - revised_budget_total
        AS forecast_budget_variance,
        ROUND((forecast_budget_variance /
        NULLIF(revised_budget_total, 0)) * 100.0, 2
        ) AS forecast_budget_variance_pct
    FROM construction.cleaned_projects AS cp
    LEFT JOIN non_payroll_costs AS npc
        ON cp.project_id = npc.project_id_clean
    LEFT JOIN labor_cost AS lc
        ON cp.project_id = lc.project_id_clean
    LEFT JOIN project_budget AS pb
        ON cp.project_id = pb.project_id
    LEFT JOIN cutoff_updates AS cu
        ON cp.project_id = cu.project_id
),

budget_source_total AS (
    SELECT SUM(revised_budget_amount_clean) AS source_revised_budget_total
    FROM construction.cleaned_project_budgets
),

unmatched_budget_total AS (
    SELECT
        COUNT(*) AS unmatched_budget_rows,
        COALESCE(SUM(pb.revised_budget_amount_clean), 0) AS unmatched_budget_amount
    FROM construction.cleaned_project_budgets AS pb
    LEFT JOIN construction.cleaned_projects AS cp
        ON pb.project_id = cp.project_id
    WHERE cp.project_id IS NULL
),

analytical_budget_total AS (
    SELECT SUM(revised_budget_total) AS analytical_revised_budget_total
    FROM project_summary
)

SELECT
    s.source_revised_budget_total,
    a.analytical_revised_budget_total,
    u.unmatched_budget_rows,
    u.unmatched_budget_amount,
    s.source_revised_budget_total - a.analytical_revised_budget_total
        AS source_minus_analytical,
    s.source_revised_budget_total - a.analytical_revised_budget_total
        - u.unmatched_budget_amount AS unexplained_difference
FROM budget_source_total AS s
CROSS JOIN analytical_budget_total AS a
CROSS JOIN unmatched_budget_total AS u;
-- Expected: unexplained_difference = 0.00.
-- A nonzero source_minus_analytical is explainable if it equals unmatched budgets.
-- COALESCE is used only for the unmatched amount total when no amounts exist;
-- it does not replace missing project budgets in the analytical output.


-- Step 11C: Inspect unmatched budget rows and their amounts.
-- These rows remain outside the authoritative project analytical output.
SELECT
    pb.project_id,
    pb.revised_budget_amount_clean
FROM construction.cleaned_project_budgets AS pb
LEFT JOIN construction.cleaned_projects AS cp
    ON pb.project_id = cp.project_id
WHERE cp.project_id IS NULL;


-- Step 12: Validate combined incurred cost in the all-project output.
-- Compare the calculated total with the sum of its two cost components.
-- Also compare with 111,386,073.69, the sum of the separately validated
-- source totals: 80,468,439.22 non-payroll + 30,917,634.47 labor.
-- That reference is specific to the dataset validated on September 25, 2026.
-- Result pending execution against the project database.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
),

project_summary AS (
    SELECT
        cp.project_id,
        cp.project_status_clean,
        npc.non_payroll_incurred_cost,
        lc.labor_incurred_cost,
        npc.non_payroll_incurred_cost +
        lc.labor_incurred_cost AS total_incurred_cost,
        pb.revised_budget_total,
        cu.report_date_clean,
        cu.estimated_cost_to_complete_clean,
        total_incurred_cost + estimated_cost_to_complete_clean
        AS forecast_final_cost,
        forecast_final_cost - revised_budget_total
        AS forecast_budget_variance,
        ROUND((forecast_budget_variance /
        NULLIF(revised_budget_total, 0)) * 100.0, 2
        ) AS forecast_budget_variance_pct
    FROM construction.cleaned_projects AS cp
    LEFT JOIN non_payroll_costs AS npc
        ON cp.project_id = npc.project_id_clean
    LEFT JOIN labor_cost AS lc
        ON cp.project_id = lc.project_id_clean
    LEFT JOIN project_budget AS pb
        ON cp.project_id = pb.project_id
    LEFT JOIN cutoff_updates AS cu
        ON cp.project_id = cu.project_id
)

SELECT
    SUM(non_payroll_incurred_cost) AS non_payroll_total,
    SUM(labor_incurred_cost) AS labor_total,
    SUM(total_incurred_cost) AS combined_incurred_total,
    SUM(non_payroll_incurred_cost) + SUM(labor_incurred_cost)
        AS component_total,
    SUM(total_incurred_cost)
        - (SUM(non_payroll_incurred_cost) + SUM(labor_incurred_cost))
        AS component_difference,
    SUM(total_incurred_cost) - CAST(111386073.69 AS DECIMAL(18, 2))
        AS difference_from_validated_source_totals,
    COUNT(*) FILTER (
        WHERE non_payroll_incurred_cost IS NULL
           OR labor_incurred_cost IS NULL
           OR total_incurred_cost IS NULL
    ) AS projects_missing_cost_components
FROM project_summary;

-- Expected: combined_incurred_total = 111,386,073.69;
-- both differences = 0.00; projects_missing_cost_components = 0.


-- Schedule metrics plan
-- Assess active projects as of June 30, 2026.

-- Progress gap:
-- Calculate planned_pct_complete_clean - actual_pct_complete_clean.
-- Positive = behind plan; negative = ahead; zero = matches planned progress.
-- Measure the difference in percentage points.
-- Return NULL if either percentage is missing or outside 0–100.

-- Forecast completion delay:
-- Calculate forecast_completion_date_clean - baseline_completion_date_clean.
-- Use the forecast reported on June 30, 2026.
-- Positive = late; negative = early; zero = matches the baseline finish date.
-- Measure the difference in days.
-- Return NULL if either date is missing or the baseline date is unresolved.
-- Return NULL for forecast delay when the forecast finish is before the report date.

-- Preserve source values and data-quality flags.
-- Assess each metric independently using its required inputs.
-- Retain one row per project, even when a metric is NULL.


-- Step 13: Build one row per project with cost forecasts and schedule metrics
-- as of June 30, 2026, to support analysis of budget overruns and
-- schedule risk for active projects.
-- Include source values and data-quality flags to make the results
-- traceable, and return NULL when schedule inputs are missing or invalid.
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean,
        planned_pct_complete_clean,
        actual_pct_complete_clean,
        forecast_completion_date_clean,
        actual_pct_complete_out_of_range_flag,
        forecast_completion_date_missing_flag,
        forecast_before_report_flag
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
)

SELECT
    cp.project_id,
    cp.project_status_clean,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total,
    cu.report_date_clean,
    cu.estimated_cost_to_complete_clean,
    cu.planned_pct_complete_clean,
    cu.actual_pct_complete_clean,
    cu.forecast_completion_date_clean,
    cp.baseline_completion_date_clean,
    cu.actual_pct_complete_out_of_range_flag,
    cu.forecast_completion_date_missing_flag,
    cp.baseline_completion_date_unresolved_flag,
    cu.forecast_before_report_flag,
    total_incurred_cost + estimated_cost_to_complete_clean
    AS forecast_final_cost,
    forecast_final_cost - revised_budget_total
    AS forecast_budget_variance,
    ROUND(
        forecast_budget_variance / NULLIF(pb.revised_budget_total, 0) * 100,
        2
    ) AS forecast_budget_variance_pct,
    CASE
        WHEN cu.planned_pct_complete_clean IS NULL
        OR cu.actual_pct_complete_clean IS NULL
        OR cu.planned_pct_complete_clean < 0
        OR cu.planned_pct_complete_clean > 100
        OR cu.actual_pct_complete_clean < 0
        OR cu.actual_pct_complete_clean > 100 THEN NULL
        ELSE cu.planned_pct_complete_clean - cu.actual_pct_complete_clean
    END AS progress_gap_pp,
    CASE
        WHEN cu.forecast_completion_date_clean IS NULL
        OR cp.baseline_completion_date_clean IS NULL
        OR cp.baseline_completion_date_unresolved_flag = TRUE
        OR cu.forecast_before_report_flag = TRUE THEN NULL
        ELSE cu.forecast_completion_date_clean - cp.baseline_completion_date_clean
    END AS forecast_delay_days
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id
LEFT JOIN cutoff_updates AS cu
    ON cp.project_id = cu.project_id;


-- Step 13A: Validate that the analytical output retains one row per project.
-- Expected: 96 total rows and 96 distinct project IDs
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT project_id) AS unique_projects
FROM construction.project_summary;

-- PASS: Expected returned.


-- Step 13B: Check for missing or invalid progress inputs that produced a non-NULL gap.
-- Expected: 0 rows.
SELECT *
FROM construction.project_summary
WHERE (
    planned_pct_complete_clean < 0
    OR planned_pct_complete_clean > 100
    OR planned_pct_complete_clean IS NULL
    OR actual_pct_complete_clean < 0
    OR actual_pct_complete_clean > 100
    OR actual_pct_complete_clean IS NULL
)
AND progress_gap_pp IS NOT NULL;

-- PASS: Expected returned.


-- Step 13C: Check for missing or incorrect progress gaps when both inputs are valid.
-- Expected: 0 rows.
SELECT *
FROM construction.project_summary
WHERE (
    planned_pct_complete_clean BETWEEN 0 AND 100
    AND actual_pct_complete_clean BETWEEN 0 AND 100
) AND (
    progress_gap_pp IS NULL
    OR progress_gap_pp <>
    planned_pct_complete_clean - actual_pct_complete_clean
);

-- PASS: Expected returned.


-- Seto 13D: Check for unusable date inputs taht produce a non-NULL forecast delay.
-- Expected: 0 rows.
SELECT *
FROM construction.project_summary
WHERE (
    forecast_completion_date_clean IS NULL
    OR baseline_completion_date_clean IS NULL
    OR baseline_completion_date_unresolved_flag = TRUE
    OR forecast_before_report_flag = TRUE
)
AND forecast_delay_days IS NOT NULL;

-- PASS: Expected returned.


-- Step 13E: Check for missing or inconsistent forecast_delay_days
-- when both inputs and flags are valid.
-- Expected: 0 rows.
SELECT *
FROM construction.project_summary
WHERE (
    forecast_completion_date_clean IS NOT NULL
    AND baseline_completion_date_clean IS NOT NULL
    AND baseline_completion_date_unresolved_flag = FALSE
    AND forecast_before_report_flag = FALSE
)
AND (
    forecast_delay_days IS NULL
    OR forecast_delay_days <> forecast_completion_date_clean -
    baseline_completion_date_clean
);

-- PASS: Expected returned.


-- Step 13F: Check schedule data coverage for the active projects.
SELECT
    COUNT(*) FILTER (
        WHERE project_status_clean = 'active'
    ) AS active_project_count,
    COUNT(*) FILTER (
        WHERE project_status_clean = 'active'
        AND progress_gap_pp IS NOT NULL
    ) AS active_with_progress_gap_pp,
    COUNT(*) FILTER (
        WHERE project_status_clean = 'active'
        AND forecast_delay_days IS NOT NULL
    ) AS active_with_forecast_delay_days
FROM construction.project_summary;

-- Results:
-- 18 active projects all 18 contain usable progress gaps and 9 contain
-- usable forecast delays.


-- Step 13G: Inspect the 9 projects without usable forecast delays.
SELECT
    project_id,
    forecast_completion_date_clean,
    baseline_completion_date_clean,
    report_date_clean,
    baseline_completion_date_unresolved_flag,
    forecast_before_report_flag
FROM construction.project_summary
WHERE
    project_status_clean = 'active'
    AND forecast_delay_days IS NULL;

-- Results:
-- 8 outdated forecasts: completion dates earlier than the June 30 report date.
-- 1 missing forecast: P088 has no forecast completion date.
-- This explains why the 9 projects are null.


-- Step 13H: Check active projects for missing cleaned project records,
-- missing June 30 updates, or mismatched baseline completion dates.
SELECT
    ps.project_id,
    ps.baseline_completion_date_clean AS baseline_completion_project_summary,
    pc.baseline_completion_date_clean AS baseline_completion_cleaned_projects
FROM construction.project_summary AS ps
LEFT JOIN construction.cleaned_project_updates AS cpu
    ON ps.project_id = cpu.project_id
    AND cpu.report_date_clean = DATE '2026-06-30'
LEFT JOIN construction.cleaned_projects AS pc
    ON ps.project_id = pc.project_id
WHERE ps.project_status_clean = 'active'
  AND (
      pc.project_id IS NULL
      OR cpu.project_id IS NULL
      OR ps.baseline_completion_date_clean
          IS DISTINCT FROM pc.baseline_completion_date_clean
  );

-- PASS: No missing source matches or baseline completion date differences
-- found for active projects.


-- Step 13I: Compare active-project forecast completion dates
-- in project_summary against their June 30 cleaned updates.
SELECT
    ps.project_id,
    ps.forecast_completion_date_clean AS forecast_date_project_summary,
    cpu.forecast_completion_date_clean AS forecast_date_cleaned_project_updates
FROM construction.project_summary AS ps
LEFT JOIN construction.cleaned_project_updates AS cpu
    ON ps.project_id = cpu.project_id
    AND cpu.report_date_clean = DATE '2026-06-30'
WHERE
ps.project_status_clean = 'active'
    AND ps.forecast_completion_date_clean
    IS DISTINCT FROM cpu.forecast_completion_date_clean;

-- PASS: No missing source matches or forecast completion date differences
-- found for active projects.


-- Step 13J: Compare active-project planned and actual pct complete
-- in project_summary against their June 30 cleaned updates.
SELECT
    ps.project_id,
    ps.actual_pct_complete_clean AS project_summary_actual_pct,
    ps.planned_pct_complete_clean AS project_summary_planned_pct,
    cpu.actual_pct_complete_clean AS project_updates_actual_pct,
    cpu.planned_pct_complete_clean AS project_updates_planned_pct
FROM construction.project_summary AS ps
LEFT JOIN construction.cleaned_project_updates AS cpu
    ON ps.project_id = cpu.project_id
    AND cpu.report_date_clean = DATE '2026-06-30'
WHERE
ps.project_status_clean = 'active'
    AND (ps.actual_pct_complete_clean
    IS DISTINCT FROM cpu.actual_pct_complete_clean
    OR ps.planned_pct_complete_clean
    IS DISTINCT FROM cpu.planned_pct_complete_clean
    );

-- PASS: No missing source matches or pct complete differences
-- found for active projects.


-- Step 13K: Compare active-project report_date and 4 schedule flags
-- in project_summary against their June 30 cleaned updates and cleaned projects.
SELECT
    ps.project_id,
    ps.report_date_clean,
    cpu.report_date_clean,
    ps.actual_pct_complete_out_of_range_flag,
    cpu.actual_pct_complete_out_of_range_flag,
    ps.forecast_completion_date_missing_flag,
    cpu.forecast_completion_date_missing_flag,
    ps.forecast_before_report_flag,
    cpu.forecast_before_report_flag,
    ps.baseline_completion_date_unresolved_flag,
    cp.baseline_completion_date_unresolved_flag
FROM construction.project_summary AS ps
LEFT JOIN construction.cleaned_project_updates AS cpu
    ON ps.project_id = cpu.project_id
    AND cpu.report_date_clean = DATE '2026-06-30'
LEFT JOIN construction.cleaned_projects AS cp
    ON ps.project_id = cp.project_id
WHERE
ps.project_status_clean = 'active'
    AND
    ( ps.report_date_clean
    IS DISTINCT FROM cpu.report_date_clean
    OR  ps.actual_pct_complete_out_of_range_flag
    IS DISTINCT FROM cpu.actual_pct_complete_out_of_range_flag
    OR ps.forecast_completion_date_missing_flag
    IS DISTINCT FROM cpu.forecast_completion_date_missing_flag
    OR ps.forecast_before_report_flag
    IS DISTINCT FROM cpu.forecast_before_report_flag
    OR ps.baseline_completion_date_unresolved_flag
    IS DISTINCT FROM cp.baseline_completion_date_unresolved_flag
    );

-- PASS: No report-date or schedule-flag differences found for active projects.

-- Schedule validation is complete for construction.project_summary.
-- All 18 active projects have usable progress gaps; 9 have usable forecast delays.
-- The other 9 have unavailable forecast delays: 8 have forecast completion dates
-- before the June 30 report date, and P088 has no forecast completion date.
-- NULL forecast delays mean unavailable, not zero days late.


-- Revenue and forecast profitability:
-- Estimate each active project's profit at completion using information
-- available as of June 30, 2026.
--
-- Revised contract revenue is the original contract value plus the total
-- revenue changes approved by the cutoff. Billed amounts are not used.
-- Approved changes with missing approval dates are excluded, and affected
-- projects are flagged for review.
--
-- Forecast profit is revised contract revenue minus forecast final cost,
-- which includes incurred costs and estimated cost to complete.
-- If forecast final cost is unavailable, forecast profit remains NULL.


-- Step 14: Sum the approved revenue changes for each project that qualify.
SELECT
    cp.project_id,
    COALESCE(SUM(cco.approved_revenue_change_clean), 0) AS total_revenue_change
FROM construction.cleaned_projects AS cp
LEFT JOIN construction.cleaned_change_orders AS cco
    ON cp.project_id = cco.project_id
    AND cco.approval_date <= DATE '2026-06-30'
    AND cco.status_clean = 'approved'
GROUP BY cp.project_id;


-- Step 14A: Check for approved change orders that qualify by date but have unknown amount.
SELECT
    change_order_id,
    project_id,
    approved_revenue_change_clean
FROM construction.cleaned_change_orders
WHERE
    status_clean = 'approved'
    AND approval_date <= DATE '2026-06-30'
    AND approved_revenue_change_clean IS NULL;

-- PASS: No change orders approved by June 30 have missing approved revenue amounts.


-- Step 14B: Find approved change orders with missing approval dates.
SELECT
    change_order_id,
    project_id,
    approved_revenue_change_clean
FROM construction.cleaned_change_orders
WHERE approved_missing_approval_date_flag = TRUE;

-- FINDING: CO0001 (P001) has $23,877.11 in approved revenue changes
-- with no approval date. Excluded from cutoff revenue; flag P001 for review.


-- Step 14C: List each project with approved change orders missing approval dates
-- once, so we can flag it for review in the project summary.
SELECT DISTINCT
    project_id
FROM construction.cleaned_change_orders
WHERE approved_missing_approval_date_flag = TRUE;

-- Confirmed: P001 is the only project needing the missing-approval-date review flag.


-- Step 15: Extend project_summary with revised contract revenue,
-- forecast profit, and a missing-approval-date review flag.
CREATE OR REPLACE VIEW construction.project_summary AS
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
),

cutoff_updates AS (
    SELECT
        project_id,
        report_date_clean,
        estimated_cost_to_complete_clean,
        planned_pct_complete_clean,
        actual_pct_complete_clean,
        forecast_completion_date_clean,
        actual_pct_complete_out_of_range_flag,
        forecast_completion_date_missing_flag,
        forecast_before_report_flag
    FROM construction.cleaned_project_updates
    WHERE report_date_clean = DATE '2026-06-30'
),

approved_revenue_changes AS (
    SELECT
    cp.project_id,
    COALESCE(SUM(cco.approved_revenue_change_clean), 0) AS total_revenue_change
FROM construction.cleaned_projects AS cp
LEFT JOIN construction.cleaned_change_orders AS cco
    ON cp.project_id = cco.project_id
    AND cco.approval_date <= DATE '2026-06-30'
    AND cco.status_clean = 'approved'
GROUP BY cp.project_id
),

approval_date_review AS (
    SELECT DISTINCT
    project_id
FROM construction.cleaned_change_orders
WHERE approved_missing_approval_date_flag = TRUE
)

SELECT
    cp.project_id,
    cp.project_status_clean,
    npc.non_payroll_incurred_cost,
    lc.labor_incurred_cost,
    npc.non_payroll_incurred_cost +
    lc.labor_incurred_cost AS total_incurred_cost,
    pb.revised_budget_total,
    cu.report_date_clean,
    cu.estimated_cost_to_complete_clean,
    cu.planned_pct_complete_clean,
    cu.actual_pct_complete_clean,
    cu.forecast_completion_date_clean,
    cp.baseline_completion_date_clean,
    cu.actual_pct_complete_out_of_range_flag,
    cu.forecast_completion_date_missing_flag,
    cp.baseline_completion_date_unresolved_flag,
    cu.forecast_before_report_flag,
    total_incurred_cost + estimated_cost_to_complete_clean
    AS forecast_final_cost,
    forecast_final_cost - revised_budget_total
    AS forecast_budget_variance,
    ROUND(
        forecast_budget_variance / NULLIF(pb.revised_budget_total, 0) * 100,
        2
    ) AS forecast_budget_variance_pct,
    CASE
        WHEN cu.planned_pct_complete_clean IS NULL
        OR cu.actual_pct_complete_clean IS NULL
        OR cu.planned_pct_complete_clean < 0
        OR cu.planned_pct_complete_clean > 100
        OR cu.actual_pct_complete_clean < 0
        OR cu.actual_pct_complete_clean > 100 THEN NULL
        ELSE cu.planned_pct_complete_clean - cu.actual_pct_complete_clean
    END AS progress_gap_pp,
    CASE
        WHEN cu.forecast_completion_date_clean IS NULL
        OR cp.baseline_completion_date_clean IS NULL
        OR cp.baseline_completion_date_unresolved_flag = TRUE
        OR cu.forecast_before_report_flag = TRUE THEN NULL
        ELSE cu.forecast_completion_date_clean - cp.baseline_completion_date_clean
    END AS forecast_delay_days,
    cp.original_contract_value_clean,
    arc.total_revenue_change,
    cp.original_contract_value_clean +
    arc.total_revenue_change AS revised_contract_revenue,
    revised_contract_revenue - forecast_final_cost AS
    forecast_profit,
    -- Add forecast_profit_margin_pct to construction.project_summary.
-- Purpose: Compare forecast profitability across projects of different sizes.
-- Definition: forecast_profit / revised_contract_revenue * 100.
-- Return NULL when revised_contract_revenue is zero or missing,
-- or when forecast_profit is missing.
-- With positive revenue, zero profit means breaking even;
-- negative profit means a forecast loss.
    CASE
        WHEN revised_contract_revenue = 0
            OR revised_contract_revenue IS NULL
            OR forecast_profit IS NULL
        THEN NULL
        ELSE ROUND(
            forecast_profit / revised_contract_revenue * 100,
            2
        )
    END AS forecast_profit_margin_pct,
    adr.project_id IS NOT NULL AS approved_change_missing_date_flag
FROM construction.cleaned_projects AS cp
LEFT JOIN non_payroll_costs AS npc
    ON cp.project_id = npc.project_id_clean
LEFT JOIN labor_cost AS lc
    ON cp.project_id = lc.project_id_clean
LEFT JOIN project_budget AS pb
    ON cp.project_id = pb.project_id
LEFT JOIN cutoff_updates AS cu
    ON cp.project_id = cu.project_id
LEFT JOIN approved_revenue_changes AS arc
    ON cp.project_id = arc.project_id
LEFT JOIN approval_date_review AS adr
    ON cp.project_id = adr.project_id;



-- Step 15A: Check row count and project ID count in updated view.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT project_id) AS unique_project_ids
FROM construction.project_summary;


-- Step 15B: Check that the review flag reached the saved view.
SELECT
    project_id,
    total_revenue_change,
    approved_change_missing_date_flag
FROM construction.project_summary
WHERE approved_change_missing_date_flag = TRUE;

-- PASS: Only P001 is flagged, matching soure finding.


-- Step 15C: Compare saved revenue-change total with qualifying
-- approved change-order total from the cleaned source.
WITH source_revenue_change AS (
    SELECT
    cp.project_id,
    COALESCE(SUM(cco.approved_revenue_change_clean), 0) AS total_revenue_change
FROM construction.cleaned_projects AS cp
LEFT JOIN construction.cleaned_change_orders AS cco
    ON cp.project_id = cco.project_id
    AND cco.approval_date <= DATE '2026-06-30'
    AND cco.status_clean = 'approved'
GROUP BY cp.project_id
)

SELECT
    ps.project_id,
    src.total_revenue_change AS source_revenue_change,
    ps.total_revenue_change AS summary_revenue_change
FROM construction.project_summary AS ps
LEFT JOIN source_revenue_change AS src
    ON ps.project_id = src.project_id
WHERE
    ps.total_revenue_change
    IS DISTINCT FROM src.total_revenue_change;

-- PASS: Every saved revenue change total mathes the qualifying source total.


-- Step 15D: Check revised contract revenue and forecast profit
-- against their expected calculations.
SELECT *
FROM construction.project_summary
WHERE revised_contract_revenue IS DISTINCT FROM
      (original_contract_value_clean + total_revenue_change)
   OR forecast_profit IS DISTINCT FROM
      (revised_contract_revenue - forecast_final_cost);

-- PASS: No differences found between revised contract revenue,
-- forecast profit, and their expected calculations.


-- Step 15E: Check forecast_profit_margin_pct NULL handling.
-- Find rows where revenue is zero or missing, or forecast profit is missing,
-- but forecast_profit_margin_pct is NOT NULL.
-- Expected: Zero rows.
SELECT *
FROM construction.project_summary
WHERE (
    revised_contract_revenue IS NULL
    OR revised_contract_revenue = 0
    OR forecast_profit IS NULL
)
AND forecast_profit_margin_pct IS NOT NULL;

-- PASS: Zero rows returned.


-- 15F: Calculation accuracy for forecast_profit_margin_pct.
-- Expected: Zero rows.
SELECT *
FROM construction.project_summary
WHERE forecast_profit_margin_pct IS DISTINCT FROM
    ROUND(
        forecast_profit / NULLIF(revised_contract_revenue, 0) * 100,
        2
    );

-- PASS: Zero rows returned.


-- Step 16: Check June 30 update coverage by project status.
-- Count projects with and without a June 30, 2026 update in each status.
-- In project_summary, a NULL report_date_clean means no June 30 update matched.
-- Use these counts to inform forecast treatment for completed and on-hold projects.
SELECT
    project_status_clean,
    COUNT(*) AS totals,
    COUNT(report_date_clean) AS projects_with_30th_report_date,
    COUNT(*) - COUNT(report_date_clean) AS projects_without_30th_report_date
FROM construction.project_summary
GROUP BY project_status_clean;

-- Findings:
-- All 18 active and all 3 on-hold projects have a June 30 update.
-- None of the 75 completed projects has a June 30 update.
-- Completed projects therefore have NULL update fields in this view.
-- Next: Inspect ETC values for the 3 on-hold projects.


-- Step 16A: Inspect ETC values for the 3 on-hold projects.
SELECT
    project_id,
    estimated_cost_to_complete_clean
FROM construction.project_summary
WHERE project_status_clean = 'on_hold';

-- Findings:
-- All three projects with status 'on_hold' contain ETCs.

-- Decision:
-- Keep all 96 projects in the analytical layer.
-- Focus the main analysis on active projects; review on-hold projects separately.
-- Leave unavailable forecasts for completed projects as NULL.
-- Do not replace missing ETC with zero: missing estimates do not mean
-- there are no remaining costs.

SELECT *
FROM construction.project_summary;
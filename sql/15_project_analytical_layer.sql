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

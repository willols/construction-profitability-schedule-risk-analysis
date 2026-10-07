-- Project Profitability and Schedule-Risk Analysis
-- Reporting cutoff: June 30, 2026
-- Purpose: Identify projects needing attention, investigate potential risk
-- drivers, and inform future estimating and planning.
-- Main scope: 18 active projects. Review on-hold projects separately.
-- Primary source: construction.project_summary.
-- Document data limitations alongside the findings.

-- Question 1: What are the overall forecast revenue, cost, profit,
-- and profit margin for active projects?

-- Approach:
-- I will use: revised_contract_revenue for revenue, forecast_final_cost
-- for forecast cost, and forecast_profit for forecast profit.
-- I will sum all three of these and filter to active
-- projects using project_status_clean.

-- Summarize revenue, forecast final cost, forecast profit,
-- and overall forecast profit margin for active projects.
SELECT
    SUM(revised_contract_revenue) AS revenue,
    SUM(forecast_final_cost) AS forecast_cost,
    SUM(forecast_profit) AS forecast_profit,
    ROUND(
        SUM(forecast_profit) / NULLIF(SUM(revised_contract_revenue), 0) * 100,
        2
    ) AS forecast_profit_margin_pct
FROM construction.project_summary
WHERE project_status_clean = 'active';


-- Findings:
-- As of June 30, 2026, the 18 active projects have total revised contract
-- revenue of $25,229,253.42 and forecast final costs of $20,541,689.57.
-- Total forecast profit is $4,687,563.85, with a combined margin of 18.58%.
-- This represents about $18.58 in forecast project profit per $100 of revenue.
-- The combined margin does not show differences between individual projects.


-- Question 2: Which active projects forecast losses or have the lowest margins?

-- Approach:
-- Use two queries to answer the two parts separately.
--
-- First: Identify active projects forecasting a loss.
-- Select project_id and forecast_profit.
-- Filter to active projects using project_status_clean
-- and keep only projects where forecast_profit < 0.
-- Order by forecast_profit from lowest to highest,
-- placing the largest dollar loss first.
--
-- Second: Identify active projects with the lowest forecast margins.
-- Select project_id and forecast_profit_margin_pct.
-- Filter to active projects using project_status_clean,
-- including projects that remain profitable.
-- Order by forecast_profit_margin_pct from lowest to highest.


-- Identify active projects forecasting a loss
SELECT
    project_id,
    forecast_profit
FROM construction.project_summary
WHERE project_status_clean = 'active'
    AND forecast_profit < 0
ORDER BY forecast_profit;

-- Findings:
-- As of June 30, 2026, all 18 active projects have positive
-- forecast profit; none are forecast to make a loss.


-- Identify active projects with the lowest forecast margins
SELECT
    project_id,
    forecast_profit_margin_pct
FROM construction.project_summary
WHERE project_status_clean = 'active'
ORDER BY forecast_profit_margin_pct;

-- Findings:
-- As of June 30, 2026, the active projects with the lowest forecast
-- profit margins are P083 (7.65%), P093 (7.99%), and P078 (11.88%).
-- This ranking does not show whether they meet their target margins.


-- Question 3: Which active projecs forecast budget overruns, and by how much?


-- Approach:
-- Identify active projects with positive forecast budget variance.
-- Show project_id and the forecast overrun in dollars and as a
-- percentage of revised budget. Order by largest dollar overrun first.
SELECT
    project_id,
    forecast_budget_variance,
    forecast_budget_variance_pct
FROM construction.project_summary
WHERE project_status_clean = 'active'
    AND forecast_budget_variance > 0
ORDER BY forecast_budget_variance DESC;

-- Findings:
-- As of June 30, 2026, 9 of 18 active projects forecast budget overruns.
-- The three largest dollar overruns are:
-- P093: $183,801.99 (7.48% of revised budget).
-- P083: $84,680.99 (7.59% of revised budget).
-- P089: $59,521.15 (6.08% of revised budget).
-- P093 has the largest dollar overrun, while P083 has a higher
-- percentage overrun.
-- Budget overruns do not necessarily mean forecast losses:
-- Question 2 found that all 18 active projects forecast positive profit.


-- Question 4: Which active projects are behind planned progress or forecast
-- to finish late?

-- Approach:
-- I need to identify active projects with a forecast completion date later
-- than the baseline completion date and a progress gap.
-- I will use forecast_delay_days with a filter for forecast_delay_days greater
-- than zero and progress_gap_pp for the progress gap with filter greater than zero
-- and active projects using project_status_clean,
-- then ordering by largest to smallest.
SELECT
    project_id,
    forecast_delay_days,
    progress_gap_pp
FROM construction.project_summary
WHERE project_status_clean = 'active'
    AND (forecast_delay_days > 0
    OR progress_gap_pp > 0)
ORDER BY forecast_delay_days DESC NULLS LAST,
        progress_gap_pp DESC,
        project_id;

-- Findings:
-- As of June 30, 2026, 17 of 18 active projects are behind planned
-- progress, forecast to finish late, or both.
-- Of these 17 projects, 9 have positive forecast delays and 8 have
-- unavailable forecast delays (NULL). NULL does not mean on time.
--
-- P089 has the largest forecast delay at 36 days and is
-- 14.8 percentage points behind planned progress.
-- P078 has the largest progress gap at 16.4 percentage points
-- behind plan and is forecast to finish 34 days late.
--
-- P087 is 3.3 percentage points ahead of planned progress but is
-- forecast to finish 6 days late. Progress against plan and forecast
-- completion delay measure different aspects of schedule performance.
--
-- Across all 18 active projects, only 9 have usable forecast delays.
-- The other 9 cannot be classified as on time or late using this metric.


-- Question 5: Which active projects deserve attention first based on
-- financial and schedule risks?

-- Approach:
-- Identify active projects with a forecast budget overrun and
-- at least one schedule concern: behind planned progress or
-- forecast to finish late.
-- Show forecast budget variance in dollars and percent, forecast
-- profit margin, forecast delay days, and progress gap.
-- A NULL forecast delay means unknown; a project can still qualify
-- if it has a positive progress gap.
-- Order by largest dollar overrun first for initial review.
-- This shortlist and display order are not a final risk ranking.

-- Identify active projects with both financial and schedule concerns.
SELECT
    project_id,
    forecast_budget_variance,
    forecast_budget_variance_pct,
    forecast_profit_margin_pct,
    forecast_delay_days,
    progress_gap_pp
FROM construction.project_summary
WHERE project_status_clean = 'active'
    AND forecast_budget_variance > 0
    AND (
        forecast_delay_days > 0
        OR progress_gap_pp > 0
    )
ORDER BY forecast_budget_variance DESC;

-- Findings:
-- As of June 30, 2026, 9 active projects forecast budget overruns
-- and have at least one known schedule concern.
-- Recommend P093, P089, P078, P083, and P080 for initial review.
-- This group emphasizes dollar overruns and forecast delay days,
-- with profit margins and progress gaps providing supporting context.
-- These are review priorities, not a definitive ranking.
--
-- P093: Largest forecast overrun at $183,801.99, a 32-day forecast
-- delay, 13.3 pp behind plan, and a 7.99% forecast profit margin.
--
-- P089: Largest known forecast delay at 36 days, with a $59,521.15
-- overrun and progress 14.8 pp behind plan.
--
-- P078: Largest progress gap at 16.4 pp behind plan, a 34-day
-- forecast delay, and a $55,444.24 overrun.
--
-- P083: Second-largest dollar overrun at $84,680.99 and the lowest
-- forecast profit margin at 7.65%. Progress is 6.8 pp behind plan.
-- Its forecast delay is unknown and needs clarification.
--
-- P080: A $22,126.97 overrun and a 24-day forecast delay support
-- inclusion. Its delay exceeds P082's 12 days and P081's 22 days,
-- although P081 has a larger progress gap.
--
-- Limitations:
-- NULL delays mean unknown, not on time.
-- All shortlisted projects still forecast positive profit.
-- The shortlist requires both financial and schedule concerns;
-- severe issues on only one side may also warrant review.
-- Final priorities should be confirmed with project managers.


-- Question 6: What appears to drive risk in the priority projects?

-- Approach:
-- Start with P093 because it has the largest forecast budget overrun
-- among active projects.
--
-- First, inspect the project-level cost picture using total_incurred_cost,
-- revised_budget_total, actual_pct_complete_clean, and
-- estimated_cost_to_complete_clean.
-- Compare incurred costs with the revised budget and reported progress,
-- and compare ETC with the remaining budget.
-- These comparisons indicate cost pressure but do not establish its cause.
--
-- Then, compare incurred costs, including employee labor, with revised
-- budgets by cost category to identify spending concentrations and
-- categories that have already exceeded their budgets.
-- Without category-level progress or ETC, this comparison cannot determine
-- each category's forecast overrun.


-- Project-level query for P093
SELECT
    project_id,
    total_incurred_cost,
    revised_budget_total,
    actual_pct_complete_clean,
    estimated_cost_to_complete_clean
FROM construction.project_summary
WHERE project_id = 'P093';
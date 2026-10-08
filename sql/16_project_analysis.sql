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

-- Findings:
-- P093 has incurred costs of 1,720,860.62 against a revised budget
-- of 2,457,900.00, with reported completion of 64.6%.
-- Remaining budget is 737,039.38, while ETC is 920,841.37.
-- ETC exceeds the remaining budget by 183,801.99, indicating
-- a forecast budget overrun.
--
-- Next: Compare incurred costs with revised budgets by category
-- to identify spending concentrations and categories already over budget.
-- Category-level progress and ETC are unavailable, so this comparison
-- cannot establish causes or allocate the forecast overrun by category.


-- Compare incurred costs with revised budget by category.
SELECT
    cost_category,
    revised_budget,
    incurred_cost,
    budget_remaining,
    ROUND(incurred_cost / NULLIF(revised_budget, 0) * 100, 2
      )AS budget_spent_pct
FROM construction.budget_vs_actual_report
WHERE project_id = 'P093'
ORDER BY budget_spent_pct DESC;

-- Findings:
-- No cost category has exceeded its revised budget so far.
-- Labor has the highest budget usage at 77.30%, followed by
-- General Conditions at 73.05% and Materials at 72.58%.
-- Category-level progress and ETC are unavailable, so these results
-- cannot establish the causes of the forecast overrun or allocate
-- it by category.

-- Follow-up for P093's forecast overrun:
-- Request category-level ETC and progress from the project manager,
-- along with an explanation of changes in remaining quantities,
-- labor hours, rates, rework, or scope.
-- This would help identify which categories forecast overruns
-- and investigate the reasons for the revised estimate.


-- Schedule investigation into P093.

-- Approach:
-- Use progress_gap_pp to check whether reported actual progress
-- is ahead of or behind planned progress as of June 30, 2026.
-- Use forecast_delay_days to check whether forecast completion
-- is earlier or later than baseline completion.
SELECT
    project_id,
    progress_gap_pp,
    forecast_delay_days
FROM construction.project_summary
WHERE project_id = 'P093';

-- Findings:
-- As of June 30, P093's reported actual progress is 13.3 percentage
-- points behind plan. Forecast completion is 32 days later than baseline.
-- These results identify schedule concerns but do not establish their causes.


-- Next I will inspect P093's updates through June 30 to see whether
-- its schedule position improved or worsened over time.

-- Approach:
-- Inspect P093's cleaned updates through June 30, ordered by report date.
-- Calculate progress gap as planned_pct_complete_clean minus
-- actual_pct_complete_clean, measured in percentage points.
-- Include forecast_completion_date_clean to see whether the
-- expected finish moved earlier or later across updates.


-- Inspect P093's cleaned updates through June 30th.
SELECT
    project_id,
    report_date_clean,
    planned_pct_complete_clean,
    actual_pct_complete_clean,
    planned_pct_complete_clean - actual_pct_complete_clean
      AS progress_gap_pp,
    forecast_completion_date_clean
FROM construction.cleaned_project_updates
WHERE project_id = 'P093'
    AND report_date_clean <= DATE '2026-06-30'
ORDER BY report_date_clean;

-- Findings:
-- P093's progress gap narrowed from 3.6 to 0.3 percentage points
-- between January and February, then stayed around 4.5–4.8 through May.
-- It widened to 9.0 on June 11 and 13.3 on June 30, indicating
-- worsening progress against plan in June.
--
-- Forecast completion moved later at every update, from September 3
-- to September 23: a cumulative shift of 20 days.
-- At June 30, forecast completion was 32 days later than baseline.
--
-- These trends show deteriorating schedule performance but do not
-- establish its causes.


-- I need to add the notes for the updates for further insight.

-- Approach:
-- Add primary_delay_reason to the update-history query to inspect
-- reported delay reasons, especially as the progress gap widened in June.
-- These explanations require verification before treating them as causes.
SELECT
    project_id,
    report_date_clean,
    planned_pct_complete_clean,
    actual_pct_complete_clean,
    planned_pct_complete_clean - actual_pct_complete_clean
      AS progress_gap_pp,
    forecast_completion_date_clean,
    primary_delay_reason
FROM construction.cleaned_project_updates
WHERE project_id = 'P093'
    AND report_date_clean <= DATE '2026-06-30'
ORDER BY report_date_clean;

-- Findings:
-- Forecast completion moved later at every update, from September 3
-- to September 23: a cumulative shift of 20 days.
-- At June 30, forecast completion was 32 days later than baseline.
-- All seven updates report Labor availability as the primary delay reason.
-- The progress gap widened from 4.5 percentage points in May to 13.3
-- on June 30.
-- Labor availability is a reported schedule-risk driver; verify it
-- with the project manager and staffing records before attributing
-- the schedule deterioration or forecast cost overrun to it.


-- P093 conclusion:
-- At June 30, P093 forecasts a budget overrun of 183,801.99 because
-- ETC exceeds its remaining budget. No category is currently over budget;
-- category-level ETC and progress are needed to investigate cost drivers.
--
-- The progress gap widened from 4.5 percentage points in May to 13.3
-- at cutoff. Forecast completion shifted 20 days later across updates
-- and is now 32 days later than baseline.
--
-- All seven updates cite Labor availability as the primary delay reason.
-- Follow up with the project manager for category-level ETC and progress,
-- and staffing evidence to verify the reported schedule driver.
-- Its contribution to the forecast cost overrun remains unconfirmed.



-- Inspect P089, the next project in the selected review order.

-- Approach:
-- Inspect incurred cost, revised budget, reported completion, and ETC.
-- Calculate remaining budget and compare it with ETC to assess
-- the forecast budget overrun.


-- Inspect the project cost picture.
SELECT
    project_id,
    total_incurred_cost,
    revised_budget_total,
    actual_pct_complete_clean,
    estimated_cost_to_complete_clean
FROM construction.project_summary
WHERE project_id = 'P089';

-- Findings:
-- P089 has incurred costs of 127,226.01 against a revised budget
-- of 978,700.00, with reported completion of 12.7%.
-- Remaining budget is 851,473.99, while ETC is 910,995.14,
-- indicating a forecast budget overrun of 59,521.15.
--
-- Next: Compare category spending with revised budgets to identify
-- spending concentrations and categories already over budget.


-- Compare category spending with revised budgets.
SELECT
    cost_category,
    revised_budget,
    incurred_cost,
    budget_remaining,
    ROUND(incurred_cost / NULLIF(revised_budget, 0)* 100, 2
      )AS budget_spent_pct
FROM construction.budget_vs_actual_report
WHERE project_id = 'P089'
ORDER BY budget_spent_pct DESC;


-- Findings:
-- No cost category has exceeded its revised budget so far.
-- Labor has the highest budget usage at 14.42%, followed by
-- General Conditions at 14.04% and Other at 13.28%.
-- Category-level progress and ETC are unavailable, so these results
-- cannot establish the causes of the forecast overrun or allocate
-- it by category.


-- Next: Schedule investigation into P089.

-- Approach:
-- Use progress_gap_pp to check whether reported actual progress
-- is ahead of or behind planned progress as of June 30, 2026.
-- Use forecast_delay_days to check whether forecast completion
-- is earlier or later than baseline completion.
SELECT
    project_id,
    progress_gap_pp,
    forecast_delay_days
FROM construction.project_summary
WHERE project_id = 'P089';

-- Findings:
-- As of June 30, P089's reported actual progress is 14.8 percentage
-- points behind plan. Forecast completion is 36 days later than baseline.
-- These results identify schedule concerns but do not establish their causes.


-- Next: Inspect P089's update history through June 30.

-- Approach:
-- Inspect P089's cleaned updates through June 30, ordered by report date.
-- Calculate progress gap as planned_pct_complete_clean minus
-- actual_pct_complete_clean, measured in percentage points.
-- Include forecast_completion_date_clean to see whether the
-- expected finish moved earlier or later across updates.


-- Inspect P089's cleaned updates through June 30th.
SELECT
    project_id,
    report_date_clean,
    planned_pct_complete_clean,
    actual_pct_complete_clean,
    planned_pct_complete_clean - actual_pct_complete_clean
      AS progress_gap_pp,
    forecast_completion_date_clean
FROM construction.cleaned_project_updates
WHERE project_id = 'P089'
    AND report_date_clean <= DATE '2026-06-30'
ORDER BY report_date_clean;

-- Findings:
-- P089's reported progress gap widened from 4.0 percentage points
-- on May 24 to 5.1 on June 21 and 14.8 on June 30.
-- Actual completion decreased from 18.6% to 12.7% in the last update.
-- Verify whether this reflects a reporting correction or revised scope
-- before interpreting the wider gap entirely as slower work.
--
-- Forecast completion moved later at each update, from January 8
-- to January 23, 2027: a cumulative shift of 15 days.
-- At June 30, forecast completion was 36 days later than baseline.
--
-- Next: Inspect primary_delay_reason and progress_decrease_flag,
-- then request clarification of the reported progress decrease.


-- Approach:
-- Add primary_delay_reason and progress_decrease_flag to P089's
-- history query using construction.cleaned_project_updates.
-- Inspect reported delay reasons and confirm whether the June 30
-- decrease in actual completion is flagged for review.
SELECT
    project_id,
    report_date_clean,
    planned_pct_complete_clean,
    actual_pct_complete_clean,
    planned_pct_complete_clean - actual_pct_complete_clean
      AS progress_gap_pp,
    forecast_completion_date_clean,
    primary_delay_reason,
    progress_decrease_flag
FROM construction.cleaned_project_updates
WHERE project_id = 'P089'
    AND report_date_clean <= DATE '2026-06-30'
ORDER BY report_date_clean;


-- Findings:
-- All three updates report Labor availability.
-- The June 30, progress decrease is correctly flagged and
-- the reason for the decrease needs clasification; Labor
-- availability alone doesn't explain it.


-- P089 conclusion:
-- At June 30, P089 forecasts a budget overrun of 59,521.15 because
-- ETC exceeds its remaining budget. No category is currently over budget;
-- category-level ETC and progress are needed to investigate cost drivers.
--
-- The reported progress gap widened from 5.1 percentage points
-- on June 21 to 14.8 on June 30. Actual completion decreased from
-- 18.6% to 12.7%, triggering the progress-decrease flag.
-- Clarify this decrease before interpreting the gap as slower work alone.
-- Forecast completion shifted 15 days later across updates
-- and is 36 days later than baseline.
--
-- All three updates cite Labor availability as the primary delay reason.
-- Request category-level ETC and progress, clarification of the progress
-- decrease, and staffing evidence to verify the reported schedule driver.
-- Its contribution to the forecast cost overrun remains unconfirmed.


-- Next: Project P078. same process so, less commenting.

-- Project-level query for P078
SELECT
    project_id,
    total_incurred_cost,
    revised_budget_total,
    actual_pct_complete_clean,
    estimated_cost_to_complete_clean
FROM construction.project_summary
WHERE project_id = 'P078';

-- Findings for P078:
-- incurred $1,046,268.43
-- revised_budget_total $1,244,999.45
-- pct_complete 78.6%
-- estimate to complete $254,175.26
-- estimated overrun $55,444.24

-- P078: ETC exceeds remaining budget by 55,444.24.
-- Next: Inspect category spending for current budget pressure.
SELECT
    cost_category,
    revised_budget,
    incurred_cost,
    budget_remaining,
    ROUND(incurred_cost / NULLIF(revised_budget, 0) * 100, 2
      )AS budget_spent_pct
FROM construction.budget_vs_actual_report
WHERE project_id = 'P078'
ORDER BY budget_spent_pct DESC;

-- Findings:
-- No cost category has exceeded its revised budget so far.
-- Labor has the highest budget usage at 89.00%, followed by
-- Subcontractors at 88.84% and Materials at 80.56%.
-- Category-level progress and ETC remain unavailable.


-- Next: Schedule investigation into P078.

-- Inspect P078's cleaned updates through June 30th.
SELECT
    project_id,
    report_date_clean,
    planned_pct_complete_clean,
    actual_pct_complete_clean,
    planned_pct_complete_clean - actual_pct_complete_clean
      AS progress_gap_pp,
    forecast_completion_date_clean,
    primary_delay_reason,
    progress_decrease_flag
FROM construction.cleaned_project_updates
WHERE project_id = 'P078'
    AND report_date_clean <= DATE '2026-06-30'
ORDER BY report_date_clean;

-- Findings:
-- P078's progress gap generally widened, then jumped from 7.1 to
-- 16.4 percentage points in the final update.
-- Actual completion fell from 80.4% to 78.6%, triggering the decrease flag.
-- Forecast completion moved from July 27 to August 19, 2026:
-- a cumulative shift of 23 days.
-- The final update reports Owner decision / change order.
-- Verify whether a scope change explains the reported progress decrease.

-- P078 follow-up:
-- Verify whether an owner scope change explains the June 30 progress
-- decrease. Category-level ETC and progress are needed to investigate
-- the forecast budget overrun of 55,444.24.


-- Next: Project P083. same process so, less commenting.

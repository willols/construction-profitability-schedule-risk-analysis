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
# Project status

Updated October 15, 2026

## Current position

Cleaning, analytical-layer work, Q1–Q7, on-hold reviews, Excel reporting, the Tableau dashboard, final report, and README are complete locally.

Reporting cutoff: June 30, 2026.
Main scope: 18 active projects; three on-hold projects reviewed separately.
The final report and dashboard focus on active projects.

The published Tableau dashboard includes budget variance, progress gap,
forecast delay, four portfolio KPI cards, and project financial tooltips.

The README includes the overview, tools, key findings, dashboard preview,
Tableau Public link, final report link, and tested SQL execution order.

## Validation completed

- Reviewed final-report claims against the analysis SQL’s documented findings.
- Confirmed P089’s forecast profit margin of 18.31% by querying the database.
- Previously matched P093 and P077 financial tooltips to the dashboard CSV.
- Confirmed NULL delays display as Unknown and hover leaves portfolio KPIs unchanged.
- Completed a fresh-database rebuild in a separate project copy.
- Fixed missing view creation before Step 13’s validation queries in script 15.
- Applied the same fix to the original project.
- All scripts executed successfully in the tested order.
- Rebuilt forecast profit and portfolio margin matched the report.
- Regenerated the budget-versus-actual CSV and confirmed its expected
  10-column structure without spreadsheet-added validation columns.

Tested execution order:

`01–06 → 07, 08, 09, 11, 12, 13 → 14 → 15 → 10 → 16 → 17`

## Portfolio results

- Revised contract revenue: $25,229,253.42.
- Forecast profit: $4,687,563.85.
- Forecast profit margin: 18.58%.
- Projects forecast over budget: 9 of 18.
- Unknown finish delays: 9 of 18, comprising eight outdated forecasts
  and one missing forecast.

Active-project review priorities: P093, P089, P078, P083, and P080.
Additional schedule reviews: P079, P090, and P081.

P094 remains the separate on-hold priority, with a $185,660.56
forecast overrun, 7.82% forecast margin, and declining reported
completion alongside declining ETC.

## Key limitations

- Unknown finish delays do not mean projects are on schedule.
- Usable forecasts are not guaranteed accurate.
- Completion decreases and reported delay reasons require clarification.
- Category-level progress and estimates to complete (ETC) are unavailable.
- Missing ETC remains NULL; ETC is assumed to include all remaining
  costs, including labor, and exclude incurred costs.
- On-hold forecasts require confirmation of hold and restart assumptions.
- Budget effective dates and project status history are unavailable.
- Completed projects have no June 30 updates.
- P001’s undated approved change is excluded from cutoff revenue.

## Exact next task

Review and stage the intended changes in the original repository,
then commit and push.

## Remaining work

- Complete Git closeout for October 14–15 changes.
- Check the README dashboard image and report link on GitHub after pushing.
- Check that the Tableau Public link opens the intended dashboard.

## Git closeout

Last confirmed pushed commit:
`45a77c5 — Add profitability cards and refine Tableau risk dashboard`.

October 14–15 changes remain uncommitted and unpushed.
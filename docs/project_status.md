# Project status

Updated October 4, 2026

## Current position

Cleaning and analytical-layer work are complete.
construction.project_summary contains 96 projects as of June 30, 2026.

Analysis has started in sql/16_project_analysis.sql.
The main focus is the 18 active projects. On-hold projects are reviewed separately.
Completed projects retain NULL forecasts where inputs are unavailable.

## Completed today

- Added and validated forecast profit margin.
- Confirmed June 30 updates for all 18 active and 3 on-hold projects.
- Confirmed all 3 on-hold projects have ETC values.
- Agreed on seven business questions based on the client handoff.
- Answered Question 1: active projects have $4,687,563.85 in forecast
  profit and an 18.58% combined forecast margin.

## Next task

Question 2: Identify active projects forecast to lose money or have
the lowest margins.

Write the approach first, attempt the SQL, then explain the results.

## Key limitations

- Only 9 active projects have usable forecast delays.
- Completed projects have no June 30 updates.
- Missing ETC stays NULL; it does not mean zero remaining costs.
- ETC is assumed to include all remaining costs, including labor.
- Budget effective dates and project status history are unavailable.
- P001's $23,877.11 change order is excluded from cutoff revenue
  because its approval date is missing.

## Remaining work

- Answer Questions 2–7.
- Correct the earlier budget-versus-actual SQL, CSV, and Excel report
  to include employee labor before using it to investigate cost drivers.
- Build the dashboard and recommendations.
- Document limitations and additional data needed.

## Git closeout

Last confirmed pushed commit: b970c4a.
October 4 changes still need review, commit, and push.
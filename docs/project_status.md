# Project status

Updated October 12, 2026

## Current position

Cleaning, analytical-layer work, Q1–Q7, on-hold reviews, and the Excel refresh are complete.

Reporting cutoff: June 30, 2026.
Main scope: 18 active projects; three on-hold projects reviewed separately.

Built the first Tableau dashboard for Rachel Kim, Director of Operations:
- Budget variance chart above the progress gap chart and forecast delay table.
- Dashboard CSV exported and checked: 18 active projects.
- Hover highlighting works across all three views.
- Custom hover formatting started but unfinished.
- Workbook saved locally in `outputs/visualizations`.

P094 remains the on-hold priority, with a forecast overrun of $185,660.56, a 7.82% margin, and declining completion alongside declining ETC.

## Next task

Finish the custom hover effect. The `Hovered Project` set, set action, and `Hover Status` calculation are created and working. Next, create `Budget Hover Color`, combining budget status with hover status.

Then fix schedule-row alignment, finish labels and legends, and test before publishing the updated dashboard.

## Key limitations

- Only nine active projects have usable forecast delays; NULL means unknown.
- Completion decreases and reported delay reasons require clarification.
- On-hold forecasts need confirmation of hold and restart assumptions.
- Category-level progress and ETC are unavailable.
- Missing ETC remains NULL; ETC is assumed to include remaining labor.
- Budget effective dates and project status history are unavailable.
- Completed projects have no June 30 updates.
- P001’s undated approved change is excluded from cutoff revenue.
- Tableau Public publishing makes the dashboard and its data public.
- Microsoft support follow-up remains pending for the disabled Business Basic trial and billing status.

## Remaining work

- Finish and validate the dashboard.
- Complete the final report and recommendations.
- Update documentation and confirm Git closeout.

## Git closeout

Last confirmed pushed commit: `986e0a5`.
Today’s changes still need review, commit, and push.
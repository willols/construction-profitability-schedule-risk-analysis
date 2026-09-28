# Project status

Updated September 28, 2026

## Current position

Profiling and cleaning are complete. The analytical layer is saved as
construction.project_summary in sql/15_project_analytical_layer.sql.

The view contains costs, budgets, schedule metrics, revised contract revenue,
and forecast profit as of June 30, 2026. It retains 96 rows and 96 unique projects.
The current analysis focuses on the 18 active projects.

## Completed

- Finished schedule validation against cleaned sources.
- Added qualifying approved revenue changes and revised contract revenue.
- Added forecast profit and a missing-approval-date review flag.
- Confirmed revenue totals match the source and new calculations have no differences.

## Key findings and limitations

- All 18 active projects have usable progress gaps; nine have usable forecast delays.
- Eight other projects have forecasts before the report date; P088 has no forecast date.
- P001's approved change order CO0001 has no approval date. Its $23,877.11 revenue
  adjustment is excluded from cutoff revenue, and P001 is flagged for review.
- NULL means unavailable, not zero or on time.
- Budget effective dates are unavailable.
- ETC is assumed to include all remaining costs, including labor.
- Project status is treated as cutoff status because no status history is available.

## Next task

Decide whether to add forecast profit margin, then settle forecast treatment
for completed and on-hold projects without June 30 updates.

Continue with reasoning and comments first, followed by my SQL attempt.

## Remaining work

- Finish the two analytical-layer decisions above.
- Analyze project risks and profitability.
- Build the dashboard and recommendations.
- Correct the earlier budget-versus-actual SQL, CSV, and Excel report,
  which excludes employee labor.

## Git closeout

The last confirmed pushed commit is d74bfc5 from September 25.
September 27–28 changes still need Git review, commit, and push confirmation.

Detailed decisions and validation results are in docs/project_notes.md
and sql/15_project_analytical_layer.sql.
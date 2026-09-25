# Project status

Updated September 25, 2026

## Where I'm at

I'm building the analytical layer for the Construction Project Profitability and Schedule-Risk Analysis. Profiling and cleaning are complete, and the six cleaned views are saved in `construction.duckdb`.

The current file is `sql/15_project_analytical_layer.sql`. It brings costs, budgets, and remaining-cost estimates together at one row per project, using June 30, 2026 as the reporting cutoff. The analytical layer is still a query; I have not saved it as a view yet.

## What I've built

- Separate project totals for non-payroll incurred costs and employee labor.
- Total incurred cost, revised budget, project status, and June 30 ETC.
- Forecast final cost and budget variance in dollars and percentages.
- An initial query for active projects forecast to finish over budget.
- Checks for row counts, missing cutoff data, monetary totals, and unmatched project IDs.

The output has 96 unique projects. All 18 active projects have June 30 ETC, and nine are forecast over budget. That is an initial finding, not a conclusion about profitability.

Non-payroll costs reconcile at $80,468,439.22 and labor at $30,917,634.47. Neither has unmatched eligible project IDs. I also ran the added budget and combined-cost checks and reported that everything looked good; I did not paste those final outputs into the session. The expected combined cost was $111,386,073.69.

## What I'm doing next

Before writing schedule SQL, I want to plan it myself with guidance:

1. Explain the schedule question I want to answer.
2. Identify the fields, tables, and calculations needed.
3. Decide how to handle missing or questionable dates and progress values.
4. Write the comments, then make the first SQL attempt.

I can follow the cost query now, but planning the whole thing independently is still hard. I want to practice that rather than just keep adding code.

## What still needs work

- Add schedule measures and the relevant exception flags.
- Decide forecast treatment for non-active projects without June 30 updates. Keep missing ETC as NULL for now.
- Add eligible contract-revenue adjustments and profitability calculations.
- Save and validate the finished analytical view.
- Investigate project priorities and contributing factors, then build Power BI visuals and a short summary with recommendations.
- Correct the earlier budget-versus-actual SQL, CSV, and Excel report at closeout. It includes non-payroll transactions but leaves out employee labor.

## Rules and limitations to keep in mind

This is a fictional case study. I will document assumptions and unresolved issues rather than invent missing source information.

- Aggregate each detailed source before joining. Keep one row per authoritative project and account for unmatched source amounts separately.
- Include paid, approved, and applied transactions through June 30 as incurred costs. Keep pending exposure separate. Labor uses work dates through the same cutoff.
- Use the supplied revised budgets without adding approved change-order estimated costs again. Their effective dates are unavailable, so June 30 budget validity is not confirmed.
- Assume ETC includes all remaining costs, including labor, and excludes costs already incurred at its update date. Do not automatically combine older ETC with June 30 costs.
- Treat supplied project status as cutoff status because there is no status history; review apparent conflicts.
- Preserve missing and questionable data with flags. This includes P013's baseline date, P052's project type, the missing original budget, labor exceptions, and progress or forecast issues. Unmatched budgets, updates, and change orders remain separate from recognized projects.
- Keep CO0001's undated approved revenue separate from confirmed cutoff-approved changes. Exclude CO0119's July billing from June 30 billed totals.
- Pending transactions are not a complete commitments or accruals record. Budget remaining is not ETC, and budget performance alone does not establish profitability.

Details and the reasoning behind these decisions are in `docs/project_notes.md`, `docs/analysis_plan.md`, and the relevant SQL files. The original longer status file is preserved in `project_status_archive_2026-09-24.md`.

## Git closeout

The September 24 handoff confirmed commit `6b287ca` was pushed to `origin/main` and the working tree was clean then:

`Reconcile change-order budgets and begin project analytical layer`

Today's changes still need Git review and closeout. Check the actual diff, then stage the intended SQL and documentation changes, commit, and push. Do not record today's closeout as complete until that is confirmed.

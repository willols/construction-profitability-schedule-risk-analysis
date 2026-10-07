# Project status

Updated October 6, 2026

## Current position

Cleaning and analytical-layer work are complete.
`construction.project_summary` contains 96 projects with a reporting
cutoff of June 30, 2026.

Analysis is in `sql/16_project_analysis.sql`.
Questions 1–4 are complete. Question 5 identifies P093, P089, P078,
P083, and P080 for initial review, not a definitive risk ranking.
Question 6 has begun with P093; category and schedule investigations
are not yet complete.

The main analysis focuses on 18 active projects. On-hold projects
will be reviewed separately.

## Completed today

- Planned P093's project-level and cost-category investigation.
- Corrected `construction.budget_vs_actual_report` to include
  employee labor through June 30, mapped to the Labor category.
- Confirmed incurred costs of $111,386,073.69 against both sources.
  Revised budget and pending exposure totals remained unchanged.
- Found zero duplicate project/category groups and zero incurred-cost
  mismatches for projects in `project_summary`.
- Confirmed P997's Labor budget is the only row without matching
  cost records.
- Prepared a revised SQL file with updated definitions and validations.

## Next task

Save the revised `sql/10_budget_vs_actual_report.sql` locally.
Run its updated coverage check and labor cutoff inspection.
Re-export the CSV and validate the exported totals.

Then resume Q6 with P093: investigate corrected category costs and
remaining budgets, followed by schedule concerns. Write the approach
before SQL and distinguish evidence from possible explanations.

## Key limitations

- Only 9 of 18 active projects have usable forecast delays.
  NULL means unknown, not on time.
- The priority shortlist requires both financial and schedule concerns
  and may omit severe issues affecting only one side.
- Spending versus physical progress is an investigation signal,
  not proof of a cause.
- Category-level progress and ETC are unavailable, limiting allocation
  of forecast overruns to categories.
- Completed projects have no June 30 updates.
- Missing ETC stays NULL; ETC is assumed to include remaining labor.
- Budget effective dates and project status history are unavailable.
- P001's $23,877.11 change order remains excluded from cutoff revenue
  because its approval date is missing.

## Remaining work

- Finish pending report checks and refresh the CSV and Excel report.
- Complete priority-project risk investigations for Q6.
- Identify recurring patterns for Q7.
- Check excluded projects for severe individual risk concerns.
- Review on-hold projects.
- Build the dashboard and final recommendations.
- Document evidence, limitations, and additional data needed.

## Git closeout

Last confirmed pushed commit: `f1eee99` (October 4).
October 5–6 changes still need review, commit, and push.
# Project status

Updated October 7, 2026

## Current position

Cleaning and analytical-layer work are complete.
`construction.project_summary` contains 96 projects at the
June 30, 2026 reporting cutoff.

Analysis is in `sql/16_project_analysis.sql`.
Questions 1–4 are complete. Question 5 identifies P093, P089, P078,
P083, and P080 for initial review, not a definitive risk ranking.

Q6 initial reviews are complete for P093, P089, and P078.
P083 and P080 remain. The main analysis covers 18 active projects;
on-hold projects will be reviewed separately.

## Completed this session

- Completed report coverage and labor cutoff checks.
- Re-exported the corrected budget-versus-actual CSV and confirmed
  all three totals match SQL to the cent.
- Reviewed category spending and schedule history for three projects.
- P093: all seven updates report Labor availability; schedule
  deterioration is documented.
- P089: all three updates report Labor availability; the June 30
  progress decrease is flagged and requires clarification.
- P078: the final update reports Owner decision / change order;
  a scope revision may explain its flagged progress decrease.
- Documented findings, limitations, and follow-up recommendations.
- Shortened repetitive comments to emphasize new evidence and exceptions.

## Next task

Start P083's category-spending review, then inspect its update history
through June 30, including reported delay reasons and progress flags.
Interpret the results and document only useful findings and exceptions.

Repeat for P080, then move to Q7's recurring patterns.

## Key limitations

- Only 9 of 18 active projects have usable forecast delays.
  NULL means unknown, not on time.
- The priority shortlist may omit severe issues affecting only
  financial performance or schedule.
- Category-level progress and ETC are unavailable; category spending
  cannot establish causes or allocate forecast overruns.
- Reported delay reasons require verification.
- Progress decreases may reflect corrections or scope changes;
  their causes remain unconfirmed.
- Completed projects have no June 30 updates.
- Missing ETC stays NULL; ETC is assumed to include remaining labor.
- Budget effective dates and project status history are unavailable.
- P001's $23,877.11 change order remains excluded from cutoff revenue
  because its approval date is missing.

## Remaining work

- Refresh the Excel report from the corrected CSV.
- Finish Q6 reviews for P083 and P080.
- Identify recurring patterns for Q7.
- Check excluded projects for severe individual risk concerns.
- Review on-hold projects.
- Build the dashboard and final recommendations.
- Preserve evidence, limitations, and additional data needs.

## Git closeout

Last confirmed pushed commit: `f1eee99` (October 4).
October 5–7 changes still need confirmed commit/push.
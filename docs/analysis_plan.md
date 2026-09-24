# Analysis Plan

Construction Project Profitability and Schedule-Risk Analysis
Reporting cutoff: June 30, 2026
Prepared: September 23, 2026

## Objective

Help Summit Ridge Contractors identify active projects needing attention, explain the evidence behind their profitability and schedule concerns, and identify recurring problems that could inform future estimating and planning.

This is a fictional portfolio case study. Findings must come from the supplied data. Modeling assumptions must be labeled and must not be presented as confirmed source facts.

## Business Questions

| Question | Measures and comparisons | Intended decision |
| --- | --- | --- |
| Which active projects need management attention? | Recorded costs versus revised budget; forecast final cost and margin where supportable; actual versus planned progress; forecast versus baseline completion date. | Prioritize projects for review using visible cost and schedule indicators. |
| What appears to contribute to those concerns? | Cost-category overruns; labor costs and overtime patterns; progress history; reported delay reasons; change-order activity. | Identify specific issues to investigate and recommend follow-up actions. |
| Which problems recur across projects? | Frequency and size of category overruns; delay reasons across distinct projects; outcomes by project type where sample sizes permit. | Suggest improvements to estimating and planning, with evidence and limitations. |

Use transparent indicators rather than an arbitrary combined risk score. Distinguish observed patterns and reported explanations from proven causes. Do not describe overtime as low productivity without output or production measures.

## Analytical Structure

- Primary output: one row per authoritative project as of the reporting cutoff. Retain all 96 projects, with active projects as the primary management-review population.
- Supporting detail: one row per project and cost category for spending analysis, plus eligible labor entries, update history, and change-order detail for investigation.
- Aggregate each source to the required grain before joining. Select one latest eligible project update before joining it to the project summary; investigate any project/date ties rather than choosing arbitrarily.
- Keep orphan records separately visible and reconcile their amounts to source totals. Do not silently drop them or invent replacement project IDs.

## Initial Metric Definitions

| Metric | Definition |
| --- | --- |
| Recorded incurred cost | Non-payroll transactions with paid, approved, or applied status through the cutoff, plus recorded employee labor costs for work through the cutoff. Preserve credits and other signed amounts. |
| Pending exposure | Pending non-payroll transactions through the cutoff, shown separately from incurred cost. |
| Revised budget | Sum of supplied revised budget amounts. Do not add approved change-order estimated costs again. |
| Budget remaining | Revised budget minus recorded incurred cost. This is not estimated cost to complete. |
| Progress gap | Latest eligible actual completion percentage minus planned completion percentage from the same update, in percentage points. Negative values indicate progress behind plan. |
| Forecast delay | Forecast completion date minus confirmed baseline completion date, in days. Positive values indicate forecast lateness. |
| Adjusted contract value | Original contract value plus approved revenue changes confirmed approved by the cutoff. Show undated approved changes separately. This is contract value, not recognized revenue or cash collected. |
| Forecast final cost | Recorded incurred cost plus latest eligible estimated cost to complete, under the ETC assumption below. |
| Forecast project margin | Adjusted contract value minus forecast final cost. Margin percentage divides this amount by adjusted contract value when positive. This is a forecast based on supplied project costs, not company net profit. |

Cost pressure and forecast margin should be assessed together with progress and data quality. Do not infer an overrun simply because the percentage of budget spent exceeds the percentage complete; progress measurement and spending need not be linear.

## Evidence, Assumptions, and Limitations

### Supported by supplied information

- The client handoff defines cost transactions as non-payroll job costs and labor entries as payroll-cost detail. Include both cost sources once.
- The completed reconciliation found no differences between comparable project-level budget adjustments and approved change-order estimated costs. All 38 unmatched projects had zero budget adjustments and no approved-change-order match. Use supplied revised budgets without adding those estimated costs again.
- That reconciliation used all supplied approved change orders. It does not establish individual change-order allocation or budget validity at the cutoff.

### Explicit case-study assumptions

- Treat project-master status as the supplied cutoff status because status history is unavailable. Check apparent date/status conflicts and disclose exceptions.
- For forecast metrics, assume ETC represents all remaining project costs at the update date, including remaining employee labor, and excludes costs already incurred at that date. This is a modeling assumption, not a verified field definition.
- Combine cutoff incurred costs with ETC only when the update represents the cutoff date. For older updates, retain the update date and progress information, flag staleness, and leave the headline cutoff forecast-cost and margin metrics unavailable until a defensible alignment method is established.

### Exception treatment

- Use actual activity and approval dates on or before June 30. Future forecast and baseline dates remain valid analytical inputs.
- Do not infer the approval date for CO0001. Exclude its approved revenue change from confirmed cutoff adjustments and disclose the amount separately as timing-uncertain.
- Preserve invalid progress, missing forecasts, ambiguous baseline dates, and other recorded exceptions. Exclude affected values from metrics that require valid inputs, while retaining the project and explaining why a metric is unavailable.
- Budget effective dates are unavailable. Comparisons use supplied budgets and must carry that limitation.
- Pending transactions are not a complete commitment or accrual register. The exports do not establish full accounting completeness.
- Completed-project results may inform recurring-pattern analysis, but supplied costs and revenue should not be labeled final accounting profit without closeout confirmation.

If this were a real engagement, request an ETC definition, dated budget versions, status history, the missing approval date, and confirmation of cost completeness. The fictional case can proceed using the disclosed assumptions above.

## Build and Validation Sequence

1. Define the project summary fields and build project-level budget and cost aggregates, including employee labor.
2. Reconcile eligible source amounts to aggregates and joined outputs, with orphan amounts accounted for separately.
3. Add the latest eligible update and cutoff-approved revenue changes. Verify row uniqueness, date selection, and exception handling.
4. Calculate metrics, inspect a small set of projects manually, and investigate the three business questions.
5. Build a focused Power BI report and write an executive summary with findings, supporting evidence, recommended actions, and limitations.
6. At final closeout, correct the existing SQL budget-versus-actual report to include employee labor, refresh CSV and Excel outputs, and update documentation. Until then, label that existing report preliminary and incomplete for total project costs.

## Portfolio Deliverables

- Reproducible DuckDB SQL for cleaning, reconciliation, and analytical outputs.
- Power BI report showing portfolio priorities, project detail, and recurring patterns.
- Short executive summary explaining the findings and recommended actions.
- README explaining the fictional business context, source relationships, key assumptions, results, and reproduction steps.
- Corrected Excel budget-versus-actual report at closeout; no additional Excel expansion is required.

## Immediate Next Task

Design the first project-summary table before writing its SQL: list the required fields, identify each source, and explain how each contributes to the first business question. Continue in coaching mode: reasoning and comments first, then the user's SQL attempt.

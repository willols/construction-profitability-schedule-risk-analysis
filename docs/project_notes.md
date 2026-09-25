# Project notes

I'm using this fictional construction project to practice taking raw data, making it trustworthy, and turning it into insight someone can use. These notes cover what I worked on, the decisions I made, and what I still need to understand.

The reporting cutoff is June 30, 2026. Detailed queries and checks are in `sql/`. The business questions are in `docs/analysis_plan.md`, and the current task belongs in `docs/project_status.md`.

I shortened these notes on September 25 and grouped some older sessions by topic. The original notes through September 24 are preserved in `project_notes_archive_2026-09-24.md`. Older findings below describe the data at that stage, before later cleaning and corrections.

## September 25 — Forecasting project costs

### What I worked on

I added the June 30 project updates to `sql/15_project_analytical_layer.sql`. The query still returns one row per project: 96 rows and 96 unique project IDs. All 18 active projects have a June 30 update and a remaining-cost estimate.

I added three calculations:

- Forecast final cost = incurred cost + estimated cost to complete (ETC).
- Forecast budget variance = forecast final cost − revised budget.
- Forecast budget variance percentage = variance ÷ revised budget × 100.

Positive variance means forecast over budget. Negative means forecast under budget. A zero budget returns NULL for the percentage because there is no meaningful percentage to calculate against it.

Nine of the 18 active projects are forecast over budget. P093 has the largest forecast overrun in dollars at $183,801.99, or 7.48%. P083 is forecast $84,680.99 over budget, or 7.59%, and has already incurred $6,480.89 more than its budget.

That comparison helped me understand why both dollars and percentages matter. P093 has the bigger dollar exposure, but their overruns are similar relative to their budgets. These are forecasts, and being over budget does not automatically mean a project is losing money.

### Checks and what I learned

I compared the source costs with the costs retained after the project joins:

| Cost source | Source total | Analytical total |
| --- | ---: | ---: |
| Non-payroll | $80,468,439.22 | $80,468,439.22 |
| Employee labor | $30,917,634.47 | $30,917,634.47 |

Both differences were zero. Separate checks returned no eligible transactions or labor entries with unmatched project IDs.

I asked for help adding the remaining budget and combined-cost checks. I ran them and reported that everything looked good. I did not paste those final outputs into the session. The expected combined incurred cost was $111,386,073.69; the budget check also accounts separately for unmatched budget rows.

A few things needed explaining today: table aliases only apply inside their query, a LEFT JOIN keeps projects without a matching update, and an overrun percentage compares the overrun with the whole budget—not the budget remaining. I added definitions at the top of the SQL file to make those calculations easier to follow.

I can follow what we built now, but I would not have known how to plan the whole thing alone. That is the skill I want to work on next. Before adding the schedule side, I want to talk through the question, the fields needed, and how the tables fit together, then make the first attempt myself.

### What's next

Plan the schedule side before writing SQL. Start with what we want to know about an active project's schedule, then decide which fields and calculations would answer it.

The analytical layer is still a query, not a saved view. Revenue and profitability calculations, treatment of non-active projects without cutoff updates, and remaining exception handling still need work. The earlier budget-versus-actual report also needs its labor correction at project closeout. Today's Git commit and push are not yet confirmed.

## September 24 — Bringing the cost sources together

I started the project-level analytical query. I summed non-payroll costs, employee labor, and revised budgets separately, then joined them to the project list. The output stayed at 96 projects, with no missing cost-component or budget totals.

The important part was aggregating each source before joining. Joining detailed transactions directly to detailed labor entries could multiply the rows and overstate costs.

I used paid, approved, and applied transactions through June 30 for non-payroll incurred costs. Pending transactions stay separate. Labor uses `work_date_clean`; transactions use `transaction_date`.

I also confirmed that all 18 active projects have June 30 ETC and that no project has multiple updates on that date. ETC is a changing estimate, so I should use the selected update, not add estimates from different dates together. Combining an old ETC with newer incurred costs could count some work twice.

For this fictional case, I am assuming ETC covers all remaining costs, including labor, and excludes costs already incurred at the update date. The dates line up, but that does not prove the estimates are accurate. Budget effective dates are unavailable.

The session handoff confirmed commit `6b287ca` was pushed and the working tree was clean. It also confirmed the reconciliation file was renamed to `sql/14_change_order_budget_reconciliation.sql`; the earlier closeout wording had not caught up with that.

## September 23 — Correcting the cost approach

I checked the client handoff and found an important mistake in the earlier guidance: cost transactions are non-payroll costs. They do not contain a Labor category. Employee labor comes from `labor_entries.csv`, so both sources need to be included once.

That means the existing budget-versus-actual report is incomplete for total project costs. Its transaction totals reconcile, but it leaves out employee labor and overstates budget remaining where that labor applies. I will correct the SQL, CSV, and Excel workbook at project closeout. The new analytical layer includes labor from the start.

I also compared approved change-order estimated costs with supplied budget adjustments by project. There were no nonzero differences among comparable totals. The 38 unmatched projects had zero budget adjustments and no matching approved-change-order total.

I will use the supplied revised budgets without adding those change-order costs again. This comparison supports that decision, but it was across all records, not a reconstruction of budgets as of June 30. Approved revenue changes are separate and still need their own treatment.

I put the analysis direction into `docs/analysis_plan.md`: identify active projects needing attention, investigate what may contribute to the problems, and look for patterns that could improve future estimating and planning. The aim is useful analysis and clear recommendations, with Power BI and a concise final summary.

## September 21–22 — Cleaning updates and change orders

I finished the cleaned project-update and change-order views:

- Project updates: 725 rows and 725 unique update IDs.
- Change orders: 145 rows and 145 unique change-order IDs.

For updates, I standardized dates and percentages, preserved ETC, and used `LAG()` to compare each project's progress with its previous update. I kept questionable records and flagged them instead of guessing replacements.

The update checks identified one missing forecast, one actual-completion value above 100%, one unmatched project, one unknown submitter, 14 progress decreases, and 40 forecasts before their report dates. The unmatched project and unknown submitter belong to the same record, UPD99999/P995.

For change orders, I removed the exact duplicate, standardized statuses and money fields, and preserved legitimate negative amounts. CO9999/P994 remains unmatched. CO0001 remains approved with no approval date, so its revenue cannot automatically be treated as confirmed cutoff-approved revenue. CO0119's later billing date stays in the source; cutoff rules belong in the analysis.

The cleaned totals reconciled to the deduplicated source. I also checked NULLs and recorded zeros separately, because equal totals alone would not show whether those had changed.

## September 16–18 — Finishing labor cleaning

I built `construction.cleaned_labor_entries` with 18,003 unique entries and total recorded labor cost of $30,917,634.47. The source and cleaned totals matched, and the cleaned project IDs all matched the project list.

I kept raw values next to the cleaned values and recorded four specific exceptions:

| Entry | Treatment |
| --- | --- |
| TE000408 | Corrected P996 to P003 based on the documented surrounding records; kept the raw ID and flagged the correction. |
| TE001843 | Derived a missing hourly rate of 38.96 and flagged it as derived. |
| TE001216 | Kept the trade General Labor and flagged it as unresolved. |
| TE003191 | Kept the recorded $1,530.88 labor cost and flagged the unexplained $125 difference from the formula. |

I used four decimal places for regular hours because reducing the precision would change recorded values. The other cleaned numeric fields use two decimal places.

The main lesson was that a formula mismatch or an unusual value does not give me permission to overwrite the source. Corrections need evidence, and anything derived needs to stay distinguishable from what was recorded.

## September 13–16 — First budget-versus-actual report

I built a report at one row per project and cost category, exported it to CSV, and opened it in Excel. I created a table, a project-summary PivotTable, and report notes, then checked the exported and Excel totals against SQL.

The report had 673 rows, $119,564,833.67 in revised budgets, $80,468,439.22 in transaction-based incurred costs, and $7,961,647.60 in pending exposure. It retained P997's $42,000 budget even though P997 has no matching project record.

I practiced comparing category overruns with project totals. A project can have an overrun in one category while still showing budget remaining overall. Neither result tells me whether the remaining budget will cover the work still to do.

**Later correction, September 23:** this version excludes employee labor. Its zero-cost Labor rows and remaining-budget figures must not be treated as a complete picture of project costs. The SQL, CSV, and workbook still need updating at closeout.

## September 8–12 — Building the first cleaned views

I moved from profiling into reusable cleaned views in `construction.duckdb`.

| View | Rows | Main decisions |
| --- | ---: | --- |
| `cleaned_projects` | 96 | Standardize statuses and contract values; keep missing project type and unresolved baseline date flagged. |
| `cleaned_project_budgets` | 673 | Remove the exact duplicate, standardize categories, and keep the missing original budget and unmatched project visible. |
| `cleaned_cost_transactions` | 11,203 | Remove the exact duplicate, apply documented project corrections, standardize categories and statuses, and preserve credits. |

The project contract total reconciled to $141,761,000.00. P052's project type remains unknown. P013's ambiguous baseline completion date remains unresolved.

The cleaned revised-budget total was $119,564,833.67: $119,522,833.67 linked to recognized projects and $42,000 linked to P997. BUD-P057-04 still has a missing original budget; I did not turn that into zero.

For transactions, TX000316 was assigned to P003 and TX000729 was corrected from P998 to P007, with the original values and correction flags retained. The three applied material credits remained negative at $1,800 each. Paid, approved, and applied transactions make up incurred cost; pending costs stay separate.

## August 26–September 7 — Profiling change orders

I checked identifiers, project relationships, dates, statuses, and monetary fields before cleaning. CO0013 was an exact duplicate, leaving 145 unique change orders. P994 had no matching record in the other supplied datasets, so there was no supported replacement project ID.

Negative revenue and cost changes were consistent with deductive change orders. They were not errors just because they were negative. Currency formatting needed removal, and two decimal places preserved the monetary values.

CO0001 was approved and billed but missing its approval date. I kept that gap rather than inventing a date. I also separated zero billed amounts from missing amounts: an approved change that has not been billed is different from an unknown billed amount.

During the final cross-table checks, I confirmed that P997 was an unmatched budget project. All authoritative projects had budget coverage. This reinforced why checking that every project has data is different from checking that every source row belongs to a known project.

## August 17–25 — Profiling project updates

I found one exact duplicate, leaving 725 unique updates. After standardizing report dates, the project/date check found no combinations with multiple distinct updates.

The records needed interpretation as well as cleaning:

- P088's June 30 update has no forecast completion date. Earlier forecasts do not establish what the missing value should be.
- P040 has an actual-completion value of 105%. I preserved and flagged it.
- Actual progress decreased 14 times across the histories. Thirteen decreases occurred on June 30; the other followed P040's 105% record.
- Forty forecasts precede their report dates. That raises questions about reporting and stale forecasts, but does not identify a correction by itself.
- P995's only update has no matching project and an Unknown submitter. I kept both exceptions visible.

The delay label None did not consistently mean the project was on schedule: 34 of those updates were behind plan. I should measure progress against plan rather than use the label as a shortcut.

All 75 zero-ETC records reported 100% actual completion, supporting preservation of those zeros. Actual minus planned completion is a difference in percentage points; it is not the same calculation as a budget-overrun percentage.

## August 10–14 — Profiling labor

I checked duplicate IDs, missing values, dates, hours, rates, project IDs, and the relationship between recorded labor cost and calculated pay. One exact duplicate left 18,003 unique entries.

I tested different rounding approaches instead of assuming every small difference was an error. Most differences were small, but TE003191 had an unexplained $125 difference. The recorded amount stayed unchanged. The missing rate on TE001843 could be derived from its recorded cost and hours, but that is still a derived value.

I also found that the entries cannot safely be treated as individual daily timesheets. One employee/date group contained 298.68 regular hours across several projects. I should not use those records to make daily workload or overtime-compliance claims without a clearer definition of what the hours represent.

I split the growing profiling script into separate SQL files by dataset. That made it easier to find the relevant investigation and continue working.

## August 4–7 — Profiling cost transactions

I found the exact TX000138 duplicate, a missing project ID, an unmatched project ID, inconsistent categories and statuses, and one currency-formatted amount.

I investigated the surrounding records before choosing project-ID corrections. TX000316 fell within a P003 block; TX000729 interrupted a P007 block. The corrections were later applied only in cleaned columns and flagged.

The three negative transactions were returned-material credits. They needed to reduce incurred costs, not be removed. After the documented project and category corrections, the transaction-to-budget category mismatches were resolved.

This was where I started distinguishing costs already incurred from pending exposure. Those should not be added together and presented as if they mean the same thing.

## July 24–August 3 — Profiling budgets

I checked the budget-line grain, duplicate IDs, categories, money fields, and the relationship between original budgets, approved changes, and revised budgets.

BUD-P031-01 was an exact duplicate. BUD-P057-04 had a missing original budget but a revised budget of $31,672 and zero approved change. The arithmetic suggests a possible original value, but I kept the recorded original budget NULL.

All testable source rows satisfied original budget plus approved change equals revised budget. I chose decimal types for money after checking the observed range and precision, and kept the raw CSV unchanged.

## July 22–23 — Profiling projects

I investigated missing project type, status variations, date order, and contract and budget ranges. P052's project type could not be inferred safely. P013's baseline completion date had two possible interpretations, so I left it unresolved. P066's formatted contract value could be cleaned to $672,000.

I established June 30, 2026 as the reporting cutoff. Later actual activity should be excluded from cutoff calculations, but future baseline and forecast dates are still relevant. A future date is not automatically a bad date.

The rule carried through the rest of the project: keep the raw data, explain corrections, and leave uncertainty visible when the evidence does not support a fix.

# Project notes

I'm using this fictional construction project to practice taking raw data, making it trustworthy, and turning it into insight someone can use. These notes cover what I worked on, the decisions I made, and what I still need to understand.

The reporting cutoff is June 30, 2026. Detailed queries and checks are in `sql/`. The business questions are in `docs/analysis_plan.md`, and the current task belongs in `docs/project_status.md`.

I shortened these notes on September 25 and grouped some older sessions by topic. The original notes through September 24 are preserved in `project_notes_archive_2026-09-24.md`. Older findings below describe the data at that stage, before later cleaning and corrections.

## October 8 — Finished priority reviews and analysis checks

### Completed

- Finished P083 and P080, completing the five priority-project reviews.
- Confirmed complete financial metrics and positive forecast profit for all 18 active projects.
- Reconciled category budgets and incurred costs to project totals for all five reviewed projects; zero differences.
- Added a cleaned-view project/report-date uniqueness check; passed.
- Screened the other 13 active projects and completed targeted schedule reviews of P079, P090, and P081.

### Main findings

- P083 is already $6,480.89 over budget and forecasts an $84,680.99 overrun. Completion decreased, and its finish forecast is outdated.
- P080 forecasts a $22,126.97 overrun. Its final progress gap improved, but forecast finish moved later.
- P079 forecasts a 29-day delay despite forecast costs remaining below budget.
- P090 and P081 had cutoff completion decreases requiring clarification. P090 also needs an updated finish forecast.

### Decisions and next task

Keep the five initial priorities and document additional schedule follow-up. Reported delay reasons remain unverified.

Drafted Q7 around reporting reliability, schedule trends, and reported constraints across all 18 active projects. Investigation has not started.

Next: Begin Q7 reporting reliability using cutoff completion decreases and missing/outdated forecasts. Reuse existing checks.

## October 7 — Finished report checks and reviewed three priority projects

### What I worked on

I completed the remaining budget-versus-actual checks and CSV validation, then continued Q6 in `sql/16_project_analysis.sql`. I finished initial reviews of P093, P089, and P078 using category spending, schedule history, reported delay reasons, and progress-decrease flags.

### Checks and findings

- Report coverage: 673 project/category rows; 672 with budget amounts and matching costs, 1 budget-only row (P997 / Labor), and 0 without budget amounts.
- No labor entries were dated after June 30 or had missing work dates.
- Exported CSV totals matched SQL to the cent: revised budget $119,564,833.67, pending exposure $7,961,647.60, and incurred cost $111,386,073.69.

**P093:** Forecast overrun of $183,801.99. No category is currently over budget. The progress gap widened to 13.3 percentage points, and forecast completion moved 20 days later across updates, ending 32 days later than baseline. All seven updates report Labor availability.

**P089:** Forecast overrun of $59,521.15. No category is currently over budget. Forecast completion moved 15 days later across updates, ending 36 days later than baseline. All three updates report Labor availability. Actual completion fell from 18.6% to 12.7% in the final update and was flagged; this needs clarification before attributing the larger progress gap entirely to slower work.

**P078:** Forecast overrun of $55,444.24. No category is currently over budget; Labor and Subcontractors have used about 89% of their budgets. Forecast completion moved 23 days later across updates. The final progress gap increased from 7.1 to 16.4 percentage points while actual completion fell from 80.4% to 78.6%. The final update reports Owner decision / change order; a scope revision is a possible explanation to verify.

### What I learned and decided

Category spending does not establish category forecast overruns without category-level progress and ETC. Reported delay reasons guide follow-up but are not verified causes. A forecast-date shift across updates is different from delay against baseline.

I shortened repetitive comments and focused on new findings, exceptions, and useful follow-up. Recommendations will become actions in the fictional case-study report; no requests are being sent.

### What's next

Continue Q6 with P083's category spending and update history, then review P080. After the five priority reviews, move to Q7's recurring patterns.

Excel refresh remains pending. Save the SQL and documentation changes and confirm Git commit/push.

## October 6 — Began Q6 and corrected budget versus actual

### What I worked on

I began Question 6 with P093, separating the project-level cost picture from the cost-category investigation.

Before investigating categories, I corrected `sql/10_budget_vs_actual_report.sql` to include employee labor. I summarized labor by project through June 30, mapped all trades to the Labor category, and combined it with transaction costs using a FULL OUTER JOIN on project ID and cost category. Pending exposure remains separate.

### Checks and what I learned

- Revised budget remained $119,564,833.67.
- Pending exposure remained $7,961,647.60.
- Total incurred cost is now $111,386,073.69: $80,468,439.22 in transaction costs plus $30,917,634.47 in employee labor.
- No duplicate project/cost-category groups were found.
- Project incurred totals matched `construction.project_summary`, with zero mismatches.
- P997's $42,000 Labor budget is the only row with no matching cost records. It remains visible and flagged.

For P093, incurred costs are $1,720,860.62 against a revised budget of $2,457,900.00. Remaining budget is $737,039.38, while ETC is $920,841.37, producing a forecast overrun of $183,801.99.

P093 has spent about 70.0% of its budget while reporting 64.6% completion. This suggests cost pressure but does not establish its cause. Physical progress and spending do not necessarily move evenly. Category spending can identify where pressure is concentrated, but without category-level progress or ETC, it cannot allocate the project’s forecast overrun reliably.

I practiced matching summary grain, preserving unmatched records, using COALESCE for absent cost sources, and using IS DISTINCT FROM for NULL-safe reconciliation. I also learned that totals can reconcile correctly while a report still omits a required cost source.

### What's next

Run the updated report-coverage check and labor cutoff inspection in the revised SQL file. Re-export the CSV and validate its totals. The Excel report still needs updating.

Then return to Q6: inspect P093's corrected category costs and remaining budgets, distinguish evidence from possible causes, and investigate its schedule concerns. Q6 is not yet complete. Git closeout remains pending.

## October 5 — Analyzed profitability, overruns, and schedule risks

### What I worked on

I completed Questions 2–4 and documented initial review priorities for Question 5 in `sql/16_project_analysis.sql`, using the June 30, 2026 reporting cutoff.

### Findings and what I learned

- **Question 2:** All 18 active projects have positive forecast profit, with no missing profit values. The lowest forecast margins are P083 (7.65%), P093 (7.99%), and P078 (11.88%). A low margin alone does not establish poor performance without a target for comparison.
- **Question 3:** Nine active projects forecast budget overruns. The largest dollar overruns are P093 ($183,801.99; 7.48%), P083 ($84,680.99; 7.59%), and P089 ($59,521.15; 6.08%). An overrun does not necessarily mean a loss: all active projects still forecast positive profit.
- **Question 4:** Seventeen active projects are behind planned progress, forecast to finish late, or both. Of these, nine have positive forecast delays and eight have unknown delays. P089 has the largest known delay at 36 days. P078 has the largest progress gap at 16.4 percentage points behind plan.
- **Question 5:** All nine projects forecasting overruns also have a known schedule concern. I selected P093, P089, P078, P083, and P080 for initial review, emphasizing dollar overruns and forecast delays while considering margins and progress gaps. This is a judgment-based review group, not a definitive ranking.

I practiced choosing metrics, writing approach comments before SQL, and explaining results. Progress gaps measure percentage points behind or ahead of plan; forecast delays measure days relative to baseline completion. A NULL delay means unknown, not on time. Only nine of all 18 active projects have usable forecast delays.

### What's next

Begin Question 6 by planning how to investigate P093's financial and schedule concerns. Identify the source data needed and distinguish supported findings from possible explanations.

## October 4 — Finished forecast margin and started the analysis

### What I worked on

I added forecast_profit_margin_pct to construction.project_summary and validated it. This lets me compare forecast profitability across projects of different sizes.
I checked which projects have a June 30 update. All 18 active projects and all 3 on-hold projects have one. None of the 75 completed projects has an update on that date. I then checked the on-hold projects and confirmed that all three have ETC values.
I decided to focus the main analysis on active projects and review on-hold projects separately. All 96 projects stay in the analytical layer. Completed projects keep NULL forecasts where the June 30 inputs are unavailable. Missing ETC does not mean there are no remaining costs, so I will not replace it with zero.

### Checks and what I learned

Forecast profit margin is forecast_profit / revised_contract_revenue * 100, rounded to two decimal places. It returns NULL when revenue is zero or missing, or forecast profit is missing. A zero margin means breaking even; NULL means the margin cannot be calculated.
The view still has 96 rows and 96 unique project IDs. The NULL-rule check and calculation check both returned zero violations.
I practiced turning the client request into business questions before writing SQL. We agreed on seven questions:
1. What are the overall forecast revenue, cost, profit, and profit margin for active projects?
2. Which active projects are forecast to lose money or have the lowest margins?
3. Which active projects are forecast to exceed their budgets, and by how much?
4. Which active projects are behind planned progress or forecast to finish late?
5. Which active projects deserve management attention first when financial and schedule risks are considered together?
6. What appears to be driving risk in those priority projects?
7. What recurring patterns should influence future estimating and planning?
First analysis result
I created sql/16_project_analysis.sql and answered Question 1. Across the 18 active projects:
- Revised contract revenue: $25,229,253.42.
- Forecast final cost: $20,541,689.57.
- Forecast profit: $4,687,563.85.
- Combined forecast profit margin: 18.58%.
I calculated the combined margin by dividing total forecast profit by total revenue. This means about $18.58 in forecast project profit per $100 of revenue. It does not mean every project has that margin or that the profit has already been earned.

### What's next

Start Question 2: identify active projects forecast to lose money or have the lowest margins. Write the approach first, then attempt the SQL and explain the results.
The earlier budget-versus-actual SQL, CSV, and Excel report still need the employee labor correction before I use them to investigate cost drivers. Today's documentation and Git closeout are still in progress.


## September 28 — Adding and validating revenue and profitability metrics

### What I worked on

I completed schedule validation and added revenue and forecast profit to
construction.project_summary.

The view now includes the original contract value and four new columns:

- total_revenue_change: Revenue changes approved on or before June 30, 2026,
  summed by project. Projects with no qualifying changes receive zero.
- revised_contract_revenue: Original contract value plus qualifying revenue changes.
- forecast_profit: Revised contract revenue minus forecast final cost.
  Positive means profit; negative means loss. Missing forecast costs produce NULL.
- approved_change_missing_date_flag: Identifies projects with approved change
  orders missing approval dates.

Approved changes with missing approval dates are excluded from cutoff revenue
and flagged for review.

### Checks and what I learned

Schedule inputs matched the cleaned sources. All 18 active projects have usable
progress gaps, but only nine have usable forecast delays. Eight forecasts are
before the report date, and P088 has no forecast completion date.

The updated view retained 96 rows and 96 unique project IDs. Revenue-change
totals matched the source calculations, and checks of revised revenue and
forecast profit returned no differences.

Only P001 was flagged for a missing approval date. Its change order CO0001,
worth $23,877.11, was excluded because its approval timing could not be confirmed.

I learned to distinguish no qualifying changes from an unknown revenue amount.
I confirmed that no qualifying change orders had missing amounts before using
zero for projects with no qualifying changes.

### What's next

Decide whether to add forecast profit margin for comparing different-sized
projects. Also settle how to handle forecasts for completed and on-hold
projects without June 30 updates. The current analysis focuses on active projects.

## September 27 - Adding and validating schedule metrics

### What I worked on

I added two schedule metrics to the analytical layer using the June 30 project updates.

Progress gap compares planned percentage complete with actual percentage complete. I calculate planned minus actual, measured in percentage points. Positive means behind planned progress, negative means ahead, and zero means progress matches the plan.

Forecast delay compares the forecast completion date with the baseline completion date. I calculate forecast minus baseline, measured in days. Positive means forecast late, negative means early, and zero means the dates match.

I saved the analytical query as construction.project_summary so I can run separate validation queries without copying the full query each time.

### Checks and what I learned

The view returned 96 rows and 96 unique project IDs. Checks 13B–13E returned zero failures for the schedule rules we tested.

All 18 active projects have usable progress gaps, but only nine have usable forecast delays. A NULL delay means the metric is unavailable, not that the project is on time.

P092 helped me understand why correct arithmetic is not enough. Its June 30 report showed unfinished work but a forecast completion date in March. I preserved the date and flag but excluded it from the forecast-delay calculation. Its progress gap remained usable.

I needed help translating the rules into CASE expressions and validation filters, especially deciding when to use AND versus OR. I want more practice explaining those conditions before writing SQL.

### What's next

Step 13G is written but has not been run. I will inspect the nine active projects without usable forecast delays and identify which missing dates or flags caused them.

Then I will reconcile the active projects' schedule inputs in the view against the cleaned source tables. Schedule validation is not yet complete.

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

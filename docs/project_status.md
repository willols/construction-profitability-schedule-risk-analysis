# Project Status

Last updated: September 24, 2026

## Current Phase

The comparison used all supplied approved change orders without an
approval-date cutoff. On September 24, the final reconciliation file
was confirmed saved and executed, reproducing 0 nonzero differences
and 38 unmatched projects with zero budget adjustments.

The analysis plan is confirmed saved at docs/analysis_plan.md.
It defines three business questions:

1. Which active projects need attention?
2. What appears to contribute to their profitability and schedule risk?
3. Which recurring problems should inform estimating and planning?

### Project-Level Analytical Layer — In Progress

Work has begun in sql/15_project_analytical_layer.sql.

Target grain: one row per authoritative project as of June 30, 2026.
Retain all projects; prioritize active projects for the first question.

Implemented in the working query:

- Aggregate non-payroll incurred costs by cleaned project ID.
- Include paid, approved, and applied transactions dated on or before
  June 30. Exclude pending transactions from incurred cost.
- Aggregate employee labor costs by cleaned project ID, including
  work dated on or before June 30.
- Anchor on cleaned_projects and LEFT JOIN both cost summaries.
- Add the two components as total_incurred_cost.
- Aggregate supplied revised budgets by project and LEFT JOIN them
  to the analytical query.

Reported query checks:

- Non-payroll summary: 96 project rows.
- Labor summary: 96 project rows.
- Joined cost output: 96 rows, with no NULL cost-component totals.
- Adding revised budgets retained 96 rows, with no NULL budget totals.

Cutoff-update checks:

- All 18 active projects have a June 30 update.
- All 18 matching updates have populated estimated costs to complete.
- The June 30 duplicate-update check returned 0 rows: no project has
  more than one update on that date.

Step 7 selects project_id, report_date_clean, and
estimated_cost_to_complete_clean for June 30 as a standalone query.
Its duplicate check remains a separate validation.

The cutoff-update selection has not yet been added as a CTE or joined
to the main query. Forecast final cost, forecast budget variance,
schedule metrics, and revenue adjustments remain unimplemented.

Date alignment and populated ETC values do not establish estimate
accuracy. Forecast calculations will rely on the documented assumption
that ETC covers all remaining costs, including employee labor, and
excludes costs already incurred at the update date.

Source-to-output monetary reconciliation and separate orphan accounting
remain pending. No persistent analytical-layer table or view exists.
Saving the final September 24 SQL file and end-to-end execution of that
file have not yet been confirmed.

Latest confirmed commit: 81aed56, pushed September 18.
Message: Complete and validate cleaned labor entries view.
The September 18 handoff confirmed local main matched origin/main
and the working tree was clean then.
September 21–24 work has not yet been confirmed committed or pushed.

## Profiling File Structure

Profiling SQL is organized into separate dataset-specific files:

| Dataset | SQL file | Status |
| --- | --- | --- |
| `projects.csv` | `sql/01_projects_profiling.sql` | Planned profiling complete |
| `project_budgets.csv` | `sql/02_project_budgets_profiling.sql` | Planned profiling complete, including project-ID validation through 90A |
| `cost_transactions.csv` | `sql/03_cost_transactions_profiling.sql` | Planned standalone and transaction-relationship profiling complete |
| `labor_entries.csv` | `sql/04_labor_entries_profiling.sql` | Planned profiling complete through 40A |
| `project_updates.csv` | `sql/05_project_updates_profiling.sql` | Planned profiling complete through 63A |
| `change_orders.csv` | `sql/06_change_orders_profiling.sql` | Planned profiling complete through 89 |

The superseded combined `sql/01_data_profiling.sql` file has been removed.
Existing investigation numbers and documentation references were preserved
during the reorganization.

## Reporting Cutoff

The reporting cutoff is June 30, 2026, inclusive.

* Actual activity dated on or before the cutoff belongs in cutoff-based
  analysis.
* Actual activity after the cutoff remains in the raw data but will be excluded
  from cutoff-based calculations.
* Future planned and forecast dates remain because they support schedule-risk
  analysis.
* The budget-versus-actual view now enforces the transaction cutoff before
  cost aggregation. Validation found zero transactions after June 30, 2026
  or with NULL transaction dates.
* The report uses supplied revised budgets. Neither the raw budget table
  nor its cleaned view includes an effective date or version history.
* Budget validity at the reporting cutoff remains unverified and is
  documented as a reporting limitation.

## Dataset Status

### Projects

Standalone profiling is complete.

Key results:

* `projects.csv` contains 97 raw rows and 96 distinct project IDs.
* P042 is an exact duplicate.
* P052 is the only project with a missing `project_type`.
* Six raw project-status labels represent three logical categories: active,
  completed, and on hold.
* P013 contains the ambiguous baseline completion date `8/10/2023`.
* P066 contains the formatted original contract value `$672,000`.
* No actual completion date occurs before its corresponding actual start date.
* No actual activity occurs after the reporting cutoff.
* Safely parsed baseline completion dates extend through December 18, 2026.
  Future baseline dates remain valid for schedule-risk analysis.
* Normalized original contract values range from $276,000 to $3,773,000.
* Original budgets range from $223,600 to $2,917,000.
* No original budget exceeds its normalized original contract value.

Confirmed cleaning rules:

* Retain one P042 row in cleaned output.
* Preserve the raw `project_status` value and apply these explicit mappings in
  standardized output:
  - `active` and ` active ` → `active`
  - `completed` and `Complete` → `completed`
  - `on_hold` and `On Hold` → `on_hold`
* Normalize P066's original contract value to `672000.00`.
* Preserve P013's raw date and exclude it from calculations requiring a
  confirmed baseline completion date.
* Treat P052's `project_type` as unknown unless authoritative evidence becomes
  available.

#### Cleaning Implementation

Projects cleaning is complete in `sql/07_projects_cleaned.sql`.

The reusable view `construction.cleaned_projects` is stored in the
persistent `construction.duckdb` database. It removes exact duplicates,
preserves original columns, and adds:

- `project_status_clean`
- `original_contract_value_clean`
- `baseline_completion_date_clean`
- `project_type_missing_flag`
- `baseline_completion_date_unresolved_flag`

P013's ambiguous baseline completion date remains NULL in the cleaned
column while its raw value is preserved. P052's project_type remains NULL.
P066's cleaned contract value is 672000.00.

The project-type flag identifies NULL project types. The unresolved-date
flag identifies populated raw baseline dates that cannot convert to DATE.
Flags identify limitations without automatically excluding entire projects.

The view stores the cleaning query rather than a separate copy of its
results. It reads `data/raw/projects.csv` when queried. Changes to the
saved definition require execution of `CREATE OR REPLACE VIEW`.

#### Cleaned-Layer Validation

- Validation 1: 96 rows and 96 distinct project IDs; passed.
- Validation 2: Zero populated contract values became NULL; passed.
- Validation 3: Only P013's populated baseline completion date became NULL,
  matching the documented exception; passed.
- Validation 4: on_hold (3), active (18), completed (75); total 96,
  with no unexpected statuses; passed.
- Validation 5: Cleaned status is VARCHAR, cleaned contract value is
  DECIMAL(10,2), and cleaned baseline completion date is DATE; passed.
- baseline_start_date and actual_completion_date are already DATE.
- Validation 6: Cleaned and deduplicated-source reference contract totals
  both equal 141761000.00; difference = 0.00; passed.
- The reference uses P066's independently verified 672000.00 and direct
  decimal conversion for the remaining deduplicated source records.
- Validation 7: P052 appears once with project_type = NULL; passed.
- Exception check: Only P052 has a missing project type, and only P013
  has an unresolved baseline completion date; passed.
- Final saved-view check: 96 rows, 96 distinct project IDs,
  contract total = 141761000.00, one missing project type,
  and one unresolved baseline completion date; passed.

### Project Budgets

Standalone profiling and project-ID validation are complete through
Investigations 90 and 90A.

Key results:

* `project_budgets.csv` contains 674 rows, 673 distinct `budget_line_id`
  values, 97 distinct project IDs, and 673 distinct project/category pairs.
* BUD-P031-01 appears twice, and the two records are exact duplicates.
* BUD-P057-04 is the only row with a missing `original_budget_amount`.
* BUD-P057-04 has an approved change of 0 and a revised budget of 31,672.00.
* The formula-derived candidate original budget for BUD-P057-04 is 31,672.00,
  but the value is not source-confirmed.
* Eleven raw `cost_category` values represent seven canonical categories.
* `$3,485.49` is the only approved-budget-change value that fails direct
  numeric conversion.
* Removing `$` and `,` allows every populated approved change to parse.
* Revised budgets range from 6,957.72 to 886,036.18.
* Two-decimal scale preserves every observed revised budget.
* Of 674 rows, 673 satisfy the expected monetary relationship and one is
  untestable because of the missing original budget.
* `DECIMAL(10, 2)` was selected for cleaned monetary fields.
- BUD-P997-01 is the only budget row without a matching project in projects.csv.
- It references P997 in the Labor category, with original and revised budgets
  of 42,000.00 and an approved budget change of 0.00.
- All 96 authoritative projects have at least one matching budget row.
- Project-level coverage does not establish complete cost-category coverage.
- An inner join to projects would exclude the orphan row and its budget.

Confirmed cleaning rules:

* Retain one BUD-P031-01 row in cleaned output.
* Apply the following category mappings:
  - `General conditions` → `General Conditions`
  - `Materials ` → `Materials`
  - `labor` → `Labor`
  - `Sub-Contractors` → `Subcontractors`
* Remove `$` and `,` from `approved_budget_change` before numeric conversion.
* Convert cleaned monetary fields to `DECIMAL(10, 2)`.
* Preserve BUD-P057-04's source NULL.
* If the formula-derived 31,672.00 candidate is used, expose it separately
  and flag it as inferred.
* Preserve BUD-P997-01 and its source project_id P997.
* Flag the row as an orphan requiring stakeholder clarification.
* Do not assign a replacement project ID without authoritative evidence.
* Account for its budget separately when reconciling source budgets
  with project-level analytical totals.

#### Cleaning Implementation

Cleaning is complete in `sql/08_project_budgets_cleaned.sql`.

The reusable view `construction.cleaned_project_budgets` is saved in
the persistent `construction.duckdb` database.

The cleaning query uses `deduplicated` and `cleaned_project_budgets`
CTEs to remove exact duplicates before applying transformations and
joining to `construction.cleaned_projects`.

It preserves raw budget columns and adds:

- `cost_category_clean`
- `approved_budget_change_clean`
- `original_budget_amount_clean`
- `revised_budget_amount_clean`
- `original_budget_missing_flag`
- `orphan_project_flag`

BUD-P057-04's original-budget NULL remains NULL in cleaned output.
The optional formula-derived 31672.00 candidate is not included.

A LEFT JOIN preserves BUD-P997-01 and its source project_id P997.
The unmatched project is flagged for stakeholder clarification;
no replacement ID is assigned. Its budget was reconciled separately.

The view stores the cleaning query rather than a separate copy of its
results. It reads the source CSV when queried.

#### Cleaned-Layer Validation

- Validation 1 PASS: 673 rows and 673 distinct budget_line_id values.
- Validation 2 PASS: all documented category mappings are correct;
  already-standardized categories remain unchanged. Seven cleaned
  categories remain: Equipment, General Conditions, Labor, Materials,
  Other, Permits & Fees, and Subcontractors.
- Validation 3 PASS: zero populated raw monetary values became NULL
  during conversion across all three monetary fields.
- Validation 4 PASS: only BUD-P057-04 has the missing-budget flag;
  its raw and cleaned original-budget amounts are both NULL.
- Validation 5 PASS: only BUD-P997-01 has the orphan flag;
  its source project_id remains P997.
- Validation 6 PASS: all three cleaned monetary fields are DECIMAL(10, 2).
- Validation 7 PASS: all three deduplicated-source totals equal their
  cleaned totals. Matched-project totals plus orphan totals equal
  full cleaned totals. All cleaning and split differences are 0.00.

| Monetary field | Source total | Cleaned total | Matched total | Orphan total |
| --- | ---: | ---: | ---: | ---: |
| Original budget | 116164328.00 | 116164328.00 | 116122328.00 | 42000.00 |
| Approved budget change | 3368833.67 | 3368833.67 | 3368833.67 | 0.00 |
| Revised budget | 119564833.67 | 119564833.67 | 119522833.67 | 42000.00 |

The original-budget total excludes the known NULL; reconciliation
does not resolve that missing amount.

Saved-view verification PASS: 673 rows and 673 distinct budget_line_id
values returned from `construction.cleaned_project_budgets`.


### Cost Transactions

Standalone and required transaction-relationship profiling is complete.

Key results:

* `cost_transactions.csv` contains 11,204 rows and 11,203 distinct
  `transaction_id` values.
* TX000138 occurs twice, and the two records are exact duplicates.
* Retaining both TX000138 records would overstate P002's Materials cost by
  14,821.14.
* TX000316 is the only transaction with a missing `project_id`.
* Transaction-order evidence supports assigning TX000316 to P003.
* TX000729 is the only transaction assigned to P998.
* P998 does not exist in `projects.csv` or `project_budgets.csv`.
* Transaction context supports assigning TX000729 to P007.
* `$46.90` is the only amount that fails direct numeric conversion.
* Removing `$` and `,` allows all 11,204 amount values to parse.
* Normalized amounts range from -1,800.00 to 83,246.69.
* Two-decimal scale preserves every observed amount.
* `DECIMAL(10, 2)` was selected for the cleaned amount field.
* Three negative transactions are valid returned-material credits of
  -1,800.00 each.
* Transaction dates range from January 28, 2023, through June 30, 2026.
* No transaction occurs after the reporting cutoff.
* P998 is the only unmatched non-NULL transaction project ID.
* Six raw transaction project/category pairs initially failed budget matching.
* All six mismatches are explained by documented project-ID or category
  inconsistencies.
* After applying documented corrections, zero transaction project/category
  pairs remain unmatched.

Payment-status results after standardization and deduplication:

| Payment status | Transaction count | Cleaned amount total |
| --- | ---: | ---: |
| paid | 8585 | 67748448.37 |
| approved | 1635 | 12725390.85 |
| pending | 980 | 7961647.60 |
| applied | 3 | -5400.00 |
| Total | 11203 | 88430086.82 |

These cleaned totals supersede the raw-row profiling totals for reporting.
Removing one paid TX000138 duplicate reduces the paid count by one and
the paid amount by 14821.14.

Reporting treatment:

- For this dataset, paid and approved transactions plus negative applied
  credits form incurred cost: 80468439.22.
- Pending transactions remain separate as pending exposure: 7961647.60.
- Incurred cost plus pending exposure equals 88430086.82.
- This combined amount represents recorded transaction exposure, not a
  maximum forecast of final project cost.
- No approval probability will be assigned to pending transactions.
- These figures cover the full cleaned transaction dataset. The reporting
  query must explicitly apply the June 30, 2026 cutoff.
- Pending transactions do not establish all outstanding commitments or
  costs for completed work awaiting invoices.
- Budget remaining must not be presented as estimated cost to complete.


Confirmed cleaning rules:

* Retain one TX000138 record.
* Assign P003 specifically to TX000316.
* Assign P007 specifically to TX000729.
* Remove `$` and `,` from amount values before conversion to
  `DECIMAL(10, 2)`.
* Apply the following category mappings:

  * `Sub-Contractor` → `Subcontractors`
  * `materials ` → `Materials`
* Standardize payment statuses with `LOWER(TRIM(payment_status))`.

#### Cleaning Implementation

Cleaning is complete in `sql/09_cost_transactions_cleaned.sql`.

The reusable view `construction.cleaned_cost_transactions` is saved
in the persistent `construction.duckdb` database.

The query removes exact duplicates using SELECT DISTINCT, preserves
all raw columns, and adds:

- `project_id_clean`
- `project_id_corrected_flag`
- `cost_category_clean`
- `amount_clean`
- `payment_status_clean`

Project-ID corrections are transaction-specific:

- TX000316 retains raw NULL and produces cleaned P003.
- TX000729 retains raw P998 and produces cleaned P007.
- All other project IDs remain unchanged.

The correction flag identifies those two transactions.

Category cleaning maps Sub-Contractor to Subcontractors and materials
to Materials, while trimming surrounding whitespace.

Amount cleaning removes dollar signs and commas before TRY_CAST to
DECIMAL(10, 2). Negative credits retain their signs.

Payment statuses are standardized with LOWER(TRIM(payment_status)).

The view stores the cleaning query and reads
`data/raw/cost_transactions.csv` when queried. Changes to its saved
definition require execution of CREATE OR REPLACE VIEW.

#### Cleaned-Layer Validation

- Validation 1 PASS: 11203 rows and 11203 distinct transaction IDs.
- Validation 2 PASS: the two flagged transactions have the documented
  project-ID corrections, with raw values preserved.
- Validation 3 PASS: correction-flag counts are 2 TRUE and 11201 FALSE.
- Validation 4 PASS: zero populated raw amounts became NULL during
  conversion.
- Validation 5: standardized status counts reconcile to 11203:
  paid 8585, approved 1635, pending 980, and applied 3.
- Validation 6 PASS: raw-to-cleaned category mappings inspected
  and confirmed.
- Validation 7 PASS: three applied credits retain -1800.00 each
  in raw and cleaned amounts, totaling -5400.00.
- Validation 8 PASS: zero cleaned transaction project IDs lack
  a match in construction.cleaned_projects.
- Validation 9 PASS: four payment-status groups total 11203
  transactions, with monetary totals recorded above.
- Validation 10 PASS:
  - Full cleaned total: 88430086.82.
  - Incurred cost: 80468439.22.
  - Pending exposure: 7961647.60.
  - Full total minus incurred cost minus pending exposure: 0.00.

The full reference total uses unconditional SUM(amount_clean).
This prevents unexpected statuses from being excluded from both
the reference total and the reporting groups.

The reconciliation verifies the reporting split. It does not
independently prove source completeness or monetary conversion accuracy.

Saved-view verification PASS: 11203 rows and 11203 distinct
transaction IDs returned directly from
`construction.cleaned_cost_transactions`.

Project/category budget matching was revalidated in
`sql/10_budget_vs_actual_report.sql` on September 13.

All 576 aggregated transaction groups matched budget groups.
The FULL OUTER JOIN retained 673 rows, including 97 budget-only groups,
with zero cost-only groups. Incurred cost, pending exposure, and revised
budget totals were preserved after joining.

Final report validation was completed on September 14 after adding
output columns, project context, and the transaction cutoff.
The report retained 673 unique project/category rows and all three
monetary totals. The saved construction.budget_vs_actual_report view
also returned 673 rows and matching monetary totals.

### Labor Entries

Standalone profiling is complete through Investigation 40A. Labor timeline
results were revalidated with the complete date-parsing rule, and the
employee-date grain and overtime-interpretability investigations are complete.

#### Structure and Completeness

* `labor_entries.csv` contains 18,004 raw rows and nine columns.
* `time_entry_id` is the confirmed technical row-level key after exact duplicate
  removal.
* The business reporting period represented by each labor row remains unknown.
* The file contains 18,004 non-NULL `time_entry_id` values and 18,003 distinct
  identifiers.
* TE000222 occurs twice, and the two records are exact duplicates.
* After duplicate removal, the expected cleaned row count and distinct
  identifier count are both 18,003.
* All text columns are complete.
* `hourly_rate` is the only column containing a NULL value.

#### Work Dates

* All 18,004 `work_date` values are populated.
* A total of 18,003 values parse directly as DATE.
* TE002542 contains the only direct parsing failure: `5/19/2023`.
* The value unambiguously represents May 19, 2023.
* Standard parsing followed by an `M/D/YYYY` fallback converts all 18,004
  values successfully.
* Standardized dates range from January 28, 2023, through June 30, 2026.
* No labor entry occurs after the reporting cutoff.

#### Numeric Fields

* `regular_hours` ranges from 0.0973 to 46, with no zero or negative values.
* `overtime_hours` ranges from 0 to 9, with 14,033 zero values and no negative
  values.
* Non-NULL `hourly_rate` values range from 27 to 68, with no zero or negative
  values.
* `labor_cost` ranges from 5.80 to 3,822.02, with no zero or negative values.
* Four entries contain the maximum of 46 regular hours, and all four record zero
  overtime.
* A total of 6,727 entries record more than 40 regular hours.
* Of those entries, 5,178, or 76.97%, record zero overtime.
* The dataset does not establish the time period represented by a labor entry
  or the business rules governing regular and overtime classification.
* Four decimal places are required to preserve every `regular_hours` value.
* Two decimal places preserve every non-NULL `overtime_hours`, `hourly_rate`,
  and `labor_cost` value.

#### Labor-Cost Formula Validation

The supported combined-total formula is:

```text
ROUND(
    (regular_hours × hourly_rate)
    + (overtime_hours × hourly_rate × 1.5),
    2
)
```

Aggregate results:

* The formula is testable for 18,003 rows.
* It matches 17,850 rows, or 99.15%.
* It mismatches 153 rows, or 0.85%.
* Of the 153 mismatches, 152 recorded labor costs are 0.01 below the calculated
  value.
* TE003191 is the only material exception.
* TE003191 records labor cost of 1,530.88 compared with an expected 1,405.88,
  producing an unexplained difference of 125.00.

Formula-overlap results:

* 16,948 rows match both formulas.
* 902 rows match combined-total only.
* 9 rows match component-level only.
* 144 rows match neither formula.
* Component-level rounding matches 16,957 rows overall, compared with 17,850
  combined-total matches.
* Component-level rounding fixes only 9 combined-total mismatches while causing
  902 previously matching rows to mismatch.
* Component-level rounding therefore produces 893 fewer matches overall.
* All 9 component-level-only rows contain positive overtime.
* For those 9 rows, combined-total is 0.01 above recorded labor cost while
  component-level rounding matches exactly.
* Of the 144 neither-match rows, 143 have both formulas producing the same
  result, 0.01 above recorded labor cost.
* TE003191 is the remaining neither-match row.

Decision:

* Combined-total rounding remains the primary labor-cost validation formula.
* Component-level rounding is rejected as the primary formula.
* The 152 one-cent exceptions will be preserved and documented rather than
  automatically corrected.
* TE003191 will remain unchanged and be flagged for stakeholder clarification.

#### Missing Hourly Rate

* TE001843 is the only row with a missing `hourly_rate`.
* It records 43.57 regular hours, zero overtime, and labor cost of 1,697.49.
* The implied hourly rate is 38.96.
* Investigation 35 tested all 4,101 possible two-decimal rates from 27.00
  through 68.00.
* A rate of 38.96 was the only candidate that reproduced the recorded labor
  cost under the combined-total formula.

Decision:

* Impute 38.96 in the cleaned analytical output.
* Preserve the raw NULL.
* Flag the cleaned value as formula-derived rather than source-confirmed.

#### Trade Values

Six distinct raw trade values were identified:

* `Carpenter`: 7,160 rows
* `Laborer`: 4,571 rows
* `Finisher`: 3,703 rows
* `Superintendent`: 2,568 rows
* `carpenter `: 1 row
* `General Labor`: 1 row

The four established categories account for 18,002 of the 18,004 rows.

* TE000917 contains the `carpenter ` formatting variant.
* The value differs from `Carpenter` by capitalization and trailing whitespace.
* TE001216 contains the dataset's only `General Labor` value.
* TE001216 belongs to employee E401.
* The isolated row does not provide enough evidence to determine whether
  `General Labor` is equivalent to `Laborer`.

#### Employee Trade History

* E401 has 949 labor entries.
* Of those entries, 948 are recorded as `Finisher` and one is recorded as
  `General Labor`.
* E401 has no entries recorded as `Laborer`.
* The employee's history therefore does not support standardizing
  `General Labor` to `Laborer`.
* The available evidence cannot determine whether TE001216 represents a
  legitimate temporary assignment or a source-data error.

Decision:

* Preserve TE001216's raw `General Labor` value.
* Flag the entry as unresolved pending stakeholder clarification.
* Do not map the value to either `Laborer` or `Finisher` without authoritative
  evidence.

#### Employee IDs

* The dataset contains 19 distinct employee IDs.
* Every employee ID matches the expected format of an uppercase `E` followed by
  exactly three digits.
* Entry counts range from 633 for E301 to 1,216 for E115.
* No isolated low-frequency employee ID suggests a typo or stray value.

Decision:

* No `employee_id` cleaning or correction rule is required.

#### Labor-to-Project Relationship

* P996 is the only labor `project_id` that does not exist in `projects.csv`.
* P996 affects one labor entry: TE000408.
* TE000408 records internally consistent hours, rate, and labor cost, but its
  row-level fields do not independently identify the intended project.
* The five neighboring time entries before TE000408 and the five after it all
  reference P003.
* P996 therefore interrupts an otherwise continuous P003 project block.

Decision:

* Correct TE000408's project ID from P996 to P003 only in cleaned output.
* Preserve the raw P996 value and flag the record as a source-data correction.

#### Labor and Project Timelines

The revalidated timeline query returned:

* 18,003 deduplicated labor entries
* 52 entries before baseline start
* 0 entries before actual start
* 2,818 entries after baseline completion
* 0 entries after an available actual completion date
* 0 entries after the reporting cutoff

The revalidated project summary distributed the 2,818 post-baseline entries
across 78 projects.

* P026 has the most post-baseline entries at 126.
* The ten highest-count projects account for 973 entries.
* P090 has the longest observed extension at 209 days beyond baseline
  completion.
* Post-baseline labor is broadly distributed rather than caused by a few
  isolated projects.
* Labor after baseline completion represents schedule-variance evidence and
  should not be treated automatically as a data-quality error.

TE002542 now parses correctly as May 19, 2023. It belongs to P013, occurs after
the project's baseline and actual starts, and occurs before actual completion.
P013 has a NULL baseline completion date, so TE002542 cannot be evaluated under
the post-baseline rule.

Decision:

* Treat the Investigation 39 and 39A results as final.
* Preserve post-baseline labor as valid schedule-variance evidence.

#### Labor-Entry Grain and Overtime Interpretation

Investigations 40 and 40A are complete.

* A total of 4,316 employee-date combinations contain more than one
  deduplicated labor entry.
* `employee_id` and `work_date` therefore do not form a unique row key.
* The largest observed group was E101 on February 26, 2024, with eight entries
  across six corrected projects.
* That group contains 298.68 regular hours and 3.88 overtime hours, which cannot
  represent one employee's daily labor total.
* The results suggest project-level allocations or another reporting
  convention, but they do not establish a daily, weekly, biweekly, or monthly
  row period.
* A total of 11,995 unique employee-date combinations were evaluated across
  weekdays.
* Tuesday had the highest count at 1,748, or 14.57%, while Friday had the lowest
  at 1,672, or 13.94%.
* The difference was only 76 combinations, or 0.63 percentage points.
* No weekday shows meaningful concentration, so the results do not support a
  recurring weekly reporting boundary.

Decision:

* `time_entry_id` remains the confirmed row-level key after duplicate removal.
* Preserve recorded `regular_hours` and `overtime_hours`.
* Do not reclassify hours without an authoritative reporting-period definition
  and overtime rule.
* Document the unknown `work_date` cadence as an analytical limitation.

Confirmed cleaning rules:

* Retain one TE000222 row.
* Convert `work_date` to DATE using standard parsing followed by the validated
  `M/D/YYYY` fallback.
* Standardize TE002542's date to `2023-05-19`.
* Preserve `regular_hours` at four-decimal scale.
* Preserve `overtime_hours`, `hourly_rate`, and `labor_cost` at two-decimal
  scale.
* Use DECIMAL(10,4) for regular_hours_clean.
* Use DECIMAL(10,2) for overtime_hours_clean, hourly_rate_clean,
  and labor_cost_clean.
* Impute TE001843's hourly rate as 38.96 and flag it as formula-derived.
* Standardize `carpenter ` to `Carpenter`.
* Preserve TE001216's `General Labor` value and flag it as unresolved.
* Assign P003 specifically to TE000408 in cleaned output.
* Preserve TE000408's raw P996 value and flag the correction.
* Preserve post-baseline labor as schedule-variance evidence.
* Do not reclassify regular or overtime hours without a confirmed reporting
  period and authoritative overtime rule.
* Preserve raw source values unchanged.

#### Cleaning Implementation

Cleaning is complete in `sql/11_labor_entries_cleaned.sql`.

Individual steps 1–10, combined Cleaning step 11, and
Validations 1–16 passed.

The reusable view `construction.cleaned_labor_entries` is saved
in construction.duckdb. It preserves raw columns, adds cleaned
columns and four flags, and retains recorded labor costs.

Saved-view verification confirmed:

- 18003 rows and 18003 distinct time_entry_id values.
- Total labor_cost_clean of 30917634.47.
- Only TE001843, TE000408, TE001216, and TE003191 are flagged,
  each with only its intended flag TRUE.

All cleaned labor project IDs match construction.cleaned_projects.
Numeric value comparisons detected no differences among non-NULL
raw/cleaned pairs, and source/cleaned cost totals reconcile to the cent.

See Labor Cleaning Complete for detailed validation results.
Documented business uncertainties remain unresolved.

### Project Updates

Standalone profiling is complete through Investigation 63A.

Investigations 58–60 profiled `estimated_cost_to_complete`. Investigation 61
validated its chronological behavior, and Investigations 61A–61D investigated
the unexpected 97th project-ID partition and orphan P995 update.

Investigations 62 and 62A profiled `primary_delay_reason` and tested the
operational meaning of its `None` category. Investigations 63 and 63A profiled
`submitted_by` and confirmed that its isolated `Unknown` value belongs to
UPD99999 and P995.

No standalone `project_updates.csv` fields remain unprofiled. The complete
profiling file has been executed successfully through Investigation 63A.

#### Structure and Row-Level Identifier

* `project_updates.csv` contains 726 raw rows and nine columns.
* `update_id`, `project_id`, `primary_delay_reason`, and `submitted_by` were
  inferred as `VARCHAR`.
* `report_date` and `actual_pct_complete` were inferred as `VARCHAR`.
* `planned_pct_complete` and `estimated_cost_to_complete` were inferred as
  `DOUBLE`.
* `forecast_completion_date` was inferred as `TIMESTAMP`.
* The file contains 726 populated `update_id` values and 725 distinct
  identifiers.
* UPD00655 occurs twice, and the two complete records match across all nine
  columns.
* After removing one exact UPD00655 duplicate, the expected cleaned row count
  and distinct `update_id` count are both 725.

Decision:

* Retain one UPD00655 record and remove the repeated occurrence only in the
  cleaned analytical layer.
* Use `update_id` as the cleaned row-level identifier.
* Preserve the raw CSV unchanged.

#### Business Grain

* The initial grain test grouped records by raw `project_id` and `report_date`.
* No raw project-date combination contained more than one distinct
  `update_id`.
* Investigation 45 established that one report date uses a different valid
  format, which made the raw-text result provisional.
* Investigation 43A repeated the test using standardized `report_date` values.
* No `(project_id, standardized_report_date)` combination contains more than
  one distinct `update_id`.
* Standardizing the dates did not reveal any project-date combinations hidden
  by inconsistent raw date formats.

Decision:

* Treat one project update per project and standardized reporting date as the
  observed business grain.
* Use `update_id` as the cleaned row-level identifier after removing one
  occurrence of the exact UPD00655 duplicate.

#### Completeness and Text Quality

* Eight of the nine columns contain no NULL values.
* `forecast_completion_date` contains one NULL value.
* The missing value belongs to UPD00664 for project P088.
* None of the four `VARCHAR` fields contain blank or whitespace-only values.
* None of their populated values change after applying `TRIM()`.
* No leading- or trailing-whitespace normalization is currently required.
* Internal spaces were not targeted because they may be legitimate parts of
  populated values.

#### Missing Forecast Completion Date

* P088 contains four project-update records.
* Its first two updates contain a forecast date of July 27, 2026.
* Its third update contains a forecast date of July 28, 2026.
* Those three updates list `Owner decision / change order` as the primary delay
  reason.
* The fourth update, UPD00664, was reported on June 30, 2026.
* UPD00664 records planned completion of 80.9%, actual completion of 81.7%, and
  a NULL forecast date.
* Its primary delay reason changes to `Subcontractor availability`.
* The new delay introduces an unknown scheduling impact, so the earlier
  forecast cannot be carried forward reliably.

Decision:

* Preserve UPD00664's NULL `forecast_completion_date` in the cleaned analytical
  layer.
* Flag the missing value for business clarification.
* Do not substitute a prior forecast or later actual completion date.
* Preserve the raw CSV unchanged.

#### Report Dates

* All 726 `report_date` values are populated.
* A total of 725 values convert directly to `DATE`.
* One value requires the `%m/%d/%Y` fallback.
* Zero values fail both accepted parsing methods.
* UPD00045 for project P006 contains the fallback-parsed value.
* Its raw `report_date` of `8/31/2024` standardizes to `2024-08-31`.
* The valid format variation explains why DuckDB inferred the column as
  `VARCHAR`.
* Standardized report dates range from February 25, 2023, through June 30,
  2026.
* The latest report date equals the established reporting cutoff.
* Zero project-update records occur after the cutoff.

Decision:

* Convert cleaned `report_date` values to `DATE`.
* Attempt standard DATE conversion first, followed by the validated
  `%m/%d/%Y` fallback.
* Preserve the raw source values unchanged.
* No report-date exclusions are required.

#### Forecast Completion Date Type

* `project_updates.csv` contains 726 total rows.
* A total of 725 rows contain a populated `forecast_completion_date`.
* UPD00664 contains the one NULL forecast date.
* All 725 populated values contain midnight timestamps.
* Zero populated values contain non-midnight time components.
* The timestamp portion therefore contains no additional observed information.

Decision:

* Convert populated `forecast_completion_date` values to `DATE` in the cleaned
  analytical layer.
* Preserve UPD00664's NULL forecast date and flag it for business
  clarification.
* Preserve all raw source values unchanged.

#### Forecast-Date Range and Report-Date Relationships

* Standardized forecast completion dates range from May 14, 2023, through
  January 23, 2027.
* Of the 725 populated forecast dates:

  * 40 occur before their standardized report date.
  * 75 occur on their standardized report date.
  * 610 occur after their standardized report date.
* The three relationship categories reconcile to all 725 populated forecast
  dates.
* Sixty-nine forecast dates extend beyond the June 30, 2026 reporting cutoff.
* Future forecast dates remain valid because they can represent expected
  completion after the portfolio reporting date.
* The 40 forecast-before-report records span eight projects: P076, P077, P083,
  P084, P085, P090, P091, and P092.
* Their forecast-to-report gaps range from 1 to 165 days.
* All 40 records contain `planned_pct_complete` values of 100.
* Their raw `actual_pct_complete` values suggest a possible mixture of
  post-completion reporting and overdue or stale forecasts.

Decision:

* Do not classify the 40 forecast-before-report records as data errors based on
  the within-file relationship alone.
* Preserve the records for project-timeline and completion-status comparisons.
* Retain forecasts extending beyond the reporting cutoff for schedule-risk
  analysis.

#### Actual Completion Percentage

- DuckDB infers `actual_pct_complete` as `VARCHAR`.
- All 726 rows contain populated values.
- A total of 725 values convert directly to diagnostic `DECIMAL(10, 4)` values.
- UPD00164 contains the only direct conversion failure and is stored as `89.7%`.
- Removing percent symbols allows all 726 values to convert successfully.
- Standardized values range from 7.5 through 105.
- Zero values are below 0 or equal to 0.
- One value exceeds 100, and 108 values equal 100.
- Casting standardized values to zero decimal places changes 549 values.
- Casting to one, two, or three decimal places changes zero values.
- One decimal place is therefore the minimum lossless scale.
- The maximum value of 105 requires three integer digits.

Decision:

- Remove percent symbols before numeric conversion.
- Standardize UPD00164 from `89.7%` to `89.7`.
- Use `DECIMAL(4, 1)` for cleaned `actual_pct_complete`.
- Preserve all raw source values unchanged.

#### Above-Range Actual Completion and P040 Progression

- UPD00313 for P040 contains the only standardized actual percentage above 100.
- P040 contains eight updates from March 20 through September 29, 2024.
- Its actual completion progresses through 10.5, 25, 40, 50.9, 105, 77.2, 90, and 100.
- UPD00313's value of 105 creates the only nonmonotonic step in the otherwise increasing progression.
- The value rises from 50.9 to 105 and then falls to 77.2.
- UPD00313 records planned completion of 65.4, producing a positive variance of 39.6 percentage points.
- The progression provides strong evidence that 105 is anomalous but does not establish its intended replacement.

Decision:

- Preserve UPD00313's value of 105 in the cleaned analytical layer.
- Flag the record for stakeholder clarification.
- Do not cap the value at 100 or infer another replacement without authoritative evidence.

#### Planned Completion Percentage

- All 726 `planned_pct_complete` values are populated.
- All 726 values convert directly to diagnostic `DECIMAL(10, 4)` values.
- Zero NULL values and zero conversion failures were identified.
- No formatting normalization is required.
- Standardized values range from 8.8 through 100.
- Zero values fall below 0 or above 100.
- Zero values equal 0, while 185 equal 100.
- Casting to zero decimal places changes 488 values.
- Casting to one, two, or three decimal places changes zero values.
- One decimal place is therefore the minimum lossless scale.
- The maximum value of 100 requires three integer digits.

Decision:

- Convert `planned_pct_complete` directly to `DECIMAL(4, 1)`.
- Do not apply the percent-symbol normalization used for `actual_pct_complete`.
- Preserve the raw source values unchanged.

#### Planned-Versus-Actual Completion

Interpretation:
- Positive variance means actual progress is ahead of plan.
- Zero variance means actual progress equals plan.
- Negative variance means actual progress is behind plan.
After exact-duplicate removal:
- All 725 unique updates contain testable completion variances.
- Actual completion is ahead of plan in 61 updates.
- Actual completion equals plan in 105 updates.
- Actual completion is behind plan in 559 updates.
- The three categories reconcile to all 725 unique updates.
- Completion variance ranges from -32.7 through 39.6 percentage points.
- These counts describe update records, not distinct projects.
Decision:
- Perform planned-versus-actual comparisons only after exact-duplicate removal.
- Use standardized DECIMAL(4, 1) values for both percentage fields.
- Preserve the calculated variances while evaluating anomalous source values separately.
Completion-Variance Extremes
Investigation 54A dynamically retrieved every record tied at the minimum or maximum completion variance.
- UPD00313 for P040 is the only record at the maximum variance of 39.6 percentage points.
- The variance calculation is accurate, but the extreme result is driven by the previously identified actual_pct_complete value of 105.
- UPD00395 for P052 is the only record at the minimum variance of -32.7 percentage points.
- P052 contains six chronological updates from November 19, 2023, through April 6, 2024.
- Its actual completion progresses through 19.2, 34.2, 51.8, 66.4, 81.7, and 100.
- Actual completion never decreases or makes an implausible jump.
- Completion variance worsens from -5.6 to -32.7 before improving to -18.3 and finally 0.
- P052's forecast completion date moves progressively from March 3 through April 6, 2024.
- Every P052 update identifies Labor availability as the primary delay reason and Marcus Reed as the submitter.
Decision:
- Preserve UPD00313's value of 105 and flag it for stakeholder clarification.
- Do not cap or replace UPD00313 without authoritative evidence.
- Treat UPD00395's -32.7 percentage-point variance as legitimate behind-plan performance.
- Preserve UPD00395 without correction.
Chronological Actual-Completion Progression
Investigation 55 used LAG() partitioned by project_id and ordered by standardized report date to compare each update with the immediately preceding update for the same project.
- Fourteen updates across fourteen projects contain standardized actual completion lower than the preceding value.
- UPD00314 for P040 decreases from a preceding value of 105 to 77.2.
- The P040 decrease is consistent with the previously identified anomaly in UPD00313.
- The remaining thirteen decreases all occur on June 30, 2026, the reporting cutoff.
- Eight cutoff-date projects decrease from a preceding value of 100: P076, P077, P083, P084, P085, P090, P091, and P092.
- Raw and standardized actual-completion values match for every flagged record, so percentage conversion did not create the decreases.
- The records span multiple submitters and primary delay reasons.
- The returned row identifies where a decrease becomes visible but does not establish whether the current or preceding value is erroneous.
- The concentration on the reporting cutoff suggests a possible systematic reporting pattern requiring further investigation.
Decision:
- Treat chronological decreases as investigation flags rather than automatic
  errors.
- Preserve UPD00314 because its decrease is explained by the preceding,
  preserved P040 anomaly.
- Preserve the thirteen cutoff-date decreases pending the complete-history and
  project-timeline findings from Investigations 55A and 57.

#### Cutoff-Date Actual-Completion Histories

Investigation 55A dynamically identified the 13 projects whose standardized
actual completion decreased on June 30, 2026. Their complete histories contained
120 update records.

Eight projects decreased from a preceding actual-completion value of 100:

- P076: 100 → 91.2, a decrease of 8.8 percentage points.
- P077: 100 → 96.0, a decrease of 4.0 percentage points.
- P083: 100 → 93.2, a decrease of 6.8 percentage points.
- P084: 100 → 95.2, a decrease of 4.8 percentage points.
- P085: 100 → 87.7, a decrease of 12.3 percentage points.
- P090: 100 → 85.1, a decrease of 14.9 percentage points.
- P091: 100 → 90.1, a decrease of 9.9 percentage points.
- P092: 100 → 92.9, a decrease of 7.1 percentage points.

Five projects decreased before reaching 100:

- P078: 80.4 → 78.6, a decrease of 1.8 percentage points.
- P081: 74.8 → 70.7, a decrease of 4.1 percentage points.
- P082: 94.1 → 93.1, a decrease of 1.0 percentage point.
- P089: 18.6 → 12.7, a decrease of 5.9 percentage points.
- P094: 52.1 → 43.3, a decrease of 8.8 percentage points.

None of the thirteen histories contains an obvious isolated preceding spike
comparable to P040's likely erroneous 105% value.

P094 provides the strongest operational support for a possible reassessment
because its inspection / approval delay continued while its forecast completion
date moved later. The available records still do not confirm that the decrease
was an authorized correction.

The concentration of all thirteen decreases on the reporting cutoff across
multiple submitters and delay reasons suggests a systematic reassessment or
reporting anomaly rather than isolated entry mistakes.

Decision:

- Preserve all thirteen cutoff-date values without correction.
- Do not classify any decrease as a reversal caused by a confirmed earlier
  error.
- Flag the reporting-cutoff pattern for stakeholder clarification.
- Confirm whether actual completion may decrease because of inspections,
  punch-list items, rework, scope changes, or cutoff-period reassessments.

#### Chronological Planned-Completion Progression

Investigation 56 used `LAG()` partitioned by `project_id` and ordered by
standardized report date to compare each planned-completion value with its
immediately preceding value.

- The query returned zero rows.
- No standardized planned-completion value was below its preceding
  chronological value.
- Planned completion remained non-decreasing within every project, either
  increasing or remaining unchanged.
- The first update for each project was naturally excluded because `LAG()`
  returns NULL when no preceding update exists.
- No downward planned-completion revisions or unexplained chronological
  reversals were identified.

Decision:

- No corrections or additional investigation are required for
  planned-completion chronology.

#### Forecast-Before-Report Project-Timeline Comparison

Investigation 57 joined the 40 forecast-before-report updates to deduplicated
and standardized project records.

- The 40 updates span eight projects: P076, P077, P083, P084, P085, P090,
  P091, and P092.
- All 40 records contain planned completion of 100%.
- Every affected update was submitted after both its project's baseline
  completion date and its recorded forecast completion date.
- All eight projects remained officially classified as active.
- All eight projects had NULL actual completion dates.
- The official project records therefore do not support classifying the
  affected records as confirmed post-completion administrative updates.
- Several projects repeatedly reported 100% actual completion despite
  remaining active with no official actual completion date.
- These are the same eight projects that later decreased from 100% actual
  completion on June 30, 2026.
- The combined evidence indicates that their forecasts became stale and that
  100% actual completion may have been reported prematurely before a
  systematic cutoff-date reassessment.
- Reopened work caused by inspections, punch-list items, rework, or added scope
  remains a plausible alternative, but the data does not confirm that the
  projects were ever officially completed.

Decision:

- Preserve all source values without correction.
- Classify the 40 forecast-before-report records as stale or inconsistent
  forecasts rather than confirmed post-completion updates.
- Flag the eight projects for stakeholder clarification regarding the
  definition of 100% actual completion, official completion requirements, and
  the June 30 reassessment process.

#### Estimated Cost to Complete

Investigations 58–60 profiled `estimated_cost_to_complete` across the 725 unique
project updates.

- DuckDB infers `estimated_cost_to_complete` as `DOUBLE`.
- All 725 unique updates contain a populated value.
- Zero NULL values were identified.
- Values range from 0 through 2,695,267.50.
- Seventy-five values equal zero.
- Zero negative values were identified.
- All 75 zero-value updates represent distinct projects and report
  `actual_pct_complete` of 100%.
- The zero values are therefore internally consistent with completed work.
- Casting to zero decimal places changes 645 values.
- Casting to one decimal place changes 590 values.
- Casting to two or three decimal places changes zero values.
- Two decimal places are therefore the minimum lossless scale.
- `DECIMAL(9,2)` is the minimum type supporting the observed range and scale.

Decision:

- Use `DECIMAL(10,2)` for cleaned `estimated_cost_to_complete` to preserve all
  observed values, match the existing project monetary convention, and provide
  additional headroom.
- Preserve all 75 zero values without correction.
- No missing-value, negative-value, or range correction is required.
- Preserve the raw source values unchanged.

#### Chronological Estimated-Cost-to-Complete Progression

Investigation 61 used `LAG()` partitioned by `project_id` and ordered by
standardized report date to compare each ETC value with its immediately
preceding value.

- The 725 unique updates produced 628 consecutive comparisons across 97
  project-ID partitions.
- All 628 comparable ETC values decreased from their preceding values.
- Zero ETC increases were identified.
- Zero unchanged ETC values were identified.
- Each project partition's first update was excluded because no preceding ETC
  value exists.
- The 628 comparisons reconcile mathematically to 725 unique updates minus 97
  first-in-partition records.
- The unexpected 97th partition triggered project-ID relationship validation.

Decision:

- Treat ETC as strictly decreasing across every comparable project-update
  sequence.
- No ETC-specific chronological anomaly requires correction or follow-up.
- Investigate the unexpected project-ID partition separately rather than
  treating the comparison count as a query error.

#### Project-Update Project-ID Validation

Investigations 61A–61D validated the 97 distinct project-update IDs against the
96 authoritative IDs in `projects.csv`.

- P995 is the only project ID in `project_updates.csv` without a matching
  project record.
- The reverse anti-join returned zero authoritative projects without updates.
- All 96 authoritative project IDs are represented in `project_updates.csv`.
- P995 contains one update record: UPD99999.
- UPD99999 was reported on June 30, 2026.
- It records planned completion of 70.0%, actual completion of 51.0%, ETC of
  180,000.00, and forecast completion of October 15, 2026.
- Its primary delay reason is `Material lead time`, and `submitted_by` is
  `Unknown`.
- Because P995 has only one update, it provides no chronological history.
- P995 appears zero times in `projects.csv`, `project_budgets.csv`,
  `cost_transactions.csv`, `labor_entries.csv`, and `change_orders.csv`.
- UPD99999 has no exact business-field match among the other 724 unique project
  updates.
- No data-supported mapping to an authoritative project ID exists.

Decision:

- Classify P995 as an update-only orphan.
- Preserve the raw P995 value unchanged.
- Flag UPD99999 for stakeholder clarification.
- Do not assign a replacement project ID in cleaned outputs without new
  authoritative evidence.

#### Primary Delay Reason

Investigation 62 profiled `primary_delay_reason` across the 725 unique project
updates.

- Eight distinct raw labels were identified:
  - `Labor availability`: 211
  - `Material lead time`: 106
  - `Subcontractor availability`: 90
  - `Inspection / approval delay`: 80
  - `None`: 79
  - `Owner decision / change order`: 73
  - `Unforeseen site condition`: 63
  - `Weather`: 23
- The frequencies reconcile to all 725 unique updates.
- All eight labels use consistent sentence case.
- No apparent capitalization, spelling, or labeling variants require
  standardization.
- Investigation 62A classified the 79 updates labeled `None` by comparing
  standardized actual and planned completion:
  - 38 were ahead of schedule.
  - 7 were on schedule.
  - 34 were behind schedule.
- The three schedule categories reconcile to all 79 `None` updates.
- The 34 behind-schedule records disprove the hypothesis that `None`
  consistently means no active delay.
- The available data does not establish whether `None` means that no primary
  reason was identified, selected, or documented.

Decision:

- Preserve all eight raw delay-reason labels unchanged.
- Do not convert `None` to NULL or reinterpret it as “no delay.”
- Flag the business meaning of `None` for stakeholder clarification.

#### Submitted By

Investigations 63 and 63A profiled `submitted_by` across the 725 unique project
updates.

- Six distinct raw values were identified:
  - Elena Martinez: 181
  - Priya Shah: 174
  - Daniel Kim: 159
  - Marcus Reed: 115
  - Olivia Bennett: 95
  - `Unknown`: 1
- The frequencies reconcile to all 725 unique updates.
- The five employee names are consistently formatted.
- No apparent capitalization, spelling, or labeling variants require
  standardization.
- The only `Unknown` value belongs to UPD99999 for orphan project P995.
- UPD99999 was reported on June 30, 2026.
- The available data provides no authoritative evidence identifying the actual
  submitter or supporting assignment to one of the five named employees.

Decision:

- Preserve the five named submitter values unchanged.
- Preserve `Unknown` unchanged.
- Flag the submitter value with UPD99999 and P995 for stakeholder
  clarification.
- Do not infer or assign a replacement submitter without authoritative
  evidence.

#### Cleaning Implementation

#### Cleaning Implementation

Cleaning is complete in `sql/12_project_updates_cleaned.sql`.
The reusable view construction.cleaned_project_updates is saved
and verified at 725 rows and 725 distinct update IDs.

Implemented transformations:

- Remove exact duplicate rows and preserve raw columns.
- Convert report_date to DATE with the validated M/D/YYYY fallback.
- Convert forecast_completion_date to DATE and flag missing forecasts.
- Remove percentage symbols from actual_pct_complete and convert both
  percentage fields to DECIMAL(4,1).
- Preserve actual percentages outside 0–100 and flag them.
- Convert estimated_cost_to_complete to DECIMAL(10,2).
- Use LAG() to retrieve previous actual completion by project,
  ordered by cleaned report date.
- LEFT JOIN to cleaned_projects to preserve and flag unmatched updates.
- Add unknown-submitter, progress-decrease, and forecast-before-report flags.

Earlier individual checks confirmed zero populated values failed
conversion, UPD00664 retains its missing forecast, and UPD00313
retains actual completion of 105.0 with its out-of-range flag.

Confirmed September 22 results:

- Combined output: 725 rows and 725 distinct update IDs.
- Missing-forecast flags: 1.
- Out-of-range-percentage flags: 1.
- Unmatched-project flags: 1.
- Unknown-submitter flags: 1.
- Progress-decrease flags: 14.
- Forecast-before-report flags: 40.
- UPD99999/P995/Unknown receives both the unmatched-project and
  unknown-submitter flags.
- Cleaned column types match the intended DATE, DECIMAL, and BOOLEAN types.
- Zero recorded-zero preservation violations were returned across
  actual completion, planned completion, and ETC.
- Deduplicated-source and cleaned ETC totals match; difference = 0.00.
- Saved-view verification: 725 rows and 725 distinct update IDs.

Progress decreases compare current actual completion with previous
actual completion, not planned completion. The comparison is designed
to remain NULL when no previous update exists. Forecast comparisons
remain NULL when the forecast is missing.

Raw project IDs, delay-reason labels, and submitter values remain
unchanged, including P995, None, and Unknown.

Separate combined-output checks for project/date uniqueness and
comparison-flag NULL behavior were not reported during this session.


### Change Orders

Planned standalone and relationship profiling is complete through
Investigation 89. Individual queries executed successfully and their
results were reviewed. The full file was not rerun during September 7
closeout.

#### Structure and Project References

- The source contains 146 raw rows, 12 columns, and 145 distinct change-order IDs.
- CO0013 occurs twice as an exact duplicate across all 12 columns.
- Retaining one occurrence produces an expected 145 cleaned rows.
- All raw project IDs are populated, with 69 distinct values.
- P994, associated with pending additive change order CO9999, has no matching
  authoritative project and no supporting records in the other five datasets.

Cleaning decisions:

- Remove one exact CO0013 occurrence only in cleaned output.
- Preserve CO9999 and P994 and flag the orphan for stakeholder clarification.
- Do not assign an unsupported replacement project ID.
- Preserve raw source data unchanged.

#### Categories and Monetary Types

- change_order_type and reason require no standardization.
- LOWER(TRIM(status)) produces approved, withdrawn, pending, and rejected
  counts of 103, 16, 14, and 13 respectively.
- Remove dollar signs and commas from requested_revenue_change before casting.
- All four monetary fields will use DECIMAL(10,2).
- Two decimal places preserve every observed populated monetary value.

| Monetary field | Populated | NULL | Zero | Negative | Minimum | Maximum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| requested_revenue_change | 146 | 0 | 0 | 12 | -180,146.05 | 201,500.62 |
| estimated_cost_change | 146 | 0 | 0 | 12 | -122,322.75 | 124,992.57 |
| approved_revenue_change | 103 | 43 | 0 | 10 | -177,978.63 | 158,368.20 |
| billed_amount | 103 | 43 | 24 | 8 | -133,652.67 | 158,368.20 |

#### Dates, Approval Workflow, and Signs

- No testable workflow dates violate request-to-approval, request-to-billing,
  or approval-to-billing chronology.
- All 103 approved rows contain approved revenue.
- The 43 non-approved rows contain no approval fields or billing evidence.
- CO0001 is the only approved row with a missing approval_date.
- Preserve CO0001's NULL approval date and flag it; do not infer a date.
- Requested revenue, estimated cost, approved revenue, and nonzero billed
  amounts have signs consistent with change_order_type.
- No monetary sign corrections are required.

#### Billing-Date Consistency

Investigation 87 evaluated all 146 raw rows and found:

- 0 nonzero billed amounts with NULL billed dates.
- 0 populated billed dates with NULL billed amounts.
- 0 populated billed dates with zero billed amounts.

Every nonzero billed amount has a populated billed date. Zero and NULL billed
amounts have NULL billed dates. No correction is required for these relationships.

#### Requested Versus Approved Revenue

Investigation 88 identified 103 rows with both amounts populated:

- All 93 additive rows have requested revenue greater than approved revenue.
- All 10 deductive rows have requested revenue numerically less than approved
  revenue, representing smaller approved deductions.
- No comparable row has equal requested and approved amounts.
- All 103 approved changes are smaller in magnitude than requested.
- The remaining 43 rows have NULL approved revenue.

Preserve these differences as business observations. Negotiation is a possible
explanation, but the data does not establish why the amounts changed.

#### Approved Versus Billed Amounts

Investigation 89 classified standardized approved rows using exact monetary
values and absolute magnitudes for partial and potentially excessive billing.

| Type | Approved rows | Unbilled | Partially billed | Fully billed | Potentially overbilled |
| --- | ---: | ---: | ---: | ---: | ---: |
| Additive | 93 | 22 | 20 | 51 | 0 |
| Deductive | 10 | 2 | 2 | 6 | 0 |
| Total | 103 | 24 | 22 | 57 | 0 |

- No approved rows have missing approved revenue or billed amounts.
- The four billing categories reconcile to all 103 approved rows.
- Zero billed amounts are unbilled and excluded from partially billed counts.
- Preserve partial billing as a business observation, not a data error.
- Preserve NULL billed amounts separately from recorded zeros.
- These are raw-row profiling results and include the known CO0013 duplicate.
- These classifications describe billing as recorded, not billing as of cutoff.

#### Reporting-Cutoff Treatment

CO0119 for P077 is the only change order billed after June 30, 2026:

- Requested date: May 11, 2026.
- Approval date: June 21, 2026.
- Billed date: July 9, 2026.
- Approved revenue and billed amount: -36,633.22 each.

Retain its approved change in the June 30 analysis, but exclude its post-cutoff
billed amount from June 30 billed totals. Implement this through a derived
calculation while preserving the source amount and date.

No planned change-order profiling checks remain.

#### Cleaning Implementation

Cleaning is complete in `sql/13_change_orders_cleaned.sql`.
The reusable view construction.cleaned_change_orders is saved
and verified at 145 rows and 145 distinct change-order IDs.

Implemented transformations:

- Remove exact duplicates, retaining one CO0013 record.
- Preserve raw columns alongside cleaned values and exception flags.
- Standardize status using LOWER(TRIM(status)).
- Remove dollar signs and commas from requested_revenue_change
  before numeric conversion.
- Convert all four monetary fields to DECIMAL(10,2).
- Retain the three date fields, already inferred as DATE.
- Preserve change_order_type, reason, negative amounts, zeros, and NULLs.
- LEFT JOIN to cleaned_projects and flag unmatched project IDs.
- Flag approved change orders with missing approval dates.

Validation results:

- Validation 1: 145 rows and 145 distinct change-order IDs.
- Validation 2: zero populated monetary values failed conversion;
  one unmatched-project flag and one missing-approval-date flag.
- Validation 3: CO9999/P994 has only the unmatched-project flag;
  CO0001/P001 retains approval_date NULL and has only the
  approved_missing_approval_date_flag.
- Validation 4: raw status variants map correctly to approved,
  pending, withdrawn, and rejected.
- Cleaned status counts: approved 102, pending 14, withdrawn 16,
  rejected 13; total 145.
- Validation 5: all four cleaned monetary fields are DECIMAL(10,2),
  status_clean is VARCHAR, and both flags are BOOLEAN.
- Validation 6: all four monetary totals reconcile to the
  deduplicated source with differences of 0.00.
- Validation 7: zero source-NULL or recorded-zero preservation violations.

Reconciled source and cleaned totals:

| Monetary field | Total |
| --- | ---: |
| requested_revenue_change | 6974614.34 |
| estimated_cost_change | 4949215.55 |
| approved_revenue_change | 4481858.73 |
| billed_amount | 3129442.88 |

The preceding profiling results describe 146 raw rows, including
the duplicate. Cleaned results describe 145 rows.

CO0119's billed amount and post-cutoff billing date remain unchanged.
The billed total above includes that record and is not a June 30
cutoff-based billed total.

Saved-view verification passed: 145 rows and 145 distinct change-order IDs.

## Unresolved Items

This is a fictional case study. Stakeholder-clarification items below
represent limitations and information requests that would apply in a
real engagement; they are not blockers requiring a fictional response.
Preserve unresolved source exceptions. Where necessary, use explicitly
documented modeling assumptions without presenting them as source facts.

### Projects

* Confirm P013's intended baseline date format.
* Preserve P052's missing `project_type` as unknown unless authoritative
  evidence becomes available.

### Project Budgets

* Obtain stakeholder clarification for orphan budget BUD-P997-01,
  which references unmatched project ID P997.
* Preserve BUD-P057-04's original-budget NULL unless a stakeholder confirms the
  formula-derived candidate.
* Confirm whether the supplied revised budgets were valid as of June 30,
  2026. The source has no effective dates or version history; retain
  this reporting limitation until authoritative confirmation is available.

### Labor Entries


* Obtain stakeholder clarification for TE001216's unresolved `General Labor`
  value.
* Obtain stakeholder clarification for TE003191's unexplained 125.00
  labor-cost difference.
* Obtain stakeholder clarification regarding the reporting period represented
  by `work_date` and the applicable regular and overtime rules.

### Project Updates

- Obtain stakeholder clarification for UPD00664's missing forecast date.
- Obtain stakeholder clarification for UPD00313's preserved
  actual-completion value of 105.
- Confirm the business definition of `actual_pct_complete` and whether it may
  decrease because of inspections, punch-list items, rework, scope changes, or
  cutoff-period reassessments.
- Clarify why thirteen projects received actual-completion decreases on the
  June 30 reporting cutoff.
- Clarify why P076, P077, P083, P084, P085, P090, P091, and P092 repeatedly
  reported 100% actual completion while remaining active with no official
  actual completion date.
- Clarify the operational meaning and intended use of the `None`
  `primary_delay_reason` category.
- Obtain stakeholder clarification for orphan update UPD99999, unmatched
  project ID P995, and the associated `Unknown` submitter value.

### Change Orders

- Obtain stakeholder clarification for orphan change order CO9999 and P994.
- Obtain stakeholder clarification for CO0001's missing approval_date;
  preserve the NULL and flag it in cleaned output.
- Implement CO0119's reporting-cutoff treatment in the analytical layer.

#### Cleaning Implementation

- All six cleaned views have been created and their row/key counts verified.
- Separate combined-output checks for project-update project/date
  uniqueness and comparison-flag NULL behavior were not reported
  during September 22.
- Investigate additional source issues only when implementation or
  analysis reveals a specific material concern.

### Analytical Reporting

- Build one row per authoritative project as of June 30, 2026.
  Retain all projects, with active projects prioritized for review.
- Include eligible non-payroll transaction costs and employee labor
  costs once, consistent with the client handoff.
- Use supplied revised budgets without adding approved change-order
  estimated costs again, based on the completed reconciliation.
- Retain the budget effective-date limitation. The reconciliation
  does not establish June 30 budget validity.
- Keep P997's orphan budget visible and separately accounted for.
  Current supplied revised-budget totals include its 42000.00.
- June 30 updates with populated ETC were confirmed for all 18 active
  projects. No project has multiple updates on that date.
- Add the exact-cutoff update selection to the analytical query.
  Preserve projects without cutoff updates and retain missing ETC
  as NULL, not zero.
- Define update selection and forecast treatment for other projects
  before extending forecast analysis beyond active projects.
  Do not automatically combine older ETC with cutoff incurred costs.
- Apply and disclose the analysis plan's case-study assumptions.
  ETC-based forecast calculations have not yet been implemented.
- For forecast metrics, assume ETC includes all remaining project
  costs, including labor, and excludes already-incurred costs at
  the update date.
- Do not automatically combine stale ETC with cutoff incurred costs.
  Preserve update dates and flag unavailable or stale forecasts.
- Treat supplied project status as cutoff status because status
  history is unavailable; review apparent conflicts.
- Keep CO0001's undated approved revenue change separate from
  confirmed cutoff-approved revenue adjustments.
- Apply CO0119's post-cutoff billing exclusion to cutoff-based
  billed totals.
- Preserve exceptions affecting progress, baseline dates, and
  forecasts. Retain projects even when individual metrics cannot
  be calculated reliably.
- Disclose the absence of dedicated commitment and accrual records.
  Pending transactions do not substitute for those records.
- Keep budget remaining distinct from ETC. Show pending exposure
  separately from incurred costs and budget remaining.
- Defer the existing budget-versus-actual SQL, CSV, and Excel
  correction until project closeout. Preserve valid exception notes
  and update the report's cost coverage and limitations then.

## Remaining Project Work

1. Continue sql/15_project_analytical_layer.sql. Cost and revised-budget
   summaries are joined; next add cutoff ETC, forecast calculations,
   project status, schedule metrics, eligible change-order revenue,
   and relevant exception flags.
2. Validate grain, source-to-output totals, cutoff treatment,
   orphan accounting, and exception handling during implementation.
3. Investigate active-project priorities, contributing factors,
   and recurring patterns across projects.
4. Develop focused Power BI visuals and an executive summary with
   evidence-backed findings, recommendations, and limitations.
5. At closeout, correct the existing budget-versus-actual SQL report
   to include employee labor and refresh its CSV and Excel outputs.
6. Complete final QA, repository documentation, and portfolio publication.

## Exact Next Task

Continue in sql/15_project_analytical_layer.sql after Step 7.

Completed prerequisites:

- Final reconciliation file saved and run: 0 nonzero differences and
  38 unmatched projects with zero budget adjustments.
- Analysis plan saved at docs/analysis_plan.md.
- Cost and revised-budget summaries joined to authoritative projects.
- June 30 ETC coverage confirmed for all 18 active projects.
- June 30 duplicate-update check returned 0 rows.

Next steps:

1. Put the Step 7 June 30 update selection into a cutoff_updates CTE.
2. LEFT JOIN cutoff_updates to cleaned_projects by project ID.
3. Select report_date_clean and estimated_cost_to_complete_clean.
4. Keep the duplicate-update check as a separate validation query.
5. Confirm the join retains 96 authoritative project rows and preserves
   the established ETC coverage for all 18 active projects.
6. Then attempt forecast final cost and comparison with revised budget.
   Preserve missing ETC as NULL; do not substitute zero.

Write a comment and make the first SQL attempt before receiving a
complete solution.

Keep the existing budget-versus-actual correction deferred until
project closeout. Do not restart the resolved labor-overlap inquiry
or repeat completed profiling without a specific material concern.


Reconnect to construction.duckdb in VS Code if required:

ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;

Continue in coaching mode:

- User explains the approach and makes the first attempt.
- Comments and documentation come before SQL.
- Give graduated hints before complete solutions.
- Pause when the user cannot explain a concept.
- Batch familiar transformations and validations.
- Provide documentation text with exact insertion or replacement locations.

### Git Status

September 21–24 work has not yet been confirmed committed or pushed.

Expected files for review and staging:

- sql/12_project_updates_cleaned.sql.
- sql/13_change_orders_cleaned.sql.
- sql/14_change_order_budget_reconciliation.sql.
- sql/15_project_analytical_layer.sql.
- docs/analysis_plan.md.
- docs/project_notes.md.
- docs/project_status.md.

The reconciliation file is confirmed saved and executed, and the
analysis plan is confirmed placed in docs/.
Confirm the current analytical-layer SQL and documentation edits
are saved before staging.

If the abandoned sql/14_labor_cost_reconciliation.sql still exists,
review and remove it if it contains only the superseded investigation.

Inspect git status and the diff to confirm the actual changed-file list.
Review and stage intended changes, commit, and push.

Suggested commit message:
Complete cleaning and reconciliation; begin project analytical layer

Confirm the resulting commit, remote synchronization, and working-tree
status before recording Git closeout as complete.

## End-of-Session Update Routine

At the end of each work session:

1. Update the current phase and dataset-status sections.
2. Add newly confirmed findings and cleaning rules.
3. Remove resolved items and add newly identified unresolved items.
4. Update the remaining-work list if project scope or sequencing changes.
5. Replace the exact next task.
6. Record the latest analysis commit.
7. Add a dated entry to `docs/project_notes.md`.

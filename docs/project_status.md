# Project Status

Last updated: August 18, 2026

## Current Phase

Raw-data profiling is in progress.

First-pass standalone profiling is complete for:

* `projects.csv`
* `project_budgets.csv`
* `cost_transactions.csv`
* `labor_entries.csv`

Labor timeline profiling and the employee-date grain and overtime
interpretability investigations are complete.

Profiling of `project_updates.csv` has been executed through Investigation 49A.
The standardized business grain has been confirmed, the forecast-completion
date type and within-file date relationships have been profiled, and the
`actual_pct_complete` formatting issue and numeric range have been investigated.

Investigation 49A identified UPD00313 for project P040 as the only update with
an `actual_pct_complete` value above 100. Investigation 49B is the next task and
will inspect P040's update progression before any correction or final
classification is made.

`change_orders.csv` has not yet been profiled.

No cleaned analytical outputs have been implemented.

## Profiling File Structure

Profiling SQL is organized into separate dataset-specific files:

| Dataset                 | SQL file                                      | Status                                                           |
| ----------------------- | --------------------------------------------- | ---------------------------------------------------------------- |
| `projects.csv`          | `sql/01_projects_profiling.sql`               | Standalone profiling complete                                    |
| `project_budgets.csv`   | `sql/02_project_budgets_profiling.sql`        | Standalone profiling complete                                    |
| `cost_transactions.csv` | `sql/03_cost_transactions_profiling.sql`      | Standalone and required relationship profiling complete          |
| `labor_entries.csv`     | `sql/04_labor_entries_profiling.sql`          | Standalone profiling complete through Investigation 40A          |
| `project_updates.csv`   | `sql/05_project_updates_profiling.sql`        | In progress through Investigation 49A; Investigation 49B is next |
| `change_orders.csv`     | Planned: `sql/06_change_orders_profiling.sql` | Not started                                                      |

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
* Normalize project statuses through explicit documented mappings.
* Normalize P066's original contract value to `672000.00`.
* Preserve P013's raw date and exclude it from calculations requiring a
  confirmed baseline completion date.
* Treat P052's `project_type` as unknown unless authoritative evidence becomes
  available.

### Project Budgets

Standalone profiling is complete.

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

Confirmed cleaning rules:

* Retain one BUD-P031-01 row in cleaned output.
* Apply the following category mappings:

  * `General conditions` → `General Conditions`
  * `Materials ` → `Materials`
  * `labor` → `Labor`
  * `Sub-Contractors` → `Subcontractors`
* Remove `$` and `,` from `approved_budget_change` before numeric conversion.
* Convert cleaned monetary fields to `DECIMAL(10, 2)`.
* Preserve BUD-P057-04's source NULL.
* If the formula-derived 31,672.00 candidate is used, expose it separately and
  flag it as inferred.

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

Payment-status results after standardization:

* `paid`: 8,586 transactions totaling $67,763,269.51
* `approved`: 1,635 transactions totaling $12,725,390.85
* `pending`: 980 transactions totaling $7,961,647.60
* `applied`: 3 transactions totaling -$5,400.00

Reporting treatment:

* Paid and approved transactions form incurred cost.
* Applied credits remain negative and reduce incurred cost.
* Net incurred cost is $80,483,260.36.
* Pending transactions are reported separately as $7,961,647.60 of pending
  cost exposure.
* Maximum cost exposure is incurred cost plus pending cost exposure:
  $88,444,907.96.
* No approval probability will be assigned to pending transactions.

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
* Preserve negative applied credits.

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
* Select final DECIMAL widths during cleaned-schema implementation.
* Impute TE001843's hourly rate as 38.96 and flag it as formula-derived.
* Standardize `carpenter ` to `Carpenter`.
* Preserve TE001216's `General Labor` value and flag it as unresolved.
* Assign P003 specifically to TE000408 in cleaned output.
* Preserve TE000408's raw P996 value and flag the correction.
* Preserve post-baseline labor as schedule-variance evidence.
* Do not reclassify regular or overtime hours without a confirmed reporting
  period and authoritative overtime rule.
* Preserve raw source values unchanged.

### Project Updates

Profiling has been executed through Investigation 49A. Investigation 49B is the
next task.

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

* DuckDB infers `actual_pct_complete` as `VARCHAR`.
* All 726 rows contain populated `actual_pct_complete` values.
* A total of 725 values convert directly to `DECIMAL(10,4)`.
* One populated value fails direct numeric conversion.
* The failed value belongs to UPD00164 for project P022 and is stored as
  `89.7%`.
* The percent symbol explains the direct conversion failure and the raw
  `VARCHAR` inference.
* Exactly one raw value contains a percent symbol.
* Removing percent symbols allows all 726 values to convert successfully to
  `DECIMAL(10,4)`, leaving zero conversion failures.
* UPD00164 standardizes from `89.7%` to `89.7`, which preserves the dataset's
  apparent 0-to-100 percentage scale.
* Standardized `actual_pct_complete` values range from 7.5 through 105.
* Zero standardized values are below 0.
* Zero standardized values are equal to 0.
* One standardized value exceeds 100.
* A total of 108 standardized values are equal to 100.

Decision:

* Remove percent symbols before converting `actual_pct_complete` in the cleaned
  analytical layer.
* Preserve UPD00164's numeric meaning and standardize `89.7%` to `89.7`.
* Preserve the raw source value unchanged.
* Treat `DECIMAL(10,4)` as a diagnostic conversion type rather than the final
  cleaned type.
* Select the final cleaned DECIMAL precision and scale after completing the
  pending precision tests.

#### Above-Range Actual Completion Percentage

* UPD00313 for project P040 contains the only standardized
  `actual_pct_complete` value above 100.
* UPD00313 was reported on July 10, 2024.
* Its forecast completion date is September 27, 2024.
* It records `planned_pct_complete` of 65.4 and `actual_pct_complete` of 105.
* The actual percentage exceeds the expected 100% maximum.
* It also exceeds the planned percentage by 39.6 percentage points.
* Its primary delay reason is `Labor availability`.
* The surrounding fields increase suspicion that 105 is erroneous, but they do
  not establish the intended replacement value.

Decision:

* Do not cap, replace, or otherwise correct UPD00313's value without additional
  evidence.
* Inspect P040's complete update progression in Investigation 49B.
* Preserve and flag the value if the neighboring records do not support a
  defensible correction.

## Unresolved Items

### Projects

* Confirm P013's intended baseline date format.
* Preserve P052's missing `project_type` as unknown unless authoritative
  evidence becomes available.

### Project Budgets

* Compare the 97 distinct budget project IDs with the 96 distinct project IDs
  in `projects.csv`.
* Preserve BUD-P057-04's original-budget NULL unless a stakeholder confirms the
  formula-derived candidate.

### Labor Entries

* Determine total DECIMAL precision when the cleaned labor schema is
  implemented.
* Obtain stakeholder clarification for TE001216's unresolved `General Labor`
  value.
* Obtain stakeholder clarification for TE003191's unexplained 125.00
  labor-cost difference.
* Obtain stakeholder clarification regarding the reporting period represented
  by `work_date` and the applicable regular and overtime rules.

### Project Updates

* Obtain stakeholder clarification for UPD00664's missing forecast date.
* Complete Investigation 49B by inspecting P040's update progression and
  determine whether UPD00313's `actual_pct_complete` value of 105 can be
  corrected defensibly or must remain preserved and flagged.
* Complete standardized `actual_pct_complete` precision testing and select its
  final cleaned DECIMAL type.
* Profile `planned_pct_complete` scale, range, precision, and numeric type.
* Validate planned-versus-actual completion relationships and chronological
  percentage progression.
* Compare the 40 forecast-before-report records with project status, baseline
  completion, and actual completion dates.
* Profile `estimated_cost_to_complete` range, precision, and relationship with
  project progress.
* Profile `primary_delay_reason` and `submitted_by` values.
* Validate project-update project IDs against `projects.csv`.

### Remaining Datasets and Relationships

* Profile `change_orders.csv`.
* Validate the remaining required relationships between supplied files.

## Remaining Project Work

1. Complete standalone profiling of `project_updates.csv`.
2. Profile `change_orders.csv`.
3. Compare project IDs in `project_budgets.csv` with `projects.csv`.
4. Validate remaining cross-file relationships.
5. Implement documented cleaning rules in cleaned analytical outputs.
6. Build project profitability and budget-variance metrics.
7. Build schedule-risk metrics.
8. Create final analytical tables and stakeholder-facing outputs.
9. Validate and document the completed analysis.

## Exact Next Task

Open `sql/05_project_updates_profiling.sql`.

Begin Investigation 49B by writing its purpose comment. Do not write the SQL
query until the purpose comment has been reviewed.

Retrieve every project-update record for P040 and order the results by
standardized `report_date`. Include:

* `update_id`
* `project_id`
* standardized `report_date`
* standardized `forecast_completion_date`
* `planned_pct_complete`
* raw `actual_pct_complete`
* standardized `actual_pct_complete`
* `primary_delay_reason`

Use the chronological progression to determine whether UPD00313's
`actual_pct_complete` value of 105 is an isolated anomaly and whether the
neighboring records support a defensible correction.

Do not cap or replace the value through assumption. If the intended value cannot
be supported by evidence, preserve 105 and flag UPD00313 for stakeholder
clarification.

After Investigation 49B, continue percentage-precision testing to determine the
minimum decimal scale required for the cleaned `actual_pct_complete` type.

The latest committed analysis is:

- Commit:
  [f5512680c766ee1e6d3d96dbc044aeece0d1d76a](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/f5512680c766ee1e6d3d96dbc044aeece0d1d76a)
- Message: `Profile project update forecasts and percentages`
- Date: August 18, 2026

The latest correction commit is:

* Commit:
  [52a08ac4164bd7279d95e0ea6c91229d229c44ef](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/52a08ac4164bd7279d95e0ea6c91229d229c44ef)
* Message: `Fix budget normalization query`
* Date: July 31, 2026

## End-of-Session Update Routine

At the end of each work session:

1. Update the current phase and dataset-status sections.
2. Add newly confirmed findings and cleaning rules.
3. Remove resolved items and add newly identified unresolved items.
4. Update the remaining-work list if project scope or sequencing changes.
5. Replace the exact next task.
6. Record the latest analysis commit.
7. Add a dated entry to `docs/project_notes.md`.

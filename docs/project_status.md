# Project Status

Last updated: August 13, 2026

## Current Phase

Raw-data profiling is in progress.

First-pass standalone profiling is complete for:

- `projects.csv`
- `project_budgets.csv`
- `cost_transactions.csv`

Profiling of `labor_entries.csv` is complete through Investigation 38B.
Trade-history analysis, employee-ID profiling, and labor-to-project relationship
validation are complete.

Investigations 39 and 39A produced initial labor-timeline results, but those
results require revalidation because their `labor_dates` CTE omitted the
previously established `M/D/YYYY` fallback for TE002542.

Investigation 40 has begun but has not been executed. It will determine the
labor-entry grain and whether regular and overtime classification can be
evaluated from the available fields.

`project_updates.csv` and `change_orders.csv` have not yet been profiled.

No cleaned analytical outputs have been implemented.

## Profiling File Structure

Profiling SQL is organized into separate dataset-specific files:

| Dataset | SQL file | Status |
|---|---|---|
| `projects.csv` | `sql/01_projects_profiling.sql` | Standalone profiling complete |
| `project_budgets.csv` | `sql/02_project_budgets_profiling.sql` | Standalone profiling complete |
| `cost_transactions.csv` | `sql/03_cost_transactions_profiling.sql` | Standalone and required relationship profiling complete |
| `labor_entries.csv` | `sql/04_labor_entries_profiling.sql` | Complete through Investigation 38B; timeline results require revalidation |
| `project_updates.csv` | Planned: `sql/05_project_updates_profiling.sql` | Not started |
| `change_orders.csv` | Planned: `sql/06_change_orders_profiling.sql` | Not started |

The superseded combined `sql/01_data_profiling.sql` file has been removed.
Existing investigation numbers and documentation references were preserved
during the reorganization.

## Reporting Cutoff

The reporting cutoff is June 30, 2026, inclusive.

- Actual activity dated on or before the cutoff belongs in cutoff-based
  analysis.
- Actual activity after the cutoff remains in the raw data but will be excluded
  from cutoff-based calculations.
- Future planned and forecast dates remain because they support schedule-risk
  analysis.

## Dataset Status

### Projects

Standalone profiling is complete.

Key results:

- `projects.csv` contains 97 raw rows and 96 distinct project IDs.
- P042 is an exact duplicate.
- P052 is the only project with a missing `project_type`.
- Six raw project-status labels represent three logical categories: active,
  completed, and on hold.
- P013 contains the ambiguous baseline completion date `8/10/2023`.
- P066 contains the formatted original contract value `$672,000`.
- No actual completion date occurs before its corresponding actual start date.
- No actual activity occurs after the reporting cutoff.
- Safely parsed baseline completion dates extend through December 18, 2026.
  Future baseline dates remain valid for schedule-risk analysis.
- Normalized original contract values range from $276,000 to $3,773,000.
- Original budgets range from $223,600 to $2,917,000.
- No original budget exceeds its normalized original contract value.

Confirmed cleaning rules:

- Retain one P042 row in cleaned output.
- Normalize project statuses through explicit documented mappings.
- Normalize P066's original contract value to `672000.00`.
- Preserve P013's raw date and exclude it from calculations requiring a
  confirmed baseline completion date.
- Treat P052's `project_type` as unknown unless authoritative evidence becomes
  available.

### Project Budgets

Standalone profiling is complete.

Key results:

- `project_budgets.csv` contains 674 rows, 673 distinct `budget_line_id`
  values, 97 distinct project IDs, and 673 distinct project/category pairs.
- BUD-P031-01 appears twice, and the two records are exact duplicates.
- BUD-P057-04 is the only row with a missing `original_budget_amount`.
- BUD-P057-04 has an approved change of 0 and a revised budget of 31,672.00.
- The formula-derived candidate original budget for BUD-P057-04 is 31,672.00,
  but the value is not source-confirmed.
- Eleven raw `cost_category` values represent seven canonical categories.
- `$3,485.49` is the only approved-budget-change value that fails direct
  numeric conversion.
- Removing `$` and `,` allows every populated approved change to parse.
- Revised budgets range from 6,957.72 to 886,036.18.
- Two-decimal scale preserves every observed revised budget.
- Of 674 rows, 673 satisfy the expected monetary relationship and one is
  untestable because of the missing original budget.
- `DECIMAL(10, 2)` was selected for cleaned monetary fields.

Confirmed cleaning rules:

- Retain one BUD-P031-01 row in cleaned output.
- Apply the following category mappings:
  - `General conditions` → `General Conditions`
  - `Materials ` → `Materials`
  - `labor` → `Labor`
  - `Sub-Contractors` → `Subcontractors`
- Remove `$` and `,` from `approved_budget_change` before numeric conversion.
- Convert cleaned monetary fields to `DECIMAL(10, 2)`.
- Preserve BUD-P057-04's source NULL.
- If the formula-derived 31,672.00 candidate is used, expose it separately and
  flag it as inferred.

### Cost Transactions

Standalone and required transaction-relationship profiling is complete.

Key results:

- `cost_transactions.csv` contains 11,204 rows and 11,203 distinct
  `transaction_id` values.
- TX000138 occurs twice, and the two records are exact duplicates.
- Retaining both TX000138 records would overstate P002's Materials cost by
  14,821.14.
- TX000316 is the only transaction with a missing `project_id`.
- Transaction-order evidence supports assigning TX000316 to P003.
- TX000729 is the only transaction assigned to P998.
- P998 does not exist in `projects.csv` or `project_budgets.csv`.
- Transaction context supports assigning TX000729 to P007.
- `$46.90` is the only amount that fails direct numeric conversion.
- Removing `$` and `,` allows all 11,204 amount values to parse.
- Normalized amounts range from -1,800.00 to 83,246.69.
- Two-decimal scale preserves every observed amount.
- `DECIMAL(10, 2)` was selected for the cleaned amount field.
- Three negative transactions are valid returned-material credits of
  -1,800.00 each.
- Transaction dates range from January 28, 2023, through June 30, 2026.
- No transaction occurs after the reporting cutoff.
- P998 is the only unmatched non-NULL transaction project ID.
- Six raw transaction project/category pairs initially failed budget matching.
- All six mismatches are explained by documented project-ID or category
  inconsistencies.
- After applying documented corrections, zero transaction project/category
  pairs remain unmatched.

Payment-status results after standardization:

- `paid`: 8,586 transactions totaling $67,763,269.51
- `approved`: 1,635 transactions totaling $12,725,390.85
- `pending`: 980 transactions totaling $7,961,647.60
- `applied`: 3 transactions totaling -$5,400.00

Reporting treatment:

- Paid and approved transactions form incurred cost.
- Applied credits remain negative and reduce incurred cost.
- Net incurred cost is $80,483,260.36.
- Pending transactions are reported separately as $7,961,647.60 of pending
  cost exposure.
- Maximum cost exposure is incurred cost plus pending cost exposure:
  $88,444,907.96.
- No approval probability will be assigned to pending transactions.

Confirmed cleaning rules:

- Retain one TX000138 record.
- Assign P003 specifically to TX000316.
- Assign P007 specifically to TX000729.
- Remove `$` and `,` from amount values before conversion to
  `DECIMAL(10, 2)`.
- Apply the following category mappings:
  - `Sub-Contractor` → `Subcontractors`
  - `materials ` → `Materials`
- Standardize payment statuses with `LOWER(TRIM(payment_status))`.
- Preserve negative applied credits.

### Labor Entries

Profiling is complete through Investigation 38B. Investigations 39 and 39A
require date-parsing revalidation, and Investigation 40 is in progress.

#### Structure and Completeness

- `labor_entries.csv` contains 18,004 raw rows and nine columns.
- The apparent grain is one labor entry for one employee on one project and work
  date.
- The file contains 18,004 non-NULL `time_entry_id` values and 18,003 distinct
  identifiers.
- TE000222 occurs twice, and the two records are exact duplicates.
- After duplicate removal, the expected cleaned row count and distinct
  identifier count are both 18,003.
- All text columns are complete.
- `hourly_rate` is the only column containing a NULL value.

#### Work Dates

- All 18,004 `work_date` values are populated.
- A total of 18,003 values parse directly as DATE.
- TE002542 contains the only direct parsing failure: `5/19/2023`.
- The value unambiguously represents May 19, 2023.
- Standard parsing followed by an `M/D/YYYY` fallback converts all 18,004
  values successfully.
- Standardized dates range from January 28, 2023, through June 30, 2026.
- No labor entry occurs after the reporting cutoff.

#### Numeric Fields

- `regular_hours` ranges from 0.0973 to 46, with no zero or negative values.
- `overtime_hours` ranges from 0 to 9, with 14,033 zero values and no negative
  values.
- Non-NULL `hourly_rate` values range from 27 to 68, with no zero or negative
  values.
- `labor_cost` ranges from 5.80 to 3,822.02, with no zero or negative values.
- Four entries contain the maximum of 46 regular hours, and all four record zero
  overtime.
- A total of 6,727 entries record more than 40 regular hours.
- Of those entries, 5,178, or 76.97%, record zero overtime.
- The dataset does not establish the time period represented by a labor entry
  or the business rules governing regular and overtime classification.
- Four decimal places are required to preserve every `regular_hours` value.
- Two decimal places preserve every non-NULL `overtime_hours`, `hourly_rate`,
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

- The formula is testable for 18,003 rows.
- It matches 17,850 rows, or 99.15%.
- It mismatches 153 rows, or 0.85%.
- Of the 153 mismatches, 152 recorded labor costs are 0.01 below the calculated
  value.
- TE003191 is the only material exception.
- TE003191 records labor cost of 1,530.88 compared with an expected 1,405.88,
  producing an unexplained difference of 125.00.

Formula-overlap results:

- 16,948 rows match both formulas.
- 902 rows match combined-total only.
- 9 rows match component-level only.
- 144 rows match neither formula.
- Component-level rounding matches 16,957 rows overall, compared with 17,850
  combined-total matches.
- Component-level rounding fixes only 9 combined-total mismatches while causing
  902 previously matching rows to mismatch.
- Component-level rounding therefore produces 893 fewer matches overall.
- All 9 component-level-only rows contain positive overtime.
- For those 9 rows, combined-total is 0.01 above recorded labor cost while
  component-level rounding matches exactly.
- Of the 144 neither-match rows, 143 have both formulas producing the same
  result, 0.01 above recorded labor cost.
- TE003191 is the remaining neither-match row.

Decision:

- Combined-total rounding remains the primary labor-cost validation formula.
- Component-level rounding is rejected as the primary formula.
- The 152 one-cent exceptions will be preserved and documented rather than
  automatically corrected.
- TE003191 will remain unchanged and be flagged for stakeholder clarification.

#### Missing Hourly Rate

- TE001843 is the only row with a missing `hourly_rate`.
- It records 43.57 regular hours, zero overtime, and labor cost of 1,697.49.
- The implied hourly rate is 38.96.
- Investigation 35 tested all 4,101 possible two-decimal rates from 27.00
  through 68.00.
- A rate of 38.96 was the only candidate that reproduced the recorded labor
  cost under the combined-total formula.

Decision:

- Impute 38.96 in the cleaned analytical output.
- Preserve the raw NULL.
- Flag the cleaned value as formula-derived rather than source-confirmed.

#### Trade Values

Six distinct raw trade values were identified:

- `Carpenter`: 7,160 rows
- `Laborer`: 4,571 rows
- `Finisher`: 3,703 rows
- `Superintendent`: 2,568 rows
- `carpenter `: 1 row
- `General Labor`: 1 row

The four established categories account for 18,002 of the 18,004 rows.

- TE000917 contains the `carpenter ` formatting variant.
- The value differs from `Carpenter` by capitalization and trailing whitespace.
- TE001216 contains the dataset's only `General Labor` value.
- TE001216 belongs to employee E401.
- The isolated row does not provide enough evidence to determine whether
  `General Labor` is equivalent to `Laborer`.

#### Employee Trade History

- E401 has 949 labor entries.
- Of those entries, 948 are recorded as `Finisher` and one is recorded as
  `General Labor`.
- E401 has no entries recorded as `Laborer`.
- The employee's history therefore does not support standardizing
  `General Labor` to `Laborer`.
- The available evidence cannot determine whether TE001216 represents a
  legitimate temporary assignment or a source-data error.

Decision:

- Preserve TE001216's raw `General Labor` value.
- Flag the entry as unresolved pending stakeholder clarification.
- Do not map the value to either `Laborer` or `Finisher` without authoritative
  evidence.

#### Employee IDs

- The dataset contains 19 distinct employee IDs.
- Every employee ID matches the expected format of an uppercase `E` followed by
  exactly three digits.
- Entry counts range from 633 for E301 to 1,216 for E115.
- No isolated low-frequency employee ID suggests a typo or stray value.

Decision:

- No `employee_id` cleaning or correction rule is required.

#### Labor-to-Project Relationship

- P996 is the only labor `project_id` that does not exist in `projects.csv`.
- P996 affects one labor entry: TE000408.
- TE000408 records internally consistent hours, rate, and labor cost, but its
  row-level fields do not independently identify the intended project.
- The five neighboring time entries before TE000408 and the five after it all
  reference P003.
- P996 therefore interrupts an otherwise continuous P003 project block.

Decision:

- Correct TE000408's project ID from P996 to P003 only in cleaned output.
- Preserve the raw P996 value and flag the record as a source-data correction.

#### Labor and Project Timelines

The initial timeline query returned:

- 18,003 deduplicated labor entries
- 52 entries before baseline start
- 0 entries before actual start
- 2,818 entries after baseline completion
- 0 entries after an available actual completion date
- 0 entries after the reporting cutoff

The initial project summary distributed the 2,818 post-baseline entries across
78 projects.

- P026 had the most post-baseline entries at 126.
- The ten highest-count projects accounted for 973 entries.
- P090 had the longest observed extension at 209 days beyond baseline
  completion.
- The initial results indicate that post-baseline labor is broadly distributed
  rather than caused by a few isolated projects.
- Labor after baseline completion represents schedule-variance evidence and
  should not be treated automatically as a data-quality error.

Revalidation requirement:

- The timeline CTE used only `TRY_CAST(work_date AS DATE)` and therefore did not
  parse TE002542's `5/19/2023` value.
- TE002542 was included in the total row count but excluded from date
  comparisons.
- Investigations 39 and 39A must be rerun with the previously validated
  standard-plus-`M/D/YYYY` fallback before these counts are considered final.

#### Labor-Entry Grain and Overtime Interpretation

Investigation 40 is in progress.

The investigation will:

- Determine whether employees have multiple labor entries on the same
  `work_date`.
- Determine whether same-date entries span multiple projects.
- Aggregate regular and overtime hours across employee-date groups.
- Inspect whether work dates follow a consistent weekday pattern.
- Assess whether each row represents a daily entry, weekly entry, or project
  allocation within a larger time record.
- Determine whether the available evidence is sufficient to validate regular
  and overtime classification.

No overtime reclassification decision has been made.

Confirmed cleaning rules:

- Retain one TE000222 row.
- Convert `work_date` to DATE using standard parsing followed by the validated
  `M/D/YYYY` fallback.
- Standardize TE002542's date to `2023-05-19`.
- Preserve `regular_hours` at four-decimal scale.
- Preserve `overtime_hours`, `hourly_rate`, and `labor_cost` at two-decimal
  scale.
- Impute TE001843's hourly rate as 38.96 and flag it as formula-derived.
- Standardize `carpenter ` to `Carpenter`.
- Preserve TE001216's `General Labor` value and flag it as unresolved.
- Assign P003 specifically to TE000408 in cleaned output.
- Preserve TE000408's raw P996 value and flag the correction.
- Do not reclassify regular or overtime hours without a confirmed time-entry
  grain and authoritative overtime rule.
- Preserve raw values unchanged.

## Unresolved Items

### Projects

- Confirm P013's intended baseline date format.
- Preserve P052's missing `project_type` as unknown unless authoritative
  evidence becomes available.

### Project Budgets

- Compare the 97 distinct budget project IDs with the 96 distinct project IDs
  in `projects.csv`.
- Preserve BUD-P057-04's original-budget NULL unless a stakeholder confirms the
  formula-derived candidate.

### Labor Entries

- Revalidate Investigations 39 and 39A using the established
  standard-plus-`M/D/YYYY` work-date parsing rule.
- Complete Investigation 40 to determine the labor-entry grain and whether
  overtime classification can be evaluated.
- Determine total DECIMAL precision when the cleaned labor schema is
  implemented.
- Obtain stakeholder clarification for TE001216's unresolved `General Labor`
  value.
- Obtain stakeholder clarification for TE003191's unexplained 125.00
  labor-cost difference.
- Obtain stakeholder clarification regarding the time period represented by a
  labor entry and the rules governing regular and overtime classification.

### Remaining Datasets and Relationships

- Profile `project_updates.csv`.
- Profile `change_orders.csv`.
- Validate the remaining required relationships between supplied files.

## Remaining Project Work

1. Revalidate labor timeline profiling and complete Investigation 40.
2. Complete the final labor-entry cleaning and exception summary.
3. Profile `project_updates.csv`.
4. Profile `change_orders.csv`.
5. Compare project IDs in `project_budgets.csv` with `projects.csv`.
6. Validate remaining cross-file relationships.
7. Implement documented cleaning rules in cleaned analytical outputs.
8. Build project profitability and budget-variance metrics.
9. Build schedule-risk metrics.
10. Create final analytical tables and stakeholder-facing outputs.
11. Validate and document the completed analysis.

## Exact Next Task

Open `sql/04_labor_entries_profiling.sql`.

First, update the `labor_dates` CTE in Investigations 39 and 39A to reuse the
exact standard-plus-`M/D/YYYY` parsing rule validated in Investigation 31B.
Rerun both investigations and update their findings if TE002542 changes any
timeline count or project summary.

After revalidating the timeline results, execute Investigation 40's prepared
employee-date grouping query. Determine whether employees have multiple entries
on the same date, whether those entries span multiple projects, and whether the
evidence supports a daily, weekly, or project-allocation interpretation of each
labor row.

## Latest Analysis Commit

The latest committed analysis is:

- Commit:
  [`6f919a9114e436cc1bc422d7377eec7c5fd1cb6e`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/6f919a9114e436cc1bc422d7377eec7c5fd1cb6e)
- Message: `Extend labor relationship and timeline profiling`
- Date: August 13, 2026

The latest correction commit is:

- Commit:
  [`52a08ac4164bd7279d95e0ea6c91229d229c44ef`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/52a08ac4164bd7279d95e0ea6c91229d229c44ef)
- Message: `Fix budget normalization query`
- Date: July 31, 2026

The latest correction commit is:

- Commit:
  [`52a08ac4164bd7279d95e0ea6c91229d229c44ef`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/52a08ac4164bd7279d95e0ea6c91229d229c44ef)
- Message: `Fix budget normalization query`
- Date: July 31, 2026

## End-of-Session Update Routine

At the end of each work session:

1. Update the current phase and dataset-status sections.
2. Add newly confirmed findings and cleaning rules.
3. Remove resolved items and add newly identified unresolved items.
4. Update the remaining-work list if project scope or sequencing changes.
5. Replace the exact next task.
6. Record the latest analysis commit.
7. Add a dated entry to `docs/project_notes.md`.
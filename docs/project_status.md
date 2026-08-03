# Project Status

Last updated: August 3, 2026

## Current Phase

Raw-data profiling is in progress. The first-pass standalone profiling of
`projects.csv` and `project_budgets.csv` is complete.

For `project_budgets.csv`, schema, grain, candidate-key uniqueness, duplicates,
missing values, categorical consistency, monetary normalization, precision, and
the relationship among `original_budget_amount`, normalized
`approved_budget_change`, and `revised_budget_amount` have been validated.

Of the 674 source rows, 673 satisfy the expected monetary relationship, zero
are genuine mismatches, and one is untestable because its

Four additional raw CSV files have not yet been profiled.

## Reporting Cutoff

The reporting cutoff is June 30, 2026, inclusive.

- Actual activity dated on or before the cutoff belongs in cutoff-based
  analysis.
- Actual activity after the cutoff remains in the raw data but will be excluded
  from cutoff-based calculations.
- Future planned and forecast dates remain because they support schedule-risk
  analysis.

## Completed

- Profiled the inferred schema and sample values in `projects.csv`.
- Confirmed 97 raw project rows and 96 distinct project IDs.
- Confirmed that P042 is an exact duplicate in the immutable raw data.
- Profiled project-level missing values and investigated P052's missing
  `project_type`.
- Profiled and interpreted raw `project_status` variations.
- Diagnosed P013's ambiguous `baseline_completion_date`.
- Diagnosed and safely normalized P066's formatted contract value in profiling
  calculations.
- Tested baseline and actual date ordering.
- Profiled actual and baseline date ranges.
- Profiled contract-value and budget ranges.
- Tested whether any original budget exceeds its normalized original contract
  value.
- Documented the reporting-cutoff policy.
- Began profiling `project_budgets.csv`.
- Completed its schema inspection.
- Assessed its row count, expected grain, and candidate-key uniqueness.
- Identified and inspected its duplicated `budget_line_id`.
- Profiled NULL, blank, and whitespace-only values.
- Identified and inspected the row with a missing `original_budget_amount`.
- Profiled `cost_category` values for formatting and consistency.
- Identified the formatted value responsible for `approved_budget_change` being
  inferred as `VARCHAR`.
- Validated the candidate normalization rule across all populated
  `approved_budget_change` values.
- Completed Investigation 14 by profiling the range, NULL count, and
  fractional values in `revised_budget_amount`.
- Completed Investigation 14B by testing whether any
  `revised_budget_amount` values contain meaningful precision beyond two
  decimal places.
- Began Investigation 15 to validate the relationship among the three monetary
  fields.
- Completed Investigation 15A by inspecting BUD-P031-01 and BUD-P057-04.
- Completed Investigation 15B and confirmed that zero testable rows have
  monetary calculation mismatches.
- Completed Investigation 15C and classified 673 rows as matching, zero as
  mismatching, and one as untestable.
- Confirmed that the classification counts reconcile to all 674 source rows.
- Completed Investigation 15D and calculated an inferred candidate
  `original_budget_amount` of 31,672.00 for BUD-P057-04.
- Decided to preserve BUD-P057-04's source NULL and treat the candidate as
  inferred rather than observed.
- Completed Investigation 16 by profiling maximum absolute monetary values.
- Selected `DECIMAL(10, 2)` for cleaned `project_budgets` monetary fields.
- Completed the first-pass standalone profiling of `project_budgets.csv`.

## Key Findings

### Projects

- P052's missing `project_type` cannot be reliably inferred from its other
  attributes.
- All 21 missing `actual_completion_date` values belong to active or on-hold
  status variants.
- Six raw project-status labels represent three logical categories: active,
  completed, and on hold.
- P013's raw `baseline_completion_date` value, `8/10/2023`, is ambiguous
  between August 10 and October 8, 2023.
- P066's raw `original_contract_value`, `$672,000`, has a clear normalized
  value of `672000.00`.
- No safely tested baseline or actual date-ordering violation was identified.
- No actual-date boundary extends beyond the June 30, 2026, reporting cutoff.
- The maximum safely parsed baseline completion date is December 18, 2026.
  This is not a cutoff violation because it is a planned date.
- Normalized original contract values range from $276,000 to $3,773,000.
- Original budgets range from $223,600 to $2,917,000.
- No zero or negative processed contract value or budget was identified.
- No original budget exceeds its normalized original contract value.

### Project Budgets

- `project_budgets.csv` contains 674 rows, 673 distinct `budget_line_id`
  values, 97 distinct `project_id` values, and 673 distinct `project_id` and
  `cost_category` combinations.
- One row is expected to represent one budget line for one project and one cost
  category.
- BUD-P031-01 appears twice. The two rows match across all six columns,
  confirming an exact duplicate.
- The BUD-P031-01 duplicate explains both one-row candidate-key discrepancies.
- No NULL, blank, or whitespace-only values were identified in
  `budget_line_id`, `project_id`, `cost_category`, or
  `approved_budget_change`.
- No missing `revised_budget_amount` values were identified.
- BUD-P057-04 is the only row with a missing `original_budget_amount`.
- BUD-P057-04 has an `approved_budget_change` of 0 and a
  `revised_budget_amount` of 31672.
- Eleven distinct raw `cost_category` labels were identified. Seven appear to
  be canonical categories.
- Four inconsistent category variants were identified:
  - `General conditions` → `General Conditions`
  - `Materials ` → `Materials`
  - `labor` → `Labor`
  - `Sub-Contractors` → `Subcontractors`
- `$3,485.49` is the only populated `approved_budget_change` value that fails
  direct conversion to `DECIMAL(18, 2)`, and it appears once.
- Removing the currency symbol and thousands separator produced zero remaining
  conversion failures across all populated values.
- `revised_budget_amount` ranges from 6,957.72 to 886,036.18.
- A total of 406 `revised_budget_amount` values contain a fractional component,
  confirming that the column should not be stored as an integer.
- Zero `revised_budget_amount` values changed when rounded to two decimal
  places.
- A scale of 2 can therefore preserve all observed
  `revised_budget_amount` values without rounding.
- Investigation 15B returned zero genuine mismatch rows among testable records.
- Of the 674 source rows, 673 are matching, zero are mismatching, and one is
  untestable.
- The matching, mismatching, and untestable counts reconcile to all 674 source
  rows.
- BUD-P057-04 is the only untestable row because its
  `original_budget_amount` is NULL.
- BUD-P057-04 has a normalized `approved_budget_change` of 0.00 and a
  normalized `revised_budget_amount` of 31,672.00.
- Subtracting the approved change from the revised amount produces an inferred
  candidate `original_budget_amount` of 31,672.00.
- The candidate is not source-confirmed. The source NULL will be preserved, and
  the candidate will be flagged as inferred if used for analysis.
- The maximum absolute observed monetary values are 845,930.00 for
  `original_budget_amount`, 104,800.44 for normalized
  `approved_budget_change`, and 886,036.18 for `revised_budget_amount`.
- The inferred candidate maximum is 31,672.00.
- Observed values require at most six digits before the decimal and a scale of
  two.
- `DECIMAL(8, 2)` is the minimum compatible type, but `DECIMAL(10, 2)` was
  selected to provide reasonable future headroom.

## Unresolved Items

### Projects

- Keep P013's ambiguous baseline completion date unresolved until its intended
  format is confirmed.
- Remove the exact P042 duplicate only in cleaned data.
- Treat P052 as unknown if a non-NULL project type is required in cleaned data.
- Implement explicit cleaned-output mappings for project statuses.
- Normalize P066's contract value in cleaned data.

### Project Budgets

- Retain only one BUD-P031-01 row in cleaned data.
- Standardize the four inconsistent `cost_category` variants in cleaned data.
- Normalize `approved_budget_change` by removing `$` and `,` before conversion.
- Convert cleaned monetary fields to `DECIMAL(10, 2)`.
- Preserve BUD-P057-04's source NULL. If its inferred candidate is used for
  analysis, expose it separately and flag it as inferred.
- Compare the 97 distinct project IDs in `project_budgets.csv` with the 96
  distinct project IDs in `projects.csv` during relationship testing.

### Remaining Work

- Profile `cost_transactions.csv`.
- Profile `labor_entries.csv`.
- Profile `project_updates.csv`.
- Profile `change_orders.csv`.
- Validate key relationships between the supplied files.
- Create cleaned outputs after raw-data profiling is complete.

## Exact Next Task

Open `sql/01_data_profiling.sql` and begin Investigation 17 by writing the
purpose comment for the initial profiling of `cost_transactions.csv`.

The investigation will inspect the inferred schema, sample values, row count,
expected grain, and likely transaction identifier before deeper profiling
begins.

Do not write the SQL query until the purpose comment has been reviewed.

## Latest Analysis Commit

The latest analysis commit is:

- Commit:
  [`4e41cbd3043803186da819b204d99278dcea66a8`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/4e41cbd3043803186da819b204d99278dcea66a8)
- Message: `Complete project budget monetary profiling`
- Date: August 3, 2026

The latest correction commit is:

- Commit:
  [`52a08ac4164bd7279d95e0ea6c91229d229c44ef`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/52a08ac4164bd7279d95e0ea6c91229d229c44ef)
- Message: `Fix budget normalization query`
- Date: July 31, 2026

## End-of-Session Update Routine

At the end of each work session:

1. Update the current phase.
2. Add newly completed work and findings.
3. Remove resolved items and add new unresolved items.
4. Replace the exact next task.
5. Record the latest analysis commit.
6. Add a dated entry to `docs/project_notes.md`.
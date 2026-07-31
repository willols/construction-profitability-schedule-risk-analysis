# Project Status

Last updated: July 31, 2026

## Current Phase

Raw-data profiling is in progress. The first-pass standalone profiling of
`projects.csv` is complete. Profiling of `project_budgets.csv` is complete
through schema, grain, key uniqueness, duplicates, missing values, categorical
consistency, and validation of the `approved_budget_change` normalization
rule. The remaining monetary types and relationships still require
investigation. Four additional raw CSV files have not yet been profiled.

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
- Completed `project_budgets.csv` documentation through Investigation 13A.
- Identified the formatted value responsible for `approved_budget_change` being
  inferred as `VARCHAR`.
- Validated the candidate normalization rule across all populated
  `approved_budget_change` values.

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
- If revised budget equals original budget plus approved change, the implied
  original amount for BUD-P057-04 is 31672. This relationship has not yet been
  validated.
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
- The normalization rule is validated, but the final cleaned monetary type and
  `revised_budget_amount` precision remain unresolved.

## Unresolved Items

### Projects

- Keep P013's ambiguous baseline completion date unresolved until its intended
  format is confirmed.
- Remove the exact P042 duplicate only in cleaned data.
- Treat P052 as unknown if a non-NULL project type is required in cleaned data.
- Implement explicit cleaned-output mappings for project statuses.
- Normalize P066's contract value in cleaned data.

### Project Budgets

- Inspect `revised_budget_amount` and select appropriate cleaned-data types for
  the monetary columns.
- Validate the relationship among `original_budget_amount`,
  `approved_budget_change`, and `revised_budget_amount`.
- Keep BUD-P057-04's missing `original_budget_amount` unresolved until the
  monetary relationship has been validated.
- Retain only one BUD-P031-01 row in cleaned data.
- Standardize the four inconsistent `cost_category` variants in cleaned data.
- Compare the 97 distinct project IDs in `project_budgets.csv` with the 96
  distinct project IDs in `projects.csv` during relationship testing.
- Complete the remaining `project_budgets.csv` profiling investigations.

### Remaining Work

- Profile `cost_transactions.csv`.
- Profile `labor_entries.csv`.
- Profile `project_updates.csv`.
- Profile `change_orders.csv`.
- Validate key relationships between the supplied files.
- Create cleaned outputs after raw-data profiling is complete.

## Exact Next Task

Open `sql/01_data_profiling.sql` and write the first attempt at the
Investigation 14 purpose comment. Investigation 14 will inspect
`revised_budget_amount` precision and numeric compatibility before selecting a
cleaned monetary type. Do not write the SQL query until the purpose comment has
been reviewed.

## Latest Analysis Commit

- Commit:
  [`d156d59afd1aa76ebfb8e55c14ffe62efbbc1c84`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/d156d59afd1aa76ebfb8e55c14ffe62efbbc1c84)
- Message: `Profile project budget structure and quality`
- Date: July 24, 2026

## End-of-Session Update Routine

At the end of each work session:

1. Update the current phase.
2. Add newly completed work and findings.
3. Remove resolved items and add new unresolved items.
4. Replace the exact next task.
5. Record the latest analysis commit.
6. Add a dated entry to `docs/project_notes.md`.

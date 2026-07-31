# Project Notes

This file is the chronological record of important work, decisions, reasoning,
and lessons. Add each new dated entry directly below this introduction.

## July 31, 2026

### Work Completed

- Resumed `project_budgets.csv` profiling after the travel break.
- Completed Investigation 13 to determine why `approved_budget_change` was
  inferred as `VARCHAR`.
- Completed Investigation 13A to validate the candidate normalization rule.
- Updated the profiling file's next steps.

### Decisions and Reasoning

- The raw CSV remains immutable; monetary formatting will be removed only in
  cleaned outputs and profiling calculations.
- `REPLACE()` normalizes the formatted text but does not change its data type.
  Numeric conversion must still occur after normalization.
- `DECIMAL(18, 2)` was used to test numeric parseability; the final cleaned
  monetary type has not yet been selected.
- `revised_budget_amount` must be investigated before the monetary-field
  relationship and BUD-P057-04's missing original amount can be resolved.

### Key Results

- `$3,485.49` is the only populated `approved_budget_change` value that fails
  direct conversion to `DECIMAL(18, 2)`, and it appears once.
- The currency symbol and thousands separator explain why DuckDB inferred the
  column as `VARCHAR`.
- After removing `$` and `,`, zero populated values failed conversion to
  `DECIMAL(18, 2)`.
- The normalization rule is therefore validated for all observed populated
  `approved_budget_change` values.

### Verification and Closeout

- `git diff --check` returned no output.
- The complete profiling SQL file executed through the DuckDB CLI with exit
  code 0.
- Analysis commit
  [`9e84a97410cad5b81abd357e3cd647c45fb31619`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/9e84a97410cad5b81abd357e3cd647c45fb31619)
  was pushed to `main` with the message
  `Profile approved budget change formatting`.
- Correction commit
  [`52a08ac4164bd7279d95e0ea6c91229d229c44ef`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/52a08ac4164bd7279d95e0ea6c91229d229c44ef)
  removed a duplicated `SELECT` line and was pushed to `main`.

### Next Session

Begin Investigation 14 by writing its purpose comment. Investigate
`revised_budget_amount` precision and numeric compatibility before selecting a
cleaned monetary type. Do not write the SQL query until the purpose comment has
been reviewed.

## July 24, 2026

### Work Completed

- Began profiling `project_budgets.csv`.
- Completed its schema inspection.
- Assessed row count, expected grain, and candidate-key uniqueness.
- Checked `budget_line_id` for missing and duplicated values.
- Identified the duplicated key and compared the complete affected records.
- Profiled NULL, blank, and whitespace-only values across the file.
- Identified and inspected the row with a missing `original_budget_amount`.
- Profiled `cost_category` values for formatting and consistency.
- Completed documentation through Investigation 12.

### Decisions and Reasoning

- One row is expected to represent one budget line for one project and one cost
  category.
- `budget_line_id` is the intended row-level key, while `project_id` may repeat
  because one project can contain multiple budget lines.
- A difference between total rows and a distinct-key count does not immediately
  prove duplication because `COUNT(DISTINCT column)` excludes NULL values.
  Missing-key and duplicate checks must be performed separately.
- Broad cross-file relationship checks will generally wait until the standalone
  profiling of the relevant files is complete.
- The raw CSVs remain immutable. Duplicate removal, category standardization,
  and any monetary type conversions belong only in cleaned outputs.
- BUD-P057-04's missing `original_budget_amount` will remain unresolved until
  the relationship among the three monetary fields is validated.
- `approved_budget_change` and `revised_budget_amount` require further
  investigation before their cleaned-data types are selected.

### Key Results

- `project_budgets.csv` contains 674 raw rows, 673 distinct `budget_line_id`
  values, 97 distinct `project_id` values, and 673 distinct `project_id` and
  `cost_category` combinations.
- No NULL, blank, or whitespace-only `budget_line_id` values were identified.
- BUD-P031-01 appears twice. The two rows match across all six columns,
  confirming an exact duplicate.
- The BUD-P031-01 duplicate explains both one-row discrepancies in the
  candidate-key counts.
- No missing or blank values were identified in `project_id`, `cost_category`,
  or `approved_budget_change`.
- No missing `revised_budget_amount` values were identified.
- BUD-P057-04 is the only row with a missing `original_budget_amount`.
- BUD-P057-04 has an `approved_budget_change` of 0 and a
  `revised_budget_amount` of 31672.
- If revised budget equals original budget plus approved change, the implied
  original amount for BUD-P057-04 is 31672. This relationship has not yet been
  validated, so no imputation decision has been made.
- Eleven distinct raw `cost_category` labels were identified. Seven appear to
  be canonical: Labor, Equipment, Permits & Fees, Other, Subcontractors,
  Materials, and General Conditions.
- Four inconsistent category variants were identified, each appearing once:
  - `General conditions` → `General Conditions`
  - `Materials ` → `Materials`
  - `labor` → `Labor`
  - `Sub-Contractors` → `Subcontractors`

### Verification and Closeout

- `git diff --check` returned no output.
- The complete `sql/01_data_profiling.sql` file executed successfully with no
  errors.
- Only `sql/01_data_profiling.sql` was included in the analysis commit.
- Commit
  [`d156d59afd1aa76ebfb8e55c14ffe62efbbc1c84`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/d156d59afd1aa76ebfb8e55c14ffe62efbbc1c84)
  was pushed to `main` with the message
  `Profile project budget structure and quality`.

### Next Session

Begin Investigation 13 by determining why `approved_budget_change` was inferred
as `VARCHAR`. Then inspect `revised_budget_amount` and validate the relationship
among `original_budget_amount`, `approved_budget_change`, and
`revised_budget_amount` before resolving BUD-P057-04's missing original amount.

## July 23, 2026

### Work Completed

- Corrected three minor documentation errors in
  `sql/01_data_profiling.sql`.
- Added a reporting-cutoff policy for June 30, 2026.
- Completed Investigation 6B for actual-date ordering.
- Completed Investigation 7A for actual-date ranges.
- Completed Investigation 7B for safely parsed baseline-date ranges.
- Completed Investigation 8A for contract-value and budget ranges.
- Completed Investigation 8B for potential negative planned margins.
- Reconstructed the profiling file's `-- Next steps:` section.
- Ran the full profiling SQL file successfully.
- Reviewed, committed, and pushed the completed `projects.csv` profiling work.

### Decisions and Reasoning

- The reporting cutoff represents the portfolio as of June 30, 2026; it does
  not make every later date invalid.
- Actual activity after the cutoff will remain in raw data but will be excluded
  from cutoff-based calculations.
- Future baseline and forecast dates will remain because they are necessary for
  schedule-risk analysis.
- Range checks flag potentially unreasonable boundaries but do not prove that
  every value within the range is correct.
- Aggregate minimums and maximums may come from different projects and must not
  be interpreted as dates belonging to the same row.
- `MIN()` and `MAX()` ignore NULL values. If every input value is NULL, the
  aggregate result is NULL.
- Text-based minimums and maximums are unreliable for mixed-format dates because
  they compare character order rather than calendar order.
- P013 must remain excluded from calculations requiring a confirmed baseline
  completion date because neither possible interpretation can be called correct
  without additional evidence.
- P066 can be included in numeric profiling after removing the dollar sign and
  comma and safely converting the result to `DECIMAL(18, 2)`.
- An original budget greater than an original contract value would indicate a
  potential negative planned margin, but it would require investigation rather
  than automatic classification as a data error.

### Key Results

- No actual completion date occurs before its corresponding actual start date.
- Actual starts range from January 28, 2023, to April 26, 2026.
- Non-NULL actual completions range from May 19, 2023, to March 22, 2026.
- Baseline starts range from January 13, 2023, to April 19, 2026.
- Safely parsed baseline completions range from May 9, 2023, to December 18,
  2026.
- Normalized original contract values range from $276,000 to $3,773,000.
- Original budgets range from $223,600 to $2,917,000.
- No original budget exceeds its normalized original contract value.

### Verification and Closeout

- `git diff --check` returned no output.
- Only `sql/01_data_profiling.sql` was modified for the analysis commit.
- The Git diff was reviewed manually.
- The complete SQL file executed successfully with no errors.
- Commit
  [`2ab81d844c57ca701e21fccd644ace42c0dfeca9`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/2ab81d844c57ca701e21fccd644ace42c0dfeca9)
  was pushed to `main`.

### Next Session

Begin profiling `project_budgets.csv` with an Investigation 9 purpose comment
and schema inspection. Continue with row count, grain, key uniqueness,
duplicates, and missing values.

## July 22, 2026

### Work Completed

- Added and interpreted Investigation 3 findings.
- Investigated P052, the only row missing `project_type`.
- Compared all 21 missing actual completion dates with raw project statuses.
- Profiled all raw status values and identified six labels representing three
  logical categories.
- Identified P013's ambiguous baseline completion date as the cause of a
  `VARCHAR` inference.
- Identified P066's formatted contract value as the cause of a `VARCHAR`
  inference.
- Completed baseline date-order checks through Investigation 6A.

### Decisions and Findings

- P052's missing project type cannot be inferred safely.
- Missing actual completion dates are consistent with unfinished projects.
- Status cleaning requires explicit mappings, not only `LOWER(TRIM())`.
- P013 must remain unresolved until its intended date convention is confirmed.
- P066 can be normalized to `672000.00` in cleaned output.
- No safely parsed baseline completion date occurs before its baseline start
  date.
- Raw CSVs remain immutable; all corrections belong in cleaned outputs.

### Closeout

- Commit
  [`6e4df2653d0e12c60a81f8663d6a9eda105c2299`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/6e4df2653d0e12c60a81f8663d6a9eda105c2299)
  was pushed to `main`.

# Project Notes

This file is the chronological record of important work, decisions, reasoning,
and lessons. Add each new dated entry directly below this introduction.

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

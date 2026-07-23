# Project Status

Last updated: July 23, 2026

## Current Phase

Raw-data profiling is in progress. The first-pass standalone profiling of
`projects.csv` is complete. Five supplied CSV files remain to be profiled before
cleaned outputs and cross-file business analysis are created.

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
- Confirmed 97 raw rows and 96 distinct project IDs.
- Confirmed that P042 is an exact duplicate in the immutable raw data.
- Profiled missing values and investigated P052's missing `project_type`.
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

## Key Findings

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

## Unresolved Items

- Keep P013's ambiguous baseline completion date unresolved until its intended
  format is confirmed.
- Remove the exact P042 duplicate only in cleaned data.
- Treat P052 as unknown if a non-NULL project type is required in cleaned data.
- Implement explicit cleaned-output mappings for project statuses.
- Normalize P066's contract value in cleaned data.
- Profile `project_budgets.csv`.
- Profile `cost_transactions.csv`.
- Profile `labor_entries.csv`.
- Profile `project_updates.csv`.
- Profile `change_orders.csv`.
- Validate key relationships between the supplied files.
- Create cleaned outputs after raw-data profiling is complete.

## Exact Next Task

Open `sql/01_data_profiling.sql` and write the first attempt at the
Investigation 9 purpose comment for `project_budgets.csv`. Begin by inspecting
the raw file's column names and DuckDB-inferred data types. Then profile its row
count, grain, key uniqueness, duplicates, and missing values.

## Latest Analysis Commit

- Commit: [`2ab81d844c57ca701e21fccd644ace42c0dfeca9`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/2ab81d844c57ca701e21fccd644ace42c0dfeca9)
- Message: `Complete projects data profiling`
- Date: July 23, 2026

## End-of-Session Update Routine

At the end of each work session:

1. Update the current phase.
2. Add newly completed work and findings.
3. Remove resolved items and add new unresolved items.
4. Replace the exact next task.
5. Record the latest analysis commit.
6. Add a dated entry to `docs/project_notes.md`.

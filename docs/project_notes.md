# Project Notes

This file is the chronological record of important work, decisions, reasoning,
and lessons. Add each new dated entry directly below this introduction.

## August 6, 2026

### Work Completed

- Completed Investigation 20C by inspecting the three negative transactions.
- Completed Investigation 20D by determining why P014, P047, and P082 appear
  in additional transaction blocks.
- Completed Investigation 20E by locating the two P007 transaction-block starts.
- Completed Investigations 20F through 20F-B by inspecting P998, comparing
  TX000729 with surrounding P007 transactions, and checking whether P998 exists
  in `projects.csv` or `project_budgets.csv`.
- Completed Investigation 21 by profiling `cost_category` values.
- Completed Investigation 22 by profiling `payment_status` values.
- Completed Investigation 23 by validating the transaction-date range against
  the reporting cutoff.
- Completed Investigation 24 by profiling `vendor_name` values.

### Decisions and Reasoning

- The three negative transactions represent legitimate returned-material credits
  rather than data-quality errors.
- Negative credits will remain negative so they correctly reduce their projects'
  material costs.
- The additional blocks for P014, P047, and P082 are valid consequences of
  separately recorded credit transactions.
- P998 is not supported as a legitimate project ID by the surrounding
  transaction context or the other profiled project files.
- Within the simulated client scenario, TX000729 will be assigned to P007 only
  in the cleaned cost-transactions output.
- The raw P998 value and all other raw source values will remain unchanged.
- Four canonical payment statuses will remain distinct: `paid`, `approved`,
  `pending`, and `applied`.
- The three `applied` transactions are valid posted credits and will not be
  combined with `paid`.
- The analytical treatment of `approved` and `pending` transactions will be
  defined when project-cost metrics are developed.
- No vendor-name standardization mappings are currently required.

### Key Results

- TX011201, TX011202, and TX011203 each contain a negative amount of
  1,800.00.
- All three negative transactions are Materials transactions described as
  `Returned material credit` with a payment status of `applied`.
- The three credit transactions explain the repeated blocks for P014, P047,
  and P082.
- TX000727 begins P007's original block after P006.
- TX000730 begins a second P007 block because TX000729 is assigned to P998.
- TX000729 is immediately preceded and followed by P007 transactions.
- TX000729 is otherwise consistent with its surrounding P007 transactions in
  date range, cost category, description, amount, and payment status.
- P998 appears once in `cost_transactions.csv` and does not appear in either
  `projects.csv` or `project_budgets.csv`.
- Eight distinct raw `cost_category` values were observed. Six canonical values
  account for 11,202 transactions.
- Two one-row category variants require standardization:
  - `Sub-Contractor` → `Subcontractors`
  - `materials ` → `Materials`
- Six distinct raw `payment_status` values were observed. Four canonical values
  account for 11,202 transactions.
- Two one-row payment-status variants require standardization:
  - `PENDING ` → `pending`
  - `Paid` → `paid`
- Transaction dates range from January 28, 2023, through June 30, 2026.
- No transactions occur after the June 30, 2026 reporting cutoff.
- Twenty-one distinct vendor names account for all 11,204 transactions, with no
  apparent variants requiring standardization.

### Next Session

Begin Investigation 25 by writing its purpose comment. Validate every non-NULL
`project_id` in `cost_transactions.csv` against `projects.csv` and identify any
unmatched IDs that could cause costs to be excluded from project-profitability
calculations. Do not write the SQL query until the purpose comment has been
reviewed.

## August 5, 2026

### Work Completed

- Completed Investigation 19A by inspecting TX000316, the transaction with the
  missing `project_id`.
- Completed Investigation 19B by evaluating P003 as the probable project
  assignment using transaction-order context.
- Used `LAG()` to compare each transaction's project with the preceding project
  and `QUALIFY` to isolate project-block transitions.
- Completed Investigation 20 to identify why `amount` was inferred as
  `VARCHAR`.
- Completed Investigation 20A to validate the proposed amount-normalization
  rule across the complete file.
- Completed Investigation 20B to profile normalized amount range, signs, and
  decimal precision.

### Decisions and Reasoning

- The isolated TX000316 record does not contain a project-specific identifier.
- Transaction ordering provides useful supporting evidence but should not be
  treated as conclusive proof without source-system or client confirmation.
- P003 was accepted as the correct project assignment for TX000316 based on
  strong internal evidence and simulated client confirmation.
- The raw CSV will remain immutable.
- TX000316 will be assigned to P003 only in cleaned output through an explicit,
  transaction-specific correction.
- Currency symbols and thousands separators will be removed from `amount`
  before numeric conversion.
- `DECIMAL(10, 2)` was selected for the cleaned `amount` field because it
  preserves the observed precision, provides headroom above the current
  maximum, and remains consistent with the monetary type selected for
  `project_budgets.csv`.
- Negative amounts require record-level inspection before they can be
  classified as valid credits, reversals, or data anomalies.
- The unexpected P998 value and repeated project blocks will be revisited
  during relationship profiling.

### Key Results

- TX000316 has a transaction date of June 1, 2024, a cost category of
  `Permits & Fees`, a vendor of `Third-Party Inspection Services`, a description
  of `Permits & Fees site expense`, an amount of 683.86, and a payment status
  of `paid`.
- The transaction-order analysis identified 97 distinct non-NULL project IDs
  and 101 project-block starts.
- P007, P014, P047, and P082 each appear in more than one transaction block.
- P998 appears once at TX000729 and splits P007 into two blocks.
- P003 begins at TX000236, and the P004 block begins at TX000360.
- TX000316 falls within P003's transaction range and is immediately surrounded
  by P003 transactions.
- `$46.90` is the only populated `amount` value that fails direct conversion to
  `DECIMAL(18, 2)`.
- After removing `$` and `,`, all 11,204 amount values converted successfully,
  with zero normalized parse failures.
- Normalized amounts range from -1,800.00 to 83,246.69.
- No zero amounts were found.
- Three negative amounts were found.
- Zero values changed when rounded to two decimal places, confirming that a
  scale of two preserves every observed amount.

### Verification and Closeout

- `git diff --check` and `git diff --cached --check` returned no output.
- The complete `sql/01_data_profiling.sql` file executed successfully with no
  errors.
- Only `sql/01_data_profiling.sql` was included in the analysis commit.
- Analysis commit
  [`7498e847ef3c50b7ab22af4031690a4e8164dccb`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/7498e847ef3c50b7ab22af4031690a4e8164dccb)
  was created on `main` with the message
  `Profile cost transaction project and amount anomalies`.

### Next Session

Begin Investigation 20C by writing its purpose comment. Inspect the complete
records associated with the three negative amounts and determine whether they
represent valid credits, reversals, or data anomalies before continuing with
categorical, date-range, and relationship profiling of `cost_transactions.csv`.

## August 4, 2026

### Work Completed

- Began standalone profiling of `cost_transactions.csv`.
- Completed Investigation 17 to inspect the inferred schema, sample values, row
  count, expected grain, and likely transaction identifier.
- Completed Investigation 18 to validate `transaction_id` as the intended unique
  identifier.
- Completed Investigation 18A to identify the repeated `transaction_id`.
- Completed Investigation 18B to compare the complete records associated with
  the repeated identifier.
- Completed Investigation 19 to profile NULL, blank, and whitespace-only values
  across all columns.

### Decisions and Reasoning

- One row is expected to represent one cost transaction.
- `transaction_id` is the intended row-level identifier.
- Total rows, non-NULL identifiers, and distinct identifiers must be compared
  separately because `COUNT(column)` excludes NULL values and
  `COUNT(DISTINCT column)` excludes NULL values and repeated values.
- `WHERE` filters individual rows before aggregation, while `HAVING` filters
  grouped results after aggregate calculations.
- The raw CSV will remain immutable.
- One occurrence of the exact TX000138 duplicate will be retained and the other
  removed only in cleaned output.
- Retaining both TX000138 records would double-count the associated cost and
  distort project-level profitability.
- The missing `project_id` will remain unresolved until the associated
  transaction has been inspected and supporting evidence has been evaluated.
- `amount` requires further investigation before a cleaned numeric type and
  normalization rule are selected.

### Key Results

- `cost_transactions.csv` contains 11,204 rows and eight columns.
- `transaction_date` was inferred as `DATE`.
- `transaction_id`, `project_id`, `cost_category`, `vendor_name`,
  `description`, `amount`, and `payment_status` were inferred as `VARCHAR`.
- The first ten sampled `amount` values appeared numeric and contained no
  visible currency symbols or other formatting that explained the `VARCHAR`
  inference.
- The file contains 11,204 non-NULL `transaction_id` values and 11,203 distinct
  `transaction_id` values.
- TX000138 occurs twice.
- Both TX000138 records match across all eight columns, confirming an exact
  duplicate.
- TX000138 represents a paid Materials cost of 14,821.14 for project P002.
- Retaining both records would overstate P002's Materials costs by 14,821.14 and
  understate its profitability by the same amount.
- `project_id` contains one NULL value and no blank or whitespace-only values.
- The remaining seven columns contain no NULL values.
- All seven `VARCHAR` columns contain no blank or whitespace-only values.
- After removing one TX000138 occurrence, the expected cleaned row count and
  distinct `transaction_id` count are both 11,203.

### Verification and Closeout

- The complete `sql/01_data_profiling.sql` file executed successfully with no
  errors.
- Analysis commit `e22c642` was pushed to `main` with the message
  `Profile cost transaction structure and completeness`.
- Documentation commit `0cc3e17` was pushed to `main` with the message
  `Update project documentation for August 4`.
- `main` was clean and synchronized with `origin/main` after the push.

### Next Session

Begin Investigation 19A by writing its purpose comment. Inspect the complete
transaction associated with the missing `project_id` and determine whether a
project assignment is supported by evidence or must remain unresolved. Do not
write the SQL query until the purpose comment has been reviewed.

## August 3, 2026

### Work Completed

- Completed Investigation 15B to identify genuine monetary calculation
  mismatches across all testable `project_budgets.csv` rows.
- Completed Investigation 15C to classify and count matching, mismatching, and
  untestable rows.
- Completed Investigation 15D to assess the missing
  `original_budget_amount` in BUD-P057-04.
- Completed Investigation 16 to determine the required monetary precision.
- Documented the completed first-pass standalone profiling of
  `project_budgets.csv`.

### Decisions and Reasoning

- Zero monetary values remain testable because zero can represent no approved
  budget change.
- Rows with missing required monetary values are untestable rather than genuine
  mismatches.
- BUD-P057-04's source `original_budget_amount` will remain NULL because the
  source value is unknown.
- An inferred candidate may be used for analysis only if it is stored or exposed
  separately and clearly flagged as inferred rather than observed.
- `DECIMAL(8, 2)` is the minimum type that supports all observed monetary
  values, but it leaves limited future headroom.
- `DECIMAL(10, 2)` was selected for cleaned `project_budgets` monetary fields.
- `approved_budget_change` will be normalized by removing `$` and `,` before
  conversion to `DECIMAL(10, 2)`.
- Raw CSV files remain immutable. Duplicate removal, category standardization,
  monetary conversion, and inferred-value handling will occur only in cleaned
  outputs.

### Key Results

- Investigation 15B returned zero genuine calculation mismatches.
- Investigation 15C classified 673 rows as matching, zero as mismatching, and
  one as untestable.
- The category counts reconcile to all 674 source rows.
- BUD-P057-04 is the only untestable row because its
  `original_budget_amount` is NULL.
- BUD-P057-04 has a normalized `approved_budget_change` of 0.00 and a
  normalized `revised_budget_amount` of 31,672.00.
- The inferred candidate `original_budget_amount` for BUD-P057-04 is 31,672.00.
- The maximum absolute values are 845,930.00 for `original_budget_amount`,
  104,800.44 for normalized `approved_budget_change`, 886,036.18 for
  `revised_budget_amount`, and 31,672.00 for the inferred candidate.
- The observed values require no more than six digits before the decimal and a
  scale of two.
- The first-pass standalone profiling of `project_budgets.csv` is complete.

### Verification and Closeout

- `git diff --check` returned no output.
- The complete `sql/01_data_profiling.sql` file executed through the DuckDB CLI
  with exit code 0.
- Only `sql/01_data_profiling.sql` was included in the analysis commit.
- Analysis commit
  [`4e41cbd3043803186da819b204d99278dcea66a8`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/4e41cbd3043803186da819b204d99278dcea66a8)
  was pushed to `main` with the message
  `Complete project budget monetary profiling`.

### Next Session

Begin Investigation 17 by writing the purpose comment for the initial profiling
of `cost_transactions.csv`. Inspect its inferred schema, sample values, row
count, expected grain, and likely transaction identifier before beginning
deeper profiling.

## August 2, 2026

### Work Completed

- Resumed `project_budgets.csv` profiling with Investigation 14.
- Profiled the range, completeness, and fractional values in
  `revised_budget_amount`.
- Completed Investigation 14B to determine whether any
  `revised_budget_amount` values contain meaningful precision beyond two
  decimal places.
- Began Investigation 15 to validate the relationship among
  `original_budget_amount`, normalized `approved_budget_change`, and
  `revised_budget_amount`.
- Completed Investigation 15A by inspecting the known duplicate
  BUD-P031-01 and the missing-value row BUD-P057-04.

### Decisions and Reasoning

- `revised_budget_amount` must use a decimal-compatible monetary type because
  the column contains fractional values.
- The cleaned monetary type can use a scale of 2 because rounding all
  `revised_budget_amount` values to two decimal places did not alter any
  observed values.
- The final `DECIMAL` precision has not yet been selected.
- The expected revised budget is calculated as `original_budget_amount` plus
  normalized `approved_budget_change`.
- `approved_budget_change` must be normalized by removing `$` and `,` before
  converting it to `DECIMAL(18, 2)` for profiling calculations.
- Known duplicates, untestable rows, and genuine calculation mismatches must be
  evaluated separately.
- BUD-P057-04 cannot currently be classified as a calculation match or
  mismatch because its `original_budget_amount` is NULL.
- The raw CSV remains immutable; all normalization, duplicate removal, and type
  conversion will occur only in cleaned outputs or profiling calculations.

### Key Results

- `project_budgets.csv` contains 674 rows.
- `revised_budget_amount` ranges from 6,957.72 to 886,036.18.
- No NULL `revised_budget_amount` values were identified.
- A total of 406 `revised_budget_amount` values contain a fractional component.
- Zero rows changed when `revised_budget_amount` was rounded to two decimal
  places.
- A scale of 2 can therefore preserve all observed
  `revised_budget_amount` values without rounding.
- BUD-P031-01 appears twice with identical monetary values, confirming the
  previously identified exact duplicate.
- Both BUD-P031-01 rows satisfy the expected budget calculation:
  `132750 + 0 = 132750`.
- BUD-P057-04 has a NULL `original_budget_amount`, an
  `approved_budget_change` of 0, and a `revised_budget_amount` of 31672.
- The calculated revised amount for BUD-P057-04 is NULL because arithmetic
  involving a NULL value produces NULL.
- BUD-P057-04 must remain unresolved until the monetary relationship has been
  validated across the remaining testable rows.

### Next Session

Begin Investigation 15B by identifying testable rows where the calculated
revised budget does not equal `revised_budget_amount`. Exclude rows with missing
required values from the mismatch test and document them separately.

Then summarize the number of matching, mismatching, and untestable rows. Use the
validated ranges to select the final `DECIMAL` precision and scale for the
cleaned monetary columns.

After completing the monetary relationship analysis, retain only one
BUD-P031-01 row in cleaned data, standardize the four inconsistent
`cost_category` variants, and finish `project_budgets.csv` profiling before
continuing with the remaining four raw CSV files.

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

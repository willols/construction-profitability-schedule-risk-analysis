# Project Status

Last updated: August 7, 2026

## Current Phase

Raw-data profiling is in progress. First-pass standalone profiling of
`projects.csv`, `project_budgets.csv`, and `cost_transactions.csv` is complete.
Required transaction relationships with `projects.csv` and
`project_budgets.csv` have also been validated.

For `cost_transactions.csv`, the only unmatched non-NULL project ID is P998.
Six raw transaction-to-budget project/category mismatches were identified and
explained by documented project-ID or category inconsistencies. After applying
the proposed corrections within profiling CTEs, zero unmatched transaction
project/category pairs remained.

Payment-status treatment has been defined. Paid and approved transactions and
applied credits will form incurred project cost. Pending transactions will be
reported separately as pending cost exposure, with no assumed approval
probability.

Profiling of `labor_entries.csv` has begun through Investigation 28. Its schema,
sample values, apparent grain, candidate identifier, and initial profiling
priorities have been documented. `project_updates.csv` and `change_orders.csv`
have not yet been profiled.

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
- Began standalone profiling of `cost_transactions.csv`.
- Completed Investigation 17 by inspecting its inferred schema, sample values,
  row count, expected grain, and likely transaction identifier.
- Confirmed that `cost_transactions.csv` contains 11,204 rows and eight
  columns.
- Completed Investigation 18 by comparing total, non-NULL, and distinct
  `transaction_id` counts.
- Completed Investigation 18A and identified TX000138 as the only repeated
  `transaction_id`.
- Completed Investigation 18B and confirmed that the two TX000138 records are
  exact duplicates across all eight columns.
- Established a cleaned-output rule to retain one TX000138 record and remove
  one duplicate occurrence.
- Completed Investigation 19 by profiling NULL, blank, and whitespace-only
  values across all columns.
- Identified one transaction with a missing `project_id`.
- Executed the complete `sql/01_data_profiling.sql` file successfully with no
  errors.
  - Completed Investigation 19A by inspecting TX000316, the transaction with the
  missing `project_id`.
- Completed Investigation 19B by using transaction-order context to evaluate
  P003 as the probable project assignment.
- Used `LAG()` and `QUALIFY` to identify project-block transitions.
- Identified 97 distinct non-NULL project IDs and 101 project-block starts.
- Accepted P003 as the cleaned-output assignment for TX000316 based on strong
  internal evidence and simulated client confirmation.
- Completed Investigation 20 and identified `$46.90` as the only amount that
  fails direct conversion to `DECIMAL(18, 2)`.
- Completed Investigation 20A and confirmed that all 11,204 amount values parse
  successfully after removing `$` and `,`.
- Completed Investigation 20B by profiling normalized amount range, zero and
  negative values, and decimal precision.
- Confirmed that zero amount values change when rounded to two decimal places.
- Selected `DECIMAL(10, 2)` for the cleaned `cost_transactions.amount` field.
- Completed Investigation 20C and confirmed that the three negative
  transactions are legitimate returned-material credits.
- Completed Investigation 20D and determined that the credits explain the
  repeated transaction blocks for P014, P047, and P082.
- Completed Investigation 20E and confirmed that P998 interrupts the P007
  transaction sequence.
- Completed Investigations 20F through 20F-B by inspecting TX000729, comparing
  it with surrounding P007 transactions, and checking P998 across
  `projects.csv` and `project_budgets.csv`.
- Established a cleaned-output rule to assign TX000729 to P007 while preserving
  the raw P998 value.
- Completed Investigation 21 by profiling `cost_category` values and identifying
  two one-row variants requiring standardization.
- Completed Investigation 22 by profiling `payment_status` values and identifying
  two one-row variants requiring standardization.
- Confirmed that `applied` is a valid status for the three returned-material
  credits.
- Completed Investigation 23 and confirmed that no transaction occurs after the
  June 30, 2026 reporting cutoff.
- Completed Investigation 24 and confirmed that the 21 vendor names require no
  specific standardization mappings.
  - Completed Investigation 25 and confirmed that P998 is the only unmatched
  non-NULL transaction project ID.
- Completed Investigation 26 by standardizing payment statuses and calculating
  transaction counts and net amounts by status.
- Defined incurred cost, pending cost exposure, and maximum cost exposure
  treatment for the final analysis.
- Completed Investigation 27 and identified six unmatched raw transaction
  project/category pairs.
- Completed Investigation 27A and confirmed that the P019, P044, and P071
  mismatches result from budget-side category formatting inconsistencies rather
  than missing budget lines.
- Completed Investigation 27B by applying documented project-ID and category
  corrections within profiling CTEs.
- Confirmed that the standardized transaction-to-budget relationship check
  returns zero unmatched project/category pairs.
- Completed Investigation 28 by inspecting the `labor_entries.csv` schema,
  sample values, apparent row grain, candidate identifier, and initial
  profiling priorities.
- Completed standalone and relationship profiling of
  `cost_transactions.csv`.

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

### Cost Transactions

- `cost_transactions.csv` contains 11,204 rows and eight columns.
- One row is expected to represent one cost transaction.
- `transaction_id` is the intended row-level identifier.
- `transaction_date` was inferred as `DATE`.
- `transaction_id`, `project_id`, `cost_category`, `vendor_name`,
  `description`, `amount`, and `payment_status` were inferred as `VARCHAR`.
- The first ten sampled `amount` values appeared numeric and contained no
  visible formatting that explained the `VARCHAR` inference.
- The file contains 11,204 non-NULL `transaction_id` values and 11,203 distinct
  `transaction_id` values.
- TX000138 occurs twice, and the two records match across all eight columns.
- TX000138 represents a paid Materials cost of 14,821.14 for project P002.
- Retaining both TX000138 records would overstate P002's Materials costs by
  14,821.14 and understate its profitability by the same amount.
- `project_id` contains one NULL value and no blank or whitespace-only values.
- The remaining seven columns contain no NULL values.
- All seven `VARCHAR` columns contain no blank or whitespace-only values.
- TX000316 is the transaction with the missing `project_id`.
- P003 begins at TX000236, and the P004 block begins at TX000360.
- TX000316 falls within P003's transaction range and is immediately surrounded
  by P003 transactions.
- P003 will be assigned to TX000316 in cleaned output based on strong internal
  evidence and simulated client confirmation.
- The transaction-order analysis identified 97 distinct non-NULL project IDs
  and 101 project-block starts.
- P007, P014, P047, and P082 each appear in more than one transaction block.
- P998 appears once at TX000729 and splits P007 into two blocks.
- `$46.90` is the only populated `amount` value that fails direct conversion to
  `DECIMAL(18, 2)`.
- After removing `$` and `,`, all 11,204 amount values converted successfully,
  with zero normalized parse failures.
- Normalized amounts range from -1,800.00 to 83,246.69.
- No zero amounts were found.
- Zero values changed when rounded to two decimal places, confirming that a
  scale of two preserves every observed amount.
- `DECIMAL(10, 2)` was selected for the cleaned `amount` field.
- Three negative transactions were identified: TX011201, TX011202, and
  TX011203.
- Each negative transaction is a 1,800.00 returned-material credit with a
  payment status of `applied`.
- Preserve the negative values so the credits correctly reduce their projects'
  material costs.
- The three credits explain the repeated transaction blocks for P014, P047,
  and P082.
- TX000729 is the only transaction assigned to P998.
- TX000729 is immediately preceded and followed by P007 transactions and is
  consistent with the surrounding P007 records.
- P998 does not appear in `projects.csv` or `project_budgets.csv`.
- Within the simulated client scenario, assign TX000729 to P007 only in cleaned
  output.
- Eight distinct raw `cost_category` values were observed. Six canonical values
  account for 11,202 transactions.
- Two category variants require standardization:
  - `Sub-Contractor` → `Subcontractors`
  - `materials ` → `Materials`
- Six distinct raw `payment_status` values were observed. Four canonical values
  account for 11,202 transactions.
- Two payment-status variants require standardization:
  - `PENDING ` → `pending`
  - `Paid` → `paid`
- Transaction dates range from January 28, 2023, through June 30, 2026.
- No transaction occurs after the reporting cutoff.
- Twenty-one distinct vendor names account for all 11,204 transactions, with no
  apparent variants requiring standardization.
- P998 is the only non-NULL transaction project ID without a match in
  `projects.csv`.
- Payment-status standardization requires `LOWER(TRIM(payment_status))` because
  one pending value contains trailing whitespace.
- After standardization, the 11,204 transactions consolidate into four statuses:
  - `paid`: 8,586 transactions totaling $67,763,269.51
  - `approved`: 1,635 transactions totaling $12,725,390.85
  - `pending`: 980 transactions totaling $7,961,647.60
  - `applied`: 3 transactions totaling -$5,400.00
- Paid, approved, and applied transactions have a combined net incurred cost of
  $80,483,260.36.
- All statuses have a combined net amount of $88,444,907.96.
- Pending transactions will be reported separately as $7,961,647.60 of pending
  cost exposure.
- Six unmatched raw transaction project/category pairs were identified:
  - P008 + `materials `
  - P011 + `Sub-Contractor`
  - P019 + `Materials`
  - P044 + `Subcontractors`
  - P071 + `General Conditions`
  - P998 + `Materials`
- P019 uses a `Materials ` budget category with trailing whitespace.
- P044 uses `Sub-Contractors` instead of `Subcontractors`.
- P071 uses `General conditions` instead of `General Conditions`.
- All six raw relationship mismatches are explained by documented project-ID or
  category inconsistencies rather than genuinely missing budget lines.
- The standardized transaction-to-budget validation returned zero unmatched
  project/category pairs.

### Labor Entries

- `labor_entries.csv` contains nine columns.
- The apparent grain is one recorded labor entry for one employee on one project
  and work date.
- `time_entry_id` appears to be the intended row-level identifier, but its
  uniqueness has not yet been validated.
- `work_date` was inferred as `VARCHAR` even though sampled values resemble ISO
  dates.
- `regular_hours`, `overtime_hours`, `hourly_rate`, and `labor_cost` require
  range, precision, and calculation-consistency profiling.

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

### Cost Transactions

- Retain only one TX000138 record in cleaned output.
- Preserve the immutable raw CSV, including both TX000138 occurrences, the NULL
  on TX000316, and the P998 value on TX000729.
- Assign P003 specifically to TX000316 in the cleaned analytical layer.
- Assign P007 specifically to TX000729 in the cleaned analytical layer.
- Normalize `amount` by removing `$` and `,` before conversion to
  `DECIMAL(10, 2)`.
- Standardize documented `cost_category` variants to their canonical values.
- Standardize payment statuses with `LOWER(TRIM(payment_status))`.
- Preserve negative `applied` credits so they reduce incurred project cost.
- Include paid, approved, and applied transactions in incurred cost.
- Report pending transactions separately as pending cost exposure.
- Report maximum cost exposure as incurred cost plus pending cost exposure.
- Implement all documented rules only after raw-data profiling is complete.

### Remaining Work

- Continue standalone profiling of `labor_entries.csv`.
- Profile `project_updates.csv`.
- Profile `change_orders.csv`.
- Compare the 97 distinct project IDs in `project_budgets.csv` with the 96
  distinct project IDs in `projects.csv`.
- Validate the remaining key relationships between supplied files.
- Create cleaned analytical outputs after raw-data profiling is complete.
- Build project profitability, budget-variance, and schedule-risk metrics.

## Exact Next Task

Open `sql/01_data_profiling.sql` and write the purpose comment for Investigation
29.

Validate `time_entry_id` as the intended row-level identifier in
`labor_entries.csv` by comparing total rows, non-NULL identifiers, and distinct
identifiers. Investigate any missing or repeated identifiers before continuing
with completeness, date, numeric, and relationship profiling.

Do not write the SQL query until the purpose comment has been reviewed.

## Latest Analysis Commit

The latest analysis commit is:

- Commit:
  [`e5ca8c54de65caf0f11918adee4e122e9b5fb7cf`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/e5ca8c54de65caf0f11918adee4e122e9b5fb7cf)
- Message: `Complete cost transaction profiling and begin labor profiling`
- Date: August 7, 2026

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
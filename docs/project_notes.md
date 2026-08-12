# Project Notes

This file is the chronological record of important work, decisions, reasoning,
and lessons. Add each new dated entry directly below this introduction.

## August 12, 2026

### Work Completed

- Reorganized the combined profiling SQL into separate files for each dataset
  profiled so far.
- Created `sql/01_projects_profiling.sql`,
  `sql/02_project_budgets_profiling.sql`,
  `sql/03_cost_transactions_profiling.sql`, and
  `sql/04_labor_entries_profiling.sql`.
- Successfully executed all four dataset-specific profiling files and confirmed
  that the existing investigations remained intact.
- Removed the superseded combined `sql/01_data_profiling.sql` file.
- Completed Investigation 34D by comparing the combined-total and
  component-level labor-cost formula outcomes row by row.
- Completed Investigation 34E by inspecting the component-level-only and
  neither-match formula exceptions.
- Completed Investigation 35 by evaluating a formula-based imputation for
  TE001843's missing `hourly_rate`.
- Revalidated the previously established `work_date` parsing rule and confirmed
  that the existing date findings and cleaning decision remain valid.
- Removed the redundant date-investigation blocks because the same analysis was
  already completed and documented in Investigations 31–31C.
- Completed Investigation 36 by profiling raw `trade` values and frequencies.
- Completed Investigation 36A by inspecting the complete labor entries
  associated with the unusual `carpenter ` and `General Labor` values.

### Decisions and Reasoning

- Dataset-specific profiling files will replace the original combined profiling
  script because the combined file had grown to 2,731 lines and 107,341 bytes
  and was causing noticeable editor lag.
- Existing investigation numbers and documentation references were preserved
  while the completed SQL was reorganized.
- Each profiling file must remain independently executable.
- Combined-total rounding remains the primary labor-cost validation formula.
- Component-level rounding was rejected as the primary formula because it fixes
  only 9 combined-total mismatches while causing 902 previously matching rows
  to become mismatches.
- The 152 one-cent combined-total differences will remain unchanged and be
  documented as minor formula exceptions rather than automatically corrected.
- TE003191 will remain unchanged and continue to be flagged for stakeholder
  clarification because neither tested formula explains its additional 125.00
  of recorded labor cost.
- TE001843's missing `hourly_rate` will be imputed as 38.96 in the cleaned
  analytical output.
- The imputed rate will be flagged as formula-derived because it is supported by
  the recorded hours and labor cost but is not independently confirmed by an
  original payroll source.
- The raw NULL `hourly_rate` for TE001843 will remain unchanged.
- The previously established `work_date` cleaning rule remains unchanged:
  standard DATE parsing will be attempted first, with `M/D/YYYY` parsing used
  as a fallback.
- TE000917's `trade` value of `carpenter ` will be standardized to
  `Carpenter` because it is a confirmed capitalization and trailing-whitespace
  variant.
- No cleaning decision was established for TE001216's `General Labor` value
  because the isolated row does not prove that it is equivalent to `Laborer`.
- Employee E401's trade history must be inspected before deciding whether
  `General Labor` should be standardized.
- No raw source values were modified, and no cleaned analytical output was
  implemented during this session.

### Key Results

- Investigation 34D classified all 18,003 testable labor entries into four
  mutually exclusive formula-outcome categories.
- A total of 16,948 rows matched both the combined-total and component-level
  formulas.
- A total of 902 rows matched only the combined-total formula.
- A total of 9 rows matched only the component-level formula.
- A total of 144 rows matched neither formula.
- The four categories reconcile to all 18,003 testable rows.
- The overlap counts reproduce the earlier aggregate results: combined-total
  rounding matches 17,850 rows, while component-level rounding matches 16,957
  rows.
- Component-level rounding produces 893 fewer matches overall.
- All 9 component-level-only rows contain positive overtime hours.
- For those 9 rows, the combined-total result is 0.01 above the recorded labor
  cost, while component-level rounding reproduces the recorded value exactly.
- Of the 144 neither-match rows, 143 have both formulas producing the same
  result, 0.01 above the recorded labor cost.
- TE003191 is the remaining neither-match row; both formulas produce 1,405.88,
  which is 125.00 below its recorded labor cost of 1,530.88.
- Component-level rounding explains only 9 of the 152 one-cent combined-total
  differences, or 5.92%.
- The remaining 143 one-cent differences, or 94.08%, are not explained by
  either tested rounding method.
- Investigation 35 tested all 4,101 possible two-decimal hourly rates from
  27.00 through 68.00 for TE001843.
- An hourly rate of 38.96 was the only candidate that reproduced TE001843's
  recorded labor cost of 1,697.49 under the combined-total formula.
- TE001843 records 43.57 regular hours and zero overtime hours, and 43.57
  multiplied by 38.96 rounds to 1,697.49.
- Revalidation of the existing `work_date` rule reproduced the previously
  documented results: 18,003 values parse through standard DATE conversion,
  one value requires the `M/D/YYYY` fallback, and zero values remain
  unparseable.
- Investigation 36 returned six distinct raw `trade` values:
  `Carpenter`, `Laborer`, `Finisher`, `Superintendent`, `carpenter `, and
  `General Labor`.
- `Carpenter` occurred 7,160 times, `Laborer` 4,571 times, `Finisher` 3,703
  times, and `Superintendent` 2,568 times.
- The four established trade categories accounted for 18,002 of the 18,004
  rows.
- The formatting variant `carpenter ` and the unusual value `General Labor`
  occurred once each.
- TE000917, for employee E134 and project P005 on 2025-02-15, contains the
  one-row `carpenter ` formatting variant.
- TE001216, for employee E401 and project P006 on 2024-03-17, contains the
  dataset's only `General Labor` value.

### Next Session

Begin Investigation 36B by writing its purpose comment. Inspect employee E401's
trade history to determine whether the one-row `General Labor` value is
consistent with that employee's other recorded trade values. Use the evidence
to decide whether `General Labor` should be standardized to `Laborer` or remain
an unresolved category.

Do not write the SQL query until the purpose comment has been reviewed.

## August 11, 2026

### Work Completed

- Continued standalone profiling of `labor_entries.csv`.
- Completed Investigation 32 by profiling numeric ranges and counts of zero and
  negative values for `regular_hours`, `overtime_hours`, `hourly_rate`, and
  `labor_cost`.
- Completed Investigation 32A by retrieving the complete records associated
  with the minimum and maximum `regular_hours` and `labor_cost` values.
- Completed Investigation 32B by quantifying entries above 40 regular hours and
  comparing zero and positive overtime.
- Completed Investigation 33 by testing whether two-decimal rounding would
  alter values in each numeric labor field.
- Completed Investigation 33A by determining the minimum decimal scale required
  to preserve every `regular_hours` value.
- Completed Investigation 34 by testing a candidate dataset-wide labor-cost
  formula using combined-total rounding.
- Completed Investigation 34A by characterizing the size, direction, and
  frequency of the formula mismatches.
- Completed Investigation 34B by inspecting the single material labor-cost
  mismatch of 125.00.
- Completed Investigation 34C by testing component-level rounding as an
  alternative labor-cost calculation method.

### Decisions and Reasoning

- All profiled numeric values will remain unchanged because no negative values
  were found and the observed zero values were limited to `overtime_hours`.
- The minimum and maximum labor-cost records are mathematically consistent with
  their recorded hours and rates.
- Entries above 40 regular hours frequently record zero overtime, so the four
  46-hour entries are part of a broader dataset pattern rather than isolated
  anomalies.
- The available fields do not establish the time period represented by each
  labor entry or the business rules governing regular and overtime
  classification.
- Regular and overtime hours will not be reclassified without an authoritative
  business rule from the data owner.
- The definitions of `regular_hours`, `overtime_hours`, and the time-entry
  period remain stakeholder-clarification items.
- A two-decimal scale preserves every observed non-NULL `overtime_hours`,
  `hourly_rate`, and `labor_cost` value.
- A four-decimal scale is required to preserve every observed `regular_hours`
  value.
- The cleaned analytical layer will preserve `regular_hours` at four-decimal
  scale and the other three numeric fields at two-decimal scale.
- Total `DECIMAL` precision will be selected when the cleaned schema is
  implemented.
- Combined-total rounding is the better-supported labor-cost calculation method
  because it produces substantially fewer mismatches than component-level
  rounding.
- Component-level rounding was rejected as the primary dataset-wide formula
  because it increased rather than reduced the overall mismatch count.
- TE003191 will remain unchanged because the available fields do not explain
  its additional 125.00 of recorded labor cost.
- TE003191 will be flagged for stakeholder clarification rather than corrected
  through an unsupported assumption.
- TE001843's missing `hourly_rate` remains unresolved until the overlap between
  the two tested formula outcomes is understood.
- No raw values were modified, and no cleaned analytical output was implemented
  during this session.

### Key Results

- `regular_hours` ranged from 0.0973 to 46, with zero zero-value records and zero
  negative-value records.
- `overtime_hours` ranged from 0 to 9, with 14,033 zero-value records and zero
  negative-value records.
- Among non-NULL values, `hourly_rate` ranged from 27 to 68, with zero zero-value
  or negative-value records.
- `labor_cost` ranged from 5.80 to 3,822.02, with zero zero-value or
  negative-value records.
- Investigation 32A returned six records because four entries tied at the
  maximum of 46 regular hours.
- The four 46-hour entries were TE000859, TE004254, TE007194, and TE015023, and
  all four recorded zero overtime.
- TE014656 contained both the minimum `regular_hours` value of 0.0973 and the
  minimum `labor_cost` of 5.80.
- Multiplying TE014656's 0.0973 regular hours by its 59.64 hourly rate produces
  5.802972, which rounds to its recorded labor cost of 5.80.
- TE011416 contained the maximum `labor_cost` of 3,822.02.
- TE011416 records 45.45 regular hours, 8.12 overtime hours, and an hourly rate
  of 66.32.
- Regular pay plus overtime pay at 1.5 times the hourly rate produces
  3,822.0216 for TE011416, which rounds to the recorded labor cost of 3,822.02.
- Employee E312 appears in both overtime patterns: TE011416 records 45.45
  regular hours plus 8.12 overtime hours, while TE015023 records 46 regular
  hours and zero overtime.
- A total of 6,727 entries recorded more than 40 regular hours.
- Of those entries, 5,178, or 76.97%, recorded zero overtime, while 1,549, or
  23.03%, recorded positive overtime.
- Rounding `regular_hours` to two decimal places would alter 94 values.
- Rounding `overtime_hours`, `hourly_rate`, or `labor_cost` to two decimal
  places would alter zero non-NULL values.
- Rounding `regular_hours` to three decimal places would alter 82 values.
- Rounding `regular_hours` to four decimal places would alter zero values,
  establishing four as the minimum required scale.
- The combined-total labor-cost formula was testable for 18,003 of the 18,004
  raw labor rows.
- One row was untestable because TE001843 has a NULL `hourly_rate`.
- Combined-total rounding matched 17,850 testable rows, or 99.15%, and
  mismatched 153 rows, or 0.85%.
- Of the 153 mismatches, 152 recorded labor costs were 0.01 below the calculated
  value.
- One mismatch recorded labor cost 125.00 above the calculated value.
- The 125.00 mismatch belongs to TE003191 for employee E417, project P016, and
  the Finisher trade on September 30, 2024.
- TE003191 records 30.26 regular hours, zero overtime, an hourly rate of 46.46,
  and a recorded labor cost of 1,530.88.
- Multiplying TE003191's regular hours by its hourly rate produces 1,405.8796,
  which rounds to an expected labor cost of 1,405.88.
- No available field explains TE003191's additional 125.00.
- Component-level rounding matched 16,957 of the 18,003 testable rows, or
  94.19%, and mismatched 1,046 rows, or 5.81%.
- Component-level rounding produced 893 more net mismatches than combined-total
  rounding.
- The aggregate formula results do not reveal whether component-level rounding
  resolves any of the original 152 one-cent mismatches while creating
  mismatches elsewhere.

### Verification and Closeout

- All four dataset-specific profiling files executed successfully.
- `git diff --check` and `git diff --cached --check` returned no output.
- The SQL reorganization and new labor investigations were included in analysis
  commit
  [`e248c2e2472814ee07363e41204c5ec27c8473c1`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/e248c2e2472814ee07363e41204c5ec27c8473c1).
- The analysis commit was pushed to `main` with the message
  `Split profiling SQL and extend labor analysis`.

### Next Session

Begin Investigation 34D by writing its purpose comment. Calculate both the
combined-total and component-level expected labor costs for every testable row,
then classify each row as matching both formulas, matching combined-total only,
matching component-level only, or matching neither formula. Use the category
counts to determine whether component-level rounding explains the original 152
one-cent differences. Do not write the SQL query until the purpose comment has
been reviewed.

## August 10, 2026

### Work Completed

- Continued standalone profiling of `labor_entries.csv`.
- Completed Investigation 29 by validating `time_entry_id` as the intended
  row-level identifier.
- Completed Investigations 29A and 29B by identifying the repeated identifier
  and comparing its complete records.
- Completed Investigation 30 by profiling NULL, blank, and whitespace-only
  values across all nine columns.
- Completed Investigations 30A and 30B by inspecting the row with a missing
  `hourly_rate`, calculating its implied rate, and evaluating employee-history
  evidence.
- Completed Investigation 31 by testing `work_date` DATE parseability.
- Completed Investigation 31A by inspecting the unparseable date value.
- Completed Investigation 31B by validating a standard-plus-fallback date
  parsing rule across the complete file.
- Completed Investigation 31C by validating the standardized date range and
  reporting cutoff.

### Decisions and Reasoning

- `time_entry_id` can serve as the row-level identifier after removing one
  occurrence of the exact TE000222 duplicate.
- The raw `labor_entries.csv` file will remain unchanged.
- One TE000222 row will be retained and the other removed only in the cleaned
  analytical layer.
- TE001843 will remain in the dataset because its recorded `labor_cost` is
  present.
- The implied `hourly_rate` for TE001843 is 38.96, and that value reproduces the
  recorded `labor_cost` after rounding to two decimal places.
- Employee E115's history does not provide sufficient corroboration for the
  implied rate because the employee has many distinct rates and no stable
  historical rate pattern.
- TE001843's missing `hourly_rate` will remain unresolved until dataset-wide
  labor-cost formula validation determines whether reverse calculation is a
  reliable correction method.
- Cleaned `work_date` values will be stored as `DATE`.
- Standard ISO-compatible values will be converted directly, with M/D/YYYY
  parsing used as a fallback for the one inconsistent value.
- TE002542's raw `work_date` of `5/19/2023` will be standardized to the DATE
  value `2023-05-19` only in the cleaned analytical layer.
- All labor entries fall within the reporting period, so no date-based
  exclusions are required.
- No cleaned output was implemented during this session; cleaning decisions
  remain documented for later implementation.

### Key Results

- `labor_entries.csv` contains 18,004 raw rows.
- All 18,004 rows contain a non-NULL `time_entry_id`, but only 18,003 identifiers
  are distinct.
- TE000222 occurs twice, and both records match across all nine columns,
  confirming an exact duplicate.
- After removing one TE000222 occurrence, the expected cleaned row count and
  distinct `time_entry_id` count are both 18,003.
- All text columns are complete, with no NULL, empty, or whitespace-only values.
- All numeric columns are complete except for one NULL `hourly_rate`.
- TE001843 is the only row with a missing `hourly_rate`.
- TE001843 belongs to employee E115, project P008, and the Carpenter trade, with
  a `work_date` of March 22, 2024.
- The row records 43.57 regular hours, zero overtime hours, and a `labor_cost`
  of 1,697.49.
- Dividing `labor_cost` by `regular_hours` produces an implied `hourly_rate` of
  38.96.
- Multiplying 38.96 by 43.57 hours reproduces the recorded `labor_cost` of
  1,697.49 after rounding to two decimal places.
- The rate 38.96 appears only once elsewhere in E115's recorded history, on
  February 9, 2026, and therefore does not corroborate the missing rate from
  March 22, 2024.
- All 18,004 `work_date` values are present.
- A total of 18,003 `work_date` values convert directly to `DATE`, while one
  value initially fails conversion.
- The unparseable value belongs to TE002542 and is stored as `5/19/2023`.
- The standard-plus-fallback parsing rule converts all 18,004 values
  successfully, leaving zero unparseable dates.
- Standardized `work_date` values range from January 28, 2023, through June 30,
  2026.
- The latest labor date is exactly the reporting cutoff.
- Zero labor entries occur after the June 30, 2026 reporting cutoff.
- The labor-entry date range matches the previously profiled
  `cost_transactions.csv` date range.

### Verification and Closeout

- The complete `sql/01_data_profiling.sql` file executed through the DuckDB CLI
  with no SQL errors.
- `git diff --check` and `git diff --cached --check` returned no output.
- Only `sql/01_data_profiling.sql` was included in the analysis commit.
- Analysis commit
  [`44aaa82bf75b0b4bca413e4c1f678aae25536b5d`](https://github.com/willols/construction-profitability-schedule-risk-analysis/commit/44aaa82bf75b0b4bca413e4c1f678aae25536b5d)
  was pushed to `main` with the message
  `Profile labor numeric precision and cost formulas`.

### Next Session

Begin Investigation 32 by writing its purpose comment. Profile the numeric
ranges and reasonableness of `regular_hours`, `overtime_hours`, `hourly_rate`,
and `labor_cost`, including zero and negative values. Continue with precision
and labor-cost calculation-consistency profiling before resolving TE001843's
missing `hourly_rate`. Do not write the SQL query until the purpose comment has
been reviewed.

## August 7, 2026

### Work Completed

- Completed Investigation 25 by validating every non-NULL transaction
  `project_id` against `projects.csv`.
- Completed Investigation 26 by standardizing payment statuses and calculating
  transaction counts and net amounts by status.
- Defined the treatment of paid, approved, pending, and applied transactions in
  project-cost reporting.
- Completed Investigation 27 by validating raw transaction project/category
  pairs against `project_budgets.csv`.
- Completed Investigation 27A by inspecting the budget-side categories associated
  with three canonical transaction-category mismatches.
- Completed Investigation 27B by repeating the transaction-to-budget relationship
  check after applying the documented project-ID and category corrections.
- Completed the first-pass schema and sample inspection of `labor_entries.csv`
  through Investigation 28.
- Finished standalone and relationship profiling of `cost_transactions.csv`.

### Decisions and Reasoning

- P998 remains the only unmatched non-NULL transaction project ID.
- TX000729 will be reassigned from P998 to P007 only in the cleaned analytical
  layer; the raw value will remain unchanged.
- Payment statuses will be standardized with `LOWER(TRIM(payment_status))` to
  correct both capitalization and surrounding whitespace.
- Paid and approved transactions will be included in incurred project cost.
- Applied credits will remain negative and reduce incurred project cost.
- Pending transactions will be excluded from incurred cost and reported
  separately as pending cost exposure.
- Maximum cost exposure will be reported as incurred cost plus pending cost
  exposure.
- No approval probability will be assigned to pending transactions because the
  dataset does not contain transaction-status history.
- Project-ID and cost-category corrections will be applied only in the cleaned
  analytical layer.
- Standardized `project_id` and `cost_category` pairs will be used for
  transaction-to-budget joins.
- All raw CSV values will remain unchanged.
- `work_date` in `labor_entries.csv` requires parseability and formatting
  investigation before selecting a cleaned date type.

### Key Results

- Investigation 25 returned one unmatched non-NULL transaction project ID:
  P998.
- After standardization, all 11,204 transactions consolidate into four payment
  statuses:
  - `paid`: 8,586 transactions totaling 67,763,269.51
  - `approved`: 1,635 transactions totaling 12,725,390.85
  - `pending`: 980 transactions totaling 7,961,647.60
  - `applied`: 3 transactions totaling -5,400.00
- Paid, approved, and applied transactions have a combined net incurred cost of
  80,483,260.36.
- All payment statuses have a combined net amount of 88,444,907.96.
- The raw transaction-to-budget relationship check identified six unmatched
  project/category pairs:
  - P008 + `materials `
  - P011 + `Sub-Contractor`
  - P019 + `Materials`
  - P044 + `Subcontractors`
  - P071 + `General Conditions`
  - P998 + `Materials`
- P019 contains a `Materials ` budget category with trailing whitespace.
- P044 uses `Sub-Contractors` instead of the canonical `Subcontractors`
  category.
- P071 uses `General conditions` instead of the canonical
  `General Conditions` category.
- All six raw relationship mismatches are explained by documented project-ID
  or category inconsistencies rather than genuinely missing budget lines.
- The standardized transaction-to-budget relationship check returned zero
  unmatched project/category pairs.
- `labor_entries.csv` contains nine columns.
- `time_entry_id` appears to be the candidate row identifier, but its uniqueness
  has not yet been validated.
- The apparent labor-entry grain is one recorded labor entry for one employee
  on one project and work date.
- `work_date` was inferred as `VARCHAR` even though the sampled values resemble
  ISO dates.
- `regular_hours`, `overtime_hours`, `hourly_rate`, and `labor_cost` require
  numeric range, precision, and calculation-consistency profiling.

### Next Session

Begin Investigation 29 by writing its purpose comment. Validate
`time_entry_id` as the intended row-level identifier by comparing total rows,
non-NULL identifiers, and distinct identifiers. Investigate any missing or
repeated identifiers before continuing with completeness, date, numeric, and
relationship profiling of `labor_entries.csv`. Do not write the SQL query until
the purpose comment has been reviewed.

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

-- Projects Data Profiling
-- Source: data/raw/cost_transactions.csv
-- Purpose:
-- - Profile the raw cost_transactions dataset before cleaning and transformation.
-- - Identify schema, completeness, uniqueness, categorical, date, numeric,
--   and relationship issues that could affect the analysis.
-- Notes:
-- - Preserve the original investigation numbering from the combined profiling file.
-- - Preserve raw source values; document cleaning decisions separately.
-- - Reporting cutoff: 2026-06-30.
--
-- cost_transactions.csv profiling
-- Profiling scope:
-- Inspect column names, inferred data types, row counts, grain, key uniqueness,
-- duplicates, missing values, categorical consistency, date ranges, numeric
-- anomalies, and relationships between files.
-- Data-handling rule:
-- Treat all raw CSV files as immutable source data. Apply any corrections or
-- standardization only in cleaned outputs.


-- Investigation 17: Initial profiling of cost_transactions.csv
-- Purpose:
-- Inspect the inferred schema and sample values, count the rows, and form initial
-- hypotheses about the row-level grain and likely transaction identifier.

-- Inferred schema
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - Eight columns were detected.
-- - transaction_date was inferred as DATE.
-- - The remaining seven columns were inferred as VARCHAR.
-- - amount requires further investigation because DuckDB inferred it as
--   VARCHAR rather than a numeric type.


-- Sample value
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
LIMIT 10;

-- Findings:
-- - transaction_id values are sequential in the sample.
-- - The sample provides tentative support for one row per transaction.
-- - No sampled amount values contain currency symbols or otherwise explain why
--   DuckDB inferred the column as VARCHAR.
-- - Two payment_status values were observed: paid and approved.
-- - The first ten rows are not representative enough to establish file-wide
--   consistency.


-- Row count
SELECT
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - cost_transaction.csv contains 11,204


-- Investigation 17 conclusion:
-- - cost_transactions.csv contains 11,204 rows and eight columns.
-- - transaction_date was inferred as DATE.
-- - transaction_id, project_id, cost_category, vendor_name, description,
--   amount, and payment_status were inferred as VARCHAR.
-- - amount contains numeric-looking sample values but requires further
--   investigation because DuckDB inferred it as VARCHAR.
-- - The expected grain is one row per cost transaction, and transaction_id is
--   the likely unique identifier; both hypotheses require validation.


-- Investigation 18: Validate transaction_id as the unique identifier
-- Purpose:
-- Compare the total row count, non-NULL transaction_id count, and distinct
-- transaction_id count to determine whether every row has a populated,
-- unique transaction identifier.
SELECT
    COUNT(*) AS row_count,
    COUNT(transaction_id) AS non_null_transaction_id,
    COUNT(DISTINCT transaction_id) AS distinct_transaction_id
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - The file contains 11,204 rows and 11,204 non-NULL transaction_id values,
--   indicating that no transaction identifiers are missing.
-- - There are 11,203 distinct transaction_id values.
-- - The difference of one confirms one duplicate occurrence that requires
--   targeted inspection to determine whether the associated rows are identical
--   or conflicting.


-- Investigation 18A: Identify repeated transaction_id values
-- Purpose:
-- Identify transaction_id values that occur more than once and inspect their
-- associated rows to determine whether they are exact duplicates or conflicting
-- records.
SELECT
    transaction_id,
    COUNT(*) AS occurance_count
FROM read_csv_auto('data/raw/cost_transactions.csv')
GROUP BY transaction_id
HAVING COUNT(*) >1;

-- Findings:
-- - transaction_id TX000138 occurs twice.
-- - This explains the one-record difference between 11,204 non-NULL
--   transaction_id values and 11,203 distinct values.
-- - Further investigation is required to determine whether the associated rows
--   are exact duplicates or conflicting transactions.


-- Investigation 18B: Inspect records associated with TX000138
-- Purpose:
-- Inspect and compare all column values for the two records associated with
-- transaction_id TX000138 to determine whether they are exact duplicates or
-- conflicting transactions.
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE transaction_id = 'TX000138';

-- Findings:
-- - The two records associated with transaction_id TX000138 are exact
--   duplicates across all eight columns.
-- - If both records were included in analysis, project P002's Materials costs
--   would be overstated by 14,821.14, causing its profitability to be
--   understated by the same amount.
-- - The raw file will remain unchanged. In the cleaned output, one occurrence
--   will be retained and the duplicate occurrence removed.


-- Investigation 19: Inspect columns for completeness
-- Purpose:
-- Count NULL values in all eight columns and blank or whitespace-only values
-- in the seven VARCHAR columns to determine whether each field is complete.
SELECT
    COUNT(*) AS row_count,

    COUNT(*) FILTER (
        WHERE transaction_id IS NULL
    ) AS null_transaction_id_count,
    COUNT(*) FILTER (
        WHERE TRIM(transaction_id) = ''
    ) AS blank_transaction_id_count,

    COUNT(*) FILTER (
        WHERE project_id IS NULL
    ) AS null_project_id_count,
    COUNT(*) FILTER (
        WHERE TRIM(project_id) = ''
    ) AS blank_project_id_count,

    COUNT(*) FILTER (
        WHERE transaction_date IS NULL
    ) AS null_transaction_date_count,

    COUNT(*) FILTER (
        WHERE cost_category IS NULL
    ) AS null_cost_category_count,
    COUNT(*) FILTER (
        WHERE TRIM(cost_category) = ''
    ) AS blank_cost_category_count,

    COUNT(*) FILTER (
        WHERE vendor_name IS NULL
    ) AS null_vendor_name_count,
    COUNT(*) FILTER (
        WHERE TRIM(vendor_name) = ''
    ) AS blank_vendor_name_count,

    COUNT(*) FILTER (
        WHERE description IS NULL
    ) AS null_description_count,
    COUNT(*) FILTER (
        WHERE TRIM(description) = ''
    ) AS blank_description_count,

    COUNT(*) FILTER (
        WHERE amount IS NULL
    ) AS null_amount_count,
    COUNT(*) FILTER (
        WHERE TRIM(amount) = ''
    ) AS blank_amount_count,

    COUNT(*) FILTER (
        WHERE payment_status IS NULL
    ) AS null_payment_status_count,
    COUNT(*) FILTER (
        WHERE TRIM(payment_status) = ''
    ) AS blank_payment_status_count

FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - cost_transactions.csv contains 11,204 rows.
-- - project_id contains one NULL value and no blank or whitespace-only values.
-- - The remaining seven columns contain no NULL values.
-- - All seven VARCHAR columns contain no blank or whitespace-only values.
-- - The missing project_id requires targeted inspection because the associated
--   transaction cannot currently be assigned to a project, potentially
--   distorting project-level costs and profitability.


-- Investigation 19A: Inspect the transaction with a missing project_id
-- Purpose:
-- - Inspect the affected transaction’s remaining fields for evidence that
--   supports assigning it to a specific project.
-- - If the available evidence does not support a reliable assignment,
--   leave the project_id unresolved rather than inferring a value.
SELECT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE project_id IS NULL;

-- Findings:
-- - None of the remaining fields provides reliable evidence connecting
--   transaction TX000316 to a specific project.
-- - The vendor name and description are generic, while the date, category,
--   amount, and payment status do not identify a project.
-- - Preserve project_id as NULL in the cleaned cost_transactions output
--   because the project assignment remains unresolved.


-- Investigation 19B: Evaluate P003 as the probable project assignment
-- Purpose:
-- - Check whether project IDs occur in contiguous transaction_id blocks.
-- - Determine whether TX000316 falls within the block assigned to P003.
-- - Treat the ordering pattern as supporting internal evidence rather than
--   conclusive proof of the project assignment.
SELECT
    transaction_id,
    project_id,
    LAG(project_id) OVER (
        ORDER BY transaction_id
    ) AS previous_project_id
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE project_id IS NOT NULL
QUALIFY project_id IS DISTINCT FROM previous_project_id
ORDER BY transaction_id;

-- Findings:
-- - The dataset contains 97 distinct non-NULL project IDs and 101 project
--   block starts. P007, P014, P047, and P082 appear in multiple blocks.
-- - P003 begins at TX000236, and the next project block begins with P004
--   at TX000360. Therefore, TX000316 falls within P003's transaction range.
-- - The surrounding records also belong to P003, providing strong internal
--   evidence that the missing project_id should be P003.
-- - For this simulated client engagement, the client confirmed that
--   TX000316 belongs to P003.
-- - Assign P003 to TX000316 in the cleaned cost_transactions output while
--   preserving the original NULL in the immutable raw CSV.


-- Investigation 20: Profile amount formatting and numeric parseability
-- Purpose:
-- - Identify the formatting patterns that caused amount to be inferred
--   as VARCHAR rather than a numeric type.
-- - Check for currency symbols and thousands separators.
-- - Validate whether every populated value can be safely normalized and
--   converted to an appropriate monetary type.
SELECT *
    amount,
    TRY_CAST(amount AS DECIMAL(18, 2)) AS direct_parsed_amount
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE direct_parsed_amount IS NULL;

-- Findings:
-- - One populated amount associated with project P015 failed direct
--   conversion to DECIMAL(18, 2).
-- - The raw value is '$46.90'; the raw amount is not NULL, but TRY_CAST()
--   returned NULL because of the currency symbol.
-- - No other amount values failed direct conversion, and no failed values
--   contained thousands separators.
-- - The dollar sign likely caused amount to be inferred as VARCHAR.
-- - The proposed cleaning rule is to remove '$' with REPLACE() before
--   converting amount to a monetary numeric type.
-- - Validate the proposed normalization across all rows before finalizing
--   the cleaning rule and cleaned monetary type.


-- Investigation 20A: Validate amount normalization and numeric parseability
-- Purpose:
-- - Validate that removing the '$' currency symbol with REPLACE() allows
--   every populated amount value to parse successfully as DECIMAL(18, 2).
SELECT
    COUNT(*) AS row_count,
    SUM(
        CASE
            WHEN TRY_CAST(
                REPLACE(
                    REPLACE(amount, '$', ''),
                    ',',
                    ''
                ) AS DECIMAL(18, 2)
            ) IS NULL
            THEN 1
            ELSE 0
        END
    ) AS normalized_parse_failure_count
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - All 11,204 amount values were evaluated after normalization.
-- - The normalized parse failure count was 0, confirming that every value
--   can be converted successfully to DECIMAL(18, 2).
-- - The raw value '$46.90' became parseable after removing the currency symbol.
-- - In the cleaned cost_transactions output, remove '$' and ',' with
--   REPLACE() before converting amount to a monetary numeric type.
-- - DECIMAL(18, 2) was used for parseability testing; final type selection
--   still requires validation of amount range and precision.


-- Investigation 20B: Profile amount range, signs, and decimal precision
-- Purpose:
-- - Profile the minimum and maximum normalized amounts to determine the
--   required number of digits before the decimal point.
-- - Count zero and negative amounts that may represent credits, reversals,
--   or data anomalies requiring further inspection.
-- - Determine the decimal precision present in the source and validate
--   whether a two-decimal monetary type would preserve every value without
--   rounding.
WITH normalized AS (
    SELECT
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',',
                ''
            ) AS DECIMAL(18, 6)
        ) AS normalized_amount
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)
SELECT
    COUNT(*) AS row_count,
    MIN(normalized_amount) AS minimum_amount,
    MAX(normalized_amount) AS maximum_amount,
    COUNT(*) FILTER (
        WHERE normalized_amount = 0
    ) AS zero_amount_count,
    COUNT(*) FILTER (
        WHERE normalized_amount < 0
    ) AS negative_amount_count,
    COUNT(*) FILTER (
        WHERE normalized_amount <> ROUND(normalized_amount, 2)
    ) AS changed_by_two_decimal_rounding_count
FROM normalized;

-- Findings:
-- - All 11,204 normalized amount values were profiled.
-- - The observed range is -1,800.00 to 83,246.69.
-- - No zero amounts were found.
-- - Three negative amounts were found and require further investigation
--   before they can be classified as valid credits, reversals, or anomalies.
-- - The changed_by_two_decimal_rounding_count was 0, confirming that a
--   scale of two decimal places preserves every source amount.
-- - Use DECIMAL(10, 2) for amount in the cleaned cost_transactions output.
--   This allows eight digits before the decimal, provides headroom above
--   the current maximum, and is consistent with the proposed monetary
--   type for project_budgets.


-- Investigation 20C: Inspect negative amount transactions
-- Purpose:
-- - Inspect the three transactions with negative normalized amounts to determine
--   whether they represent valid refunds, credits, or corrections, or potential
--   data-quality issues.
-- - Use the findings to decide how these transactions should be handled in the
--   cleaned output and downstream cost analysis.
WITH normalized_data AS (
     SELECT
        transaction_id,
        project_id,
        transaction_date,
        cost_category,
        vendor_name,
        description,
        amount AS raw_amount,
        TRY_CAST(
                REPLACE(
                    REPLACE(amount, '$', ''),
                    ',',
                    ''
                ) AS DECIMAL(10, 2)
            ) AS normalized_amount,
        payment_status
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)
SELECT
    transaction_id,
        project_id,
        transaction_date,
        cost_category,
        vendor_name,
        description,
        raw_amount,
        normalized_amount,
        payment_status
FROM normalized_data
WHERE normalized_amount < 0
ORDER BY normalized_amount ASC;

-- Findings:
-- - Three transactions have negative normalized amounts: TX011201,
--   TX011202, and TX011203.
-- - Each transaction is a $1,800.00 material credit with the description
--   "Returned material credit" and a payment status of "applied."
-- - The consistent business context indicates that these are legitimate
--   credits rather than data-quality errors.
-- - Preserve the negative amounts in the cleaned output so the credits
--   correctly reduce their respective projects' material costs.
-- - The identical amounts and similar transaction details across three
--   projects are noteworthy and should be considered during the later
--   repeated-block investigation.


-- Investigation 20D: Relate negative credits to repeated project blocks
-- Purpose:
-- - Determine whether the negative credit transactions for P014, P047, and P082
--   caused those projects to appear in additional transaction blocks.
-- - Distinguish valid, separately recorded credits from potential project-ID or
--   transaction-order anomalies.
WITH transaction_sequence AS (
    SELECT
        transaction_id,
        project_id,
        LAG(project_id) OVER (
            ORDER BY transaction_id
        ) AS previous_project_id,
        description,
        amount AS raw_amount,
        TRY_CAST(
                REPLACE(
                    REPLACE(amount, '$', ''),
                    ',',
                    ''
                ) AS DECIMAL(10, 2)
            ) AS normalized_amount,
        payment_status
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    transaction_id,
    project_id,
    previous_project_id,
    description,
    raw_amount,
    normalized_amount,
    payment_status
FROM transaction_sequence
WHERE project_id IN (
    'P014', 'P047', 'P082'
)
    AND normalized_amount < 0
ORDER BY transaction_id;

-- Findings:
-- - The negative credit transactions for P014, P047, and P082 each have a
--   previous_project_id that differs from their current project_id.
-- - Therefore, each credit transaction begins an additional transaction block
--   for its respective project.
-- - These additional blocks represent legitimate returned-material credits
--   recorded separately from the projects' original transaction blocks, not
--   incorrect project assignments.
-- - The three credit transactions explain the repeated blocks for P014, P047,
--   and P082.
-- - P007 remains the only repeated project block requiring further investigation.


-- Investigation 20E: Inspect repeated transaction blocks for P007
-- Purpose:
-- - Identify the boundaries of each P007 transaction block when transactions
--   are ordered by transaction_id.
-- - Inspect the relevant transaction details and neighboring project IDs.
-- - Determine whether the second block represents a legitimate later transaction
--   or a potential data-quality issue.
WITH normalized_data AS (
    SELECT
        transaction_id,
        project_id,
        LAG(project_id) OVER (
            ORDER BY transaction_id
        ) AS previous_project_id,
        transaction_date,
        cost_category,
        vendor_name,
        description,
        amount AS raw_amount,
        TRY_CAST(
                REPLACE(
                    REPLACE(amount, '$', ''),
                    ',',
                    ''
                ) AS DECIMAL(10, 2)
            ) AS normalized_amount,
        payment_status
FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    transaction_id,
    project_id,
    previous_project_id,
    transaction_date,
    cost_category,
    vendor_name,
    description,
    raw_amount,
    normalized_amount,
    payment_status
FROM normalized_data
WHERE project_id = 'P007'
    AND previous_project_id IS DISTINCT FROM project_id
ORDER BY transaction_id;

-- Findings:
-- - TX000727 begins P007's original transaction block after P006.
-- - TX000730 begins a second P007 block because its immediately preceding
--   transaction belongs to P998.
-- - Therefore, P998 interrupts the P007 sequence and connects the repeated
--   P007 block with the unexpected P998 project ID.
-- - P998 must be inspected before determining whether either project ID
--   requires correction.


-- Investigation 20F: Inspect P998 and its neighboring transactions
-- Purpose:
-- - Inspect P998's transaction details and its position within the transaction
--   sequence to determine why it interrupts the P007 block.
-- - Determine whether P998 represents a legitimate project or a potentially
--   misassigned project ID.
WITH normalized_data AS (
    SELECT
        transaction_id,
        project_id,
        LAG(project_id) OVER (
            ORDER BY transaction_id
        ) AS previous_project_id,
        LEAD(project_id) OVER (
            ORDER BY transaction_id
        ) AS next_project_id,
        transaction_date,
        cost_category,
        vendor_name,
        description,
        amount AS raw_amount,
        TRY_CAST(
                REPLACE(
                    REPLACE(amount, '$', ''),
                    ',',
                    ''
                ) AS DECIMAL(10, 2)
            ) AS normalized_amount,
        payment_status
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    transaction_id,
    project_id,
    previous_project_id,
    next_project_id,
    transaction_date,
    cost_category,
    vendor_name,
    description,
    raw_amount,
    normalized_amount,
    payment_status
FROM normalized_data
WHERE project_id = 'P998'
ORDER BY transaction_id;

-- Findings:
-- - P998 appears once, on transaction TX000729.
-- - TX000729 is immediately preceded and followed by P007 transactions,
--   which explains why P007 appears in two separate blocks.
-- - The transaction is otherwise complete and resembles a normal paid
--   materials invoice.
-- - The surrounding sequence suggests that P998 may be a misassigned project
--   ID and that P007 is the leading correction candidate.
-- - Additional neighboring-row and cross-table evidence is required before
--   confirming a cleaned project-ID assignment.


-- Investigation 20F-A: Compare TX000729 with surrounding transactions
-- Purpose:
-- - Compare TX000729 with TX000727 through TX000731 for similarities in
--   project ID, transaction date, cost category, vendor, description, amount,
--   and payment status.
-- - Determine whether the surrounding transaction context supports or weakens
--   P007 as the candidate project ID for TX000729.
SELECT
    transaction_id,
    project_id,
    transaction_date,
    cost_category,
    vendor_name,
    description,
    amount,
    payment_status
FROM read_csv_auto('data/raw/cost_transactions.csv')
WHERE transaction_id BETWEEN 'TX000727' AND 'TX000731'
ORDER BY transaction_id;

-- Findings:
-- - TX000729 is surrounded by four transactions assigned to P007.
-- - All five transactions are Materials costs with a payment status of "paid."
-- - TX000729's date and amount fall within the range of the surrounding P007
--   transactions, and its materials-invoice description is consistent with them.
-- - The surrounding transaction context strongly supports P007 as the candidate
--   project ID for TX000729.
-- - Cross-table evidence is still required before confirming the cleaned assignment.


-- Investigation 20F-B: Check P998 across projects and budgets
-- Purpose:
-- - Determine whether P998 appears in projects.csv or project_budgets.csv.
-- - Use the result to assess whether P998 is a legitimate project or an invalid
--   project ID that should be assigned to P007 in the cleaned transactions.

-- Check projects.csv
SELECT
    COUNT(*) AS p998_project_row_count
FROM read_csv_auto('data/raw/projects.csv')
WHERE project_id = 'P998';

-- Findings:
-- - The row count is 0.

-- Check project_budgets.csv
SELECT
COUNT(*) AS p998_budget_row_count
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE project_id = 'P998';

-- Findings:
-- - The row count is 0.

-- Investigations 20F through 20F-B conclusion:
-- - P998 appears only once in cost_transactions.csv and is absent from both
--   projects.csv and project_budgets.csv.
-- - TX000729 interrupts an otherwise continuous P007 transaction block.
-- - Its date, cost category, description, amount, and payment status are
--   consistent with the surrounding P007 transactions.
-- - Within the simulated client scenario, assign TX000729 to P007 in the
--   cleaned cost-transactions output.
-- - Preserve P998 in the raw CSV and document the correction in the cleaning
--   rules and data-quality notes.


-- Investigation 21: Profile cost transaction categories
-- Purpose:
-- - Profile distinct cost_category values and their frequencies to identify
--   capitalization, spelling, and whitespace inconsistencies.
-- - Use the findings to define standardized categories that align with
--   project_budgets.csv.
SELECT
    cost_category,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/cost_transactions.csv')
GROUP BY cost_category
ORDER BY
    row_count DESC,
    cost_category;

-- Findings:
-- - Eight distinct raw cost-category values were observed.
-- - Six values are already canonical and account for 11,202 transactions.
-- - Two one-row variants require standardization.
-- - Standardize "Sub-Contractor" to "Subcontractors" and "materials " to
--   "Materials" in the cleaned output.
-- - Preserve the original category values in the raw CSV.


-- Investigation 22: Profile payment status values
-- Purpose:
-- - Profile distinct payment_status values and their frequencies to identify
--   capitalization, spelling, and whitespace inconsistencies.
-- - Use the findings to define standardized statuses and determine how each
--   status should be treated in project-cost analysis.
SELECT
    payment_status,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/cost_transactions.csv')
GROUP BY payment_status
ORDER BY
    row_count DESC,
    payment_status;

-- Findings:
-- - Six distinct raw cost-category values were observed.
-- - Four values are already canonical and account for 11,202 transactions.
-- - Two one-row variants require standardization.
-- - Standardize "PENDING" to "pending" and "Paid " to
--   "paid" in the cleaned output.
-- - Preserve the original category values in the raw CSV.


-- Investigation 23: Profile transaction date range
-- Purpose:
-- - Determine the earliest and latest transaction dates to establish the
--   dataset's period of coverage.
-- - Count transactions occurring after the June 30, 2026 reporting cutoff so
--   they can be excluded or investigated before reporting.
SELECT
    MIN(transaction_date) AS minimum_transaction_date,
    MAX(transaction_date) AS maximum_transaction_date,
    COUNT(*) FILTER (
        WHERE transaction_date > DATE '2026-06-30'
    ) AS transactions_after_cutoff
FROM read_csv_auto('data/raw/cost_transactions.csv');

-- Findings:
-- - Transaction dates range from January 28, 2023 through June 30, 2026.
-- - The latest transaction date falls exactly on the reporting cutoff.
-- - No transactions occur after the June 30, 2026 cutoff.
-- - The file-level date range is valid for reporting; project-level date
--   relationships will be validated separately.


-- Investigation 24: Profile vendor-name values
-- Purpose:
-- - Profile distinct vendor_name values and their frequencies to identify
--   capitalization, spelling, and whitespace inconsistencies.
-- - Define standardized vendor names so transactions from the same vendor are
--   grouped correctly in vendor-level cost analysis.
SELECT
    vendor_name,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/cost_transactions.csv')
GROUP BY vendor_name
ORDER BY
    row_count DESC,
    vendor_name;

-- Findings:
-- - Twenty-one distinct raw vendor-name values were observed.
-- - Their counts account for all 11,204 transactions.
-- - No apparent capitalization, spelling, or whitespace variants were identified.
-- - No suspicious one-row vendor values require targeted inspection.
-- - No vendor-name standardization mappings are currently required.
-- - Preserve the original vendor names in the raw CSV.


-- Investigation 25: Validate transaction project IDs against projects.csv
-- Purpose:
-- - Validate referential integrity by comparing every non-NULL project_id in
--   cost_transactions.csv with the master project IDs in projects.csv.
-- - Identify unmatched transaction project IDs that could prevent costs from
--   being assigned to valid projects, understating costs and overstating profitability.
-- - Exclude NULL project IDs because TX000316 was investigated separately and
--   will be assigned to P003 in the cleaned output. Preserve raw IDs during profiling
--   so P998 appears as unmatched before TX000729 is reassigned to P007 during cleaning.
SELECT DISTINCT
    ct.project_id AS unmatched_project_id
FROM read_csv_auto('data/raw/cost_transactions.csv') AS ct
LEFT JOIN read_csv_auto('data/raw/projects.csv') AS p
    ON ct.project_id = p.project_id
WHERE ct.project_id IS NOT NULL
  AND p.project_id IS NULL
ORDER BY unmatched_project_id;

-- Findings:
-- - One unmatched non-NULL transaction project_id was identified: P998.
-- - This confirms that P998 is absent from the project master. Prior investigation
--   linked P998 to TX000729 and established its reassignment to P007 in cleaned output.


-- Investigation 26: Determine how payment statuses should affect cost metrics
-- Purpose:
-- - Quantify the financial exposure associated with each standardized payment status
--   by calculating its transaction count and net transaction amount.
-- - Evaluate how including or excluding approved and pending transactions would
--   affect reported project costs and profitability.
-- - Support a transparent, documented payment-status inclusion rule for the final analysis.
WITH standardized_data AS (
    SELECT
        LOWER(TRIM(payment_status)) AS standardized_payment_status,
    CAST(
                    REPLACE(
                        REPLACE(amount, '$', ''),
                        ',',
                        ''
                    ) AS DECIMAL(10, 2)
                ) AS normalized_amount
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)
SELECT
    standardized_payment_status,
    COUNT(*) AS transaction_count,
    SUM(normalized_amount) AS net_amount
FROM standardized_data
GROUP BY standardized_payment_status
ORDER BY net_amount DESC;

-- Findings:
-- - All 11,204 transactions consolidate into four standardized payment statuses.
-- - LOWER(TRIM(payment_status)) is required because one pending value contains
--   trailing whitespace.
-- - Paid, approved, and applied transactions have a combined net amount of
--   $80,483,260.36.
-- - Pending transactions have a net amount of $7,961,647.60.
-- - All payment statuses have a combined net amount of $88,444,907.96.
--
-- Decision:
-- - Include paid and approved transactions in incurred project cost.
-- - Include applied credits as negative incurred costs so they reduce project cost.
-- - Exclude pending transactions from incurred cost and report them separately as
--   pending cost exposure.
-- - Report maximum cost exposure as incurred cost plus pending cost exposure.
-- - Do not assign an approval probability to pending transactions because the
--   dataset does not contain transaction-status history.


-- Investigation 27: Validate cost transactions against project budgets
-- Purpose:
-- - Validate composite referential integrity by comparing each transaction's
--   project_id and cost_category pair with the corresponding pair in
--   project_budgets.csv.
-- - Identify unmatched transaction pairs that could cause actual costs to be
--   omitted from category-level budget-versus-actual calculations, understating
--   actual costs and potentially hiding budget overruns.
SELECT DISTINCT
    ct.project_id AS unmatched_project_id,
    ct.cost_category AS unmatched_cost_category
FROM read_csv_auto('data/raw/cost_transactions.csv') AS ct
LEFT JOIN read_csv_auto('data/raw/project_budgets.csv') AS pb
    ON ct.project_id = pb.project_id
    AND ct.cost_category = pb.cost_category
WHERE ct.project_id IS NOT NULL
  AND pb.budget_line_id IS NULL
ORDER BY
    unmatched_project_id,
    unmatched_cost_category;

-- Findings:
-- - Six unmatched non-NULL transaction project/category pairs were identified.
-- - P008 + materials and P011 + Sub-Contractor contain known transaction-side
--   category variants that require standardization.
-- - P998 + Materials results from the known incorrect project_id on TX000729,
--   which will be reassigned to P007 in the cleaned output.
-- - P019 + Materials, P044 + Subcontractors, and P071 + General Conditions use
--   canonical transaction categories but lack exact raw matches in project_budgets.csv.
-- - The budget-side category values for these three pairs require further inspection
--   before their mismatches can be classified as standardization issues.


-- Investigation 27A: Inspect budget categories for canonical transaction mismatches
-- Purpose:
-- - Inspect the raw cost_category values in project_budgets.csv for P019, P044,
--   and P071.
-- - Determine whether their unmatched transaction pairs result from budget-side
--   formatting inconsistencies or genuinely missing budget lines.
SELECT
    project_id,
    cost_category
FROM read_csv_auto('data/raw/project_budgets.csv')
WHERE project_id IN ('P019', 'P044', 'P071')
ORDER BY
    project_id,
    cost_category;

-- Findings:
-- - P019 contains a Materials budget category with trailing whitespace.
-- - P044 uses Sub-Contractors instead of the canonical Subcontractors category.
-- - P071 uses General conditions instead of the canonical General Conditions category.
-- - All three budget lines exist; their raw transaction pairs failed to match because
--   of budget-side formatting inconsistencies rather than missing budget lines.


-- Investigation 27B: Validate standardized transaction-to-budget relationships
-- Purpose:
-- - Apply all documented project_id and category corrections with temporary
--   CTEs, repeat the compostie relationship check, and verify that no unmatched
--   pairs remain.
WITH standardized_cost_transactions AS (
    SELECT
        transaction_id,
        CASE transaction_id
            WHEN 'TX000316' THEN 'P003'
            WHEN 'TX000729' THEN 'P007'
            ELSE project_id
        END AS standardized_project_id,
        CASE LOWER(TRIM(cost_category))
            WHEN 'general conditions' THEN 'General Conditions'
            WHEN 'labor' THEN 'Labor'
            WHEN 'materials' THEN 'Materials'
            WHEN 'sub-contractor' THEN 'Subcontractors'
            WHEN 'sub-contractors' THEN 'Subcontractors'
            WHEN 'subcontractors' THEN 'Subcontractors'
            ELSE TRIM(cost_category)
        END AS standardized_cost_category
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

standardized_project_budgets AS (
    SELECT
        budget_line_id,
        project_id AS standardized_project_id,
        CASE LOWER(TRIM(cost_category))
            WHEN 'general conditions' THEN 'General Conditions'
            WHEN 'labor' THEN 'Labor'
            WHEN 'materials' THEN 'Materials'
            WHEN 'sub-contractor' THEN 'Subcontractors'
            WHEN 'sub-contractors' THEN 'Subcontractors'
            WHEN 'subcontractors' THEN 'Subcontractors'
            ELSE TRIM(cost_category)
        END AS standardized_cost_category
    FROM read_csv_auto('data/raw/project_budgets.csv')
)

SELECT DISTINCT
    ct.standardized_project_id AS unmatched_project_id,
    ct.standardized_cost_category AS unmatched_cost_category
FROM standardized_cost_transactions AS ct
LEFT JOIN standardized_project_budgets AS pb
    ON ct.standardized_project_id = pb.standardized_project_id
   AND ct.standardized_cost_category = pb.standardized_cost_category
WHERE pb.budget_line_id IS NULL
ORDER BY
    unmatched_project_id,
    unmatched_cost_category;

-- Findings:
-- - The standardized relationship check returned zero unmatched transaction
--   project/category pairs.
-- - All six raw mismatches were resolved by the documented project-ID and
--   cost-category corrections.
--
-- Decision:
-- - Apply the documented corrections only in the cleaned analytical layer and
--   preserve all raw CSV values unchanged.
-- - Use standardized project_id and cost_category pairs when joining transactions
--   to budget lines for category-level budget-versus-actual analysis.
-- Purpose:
-- Apply documented cost_transactions.csv cleaning rules to produce
-- a reusable cleaned cost-transactions dataset.

-- Grain:
-- One row per transaction_id.

-- Cleaning rules:
-- 1. Retain one occurrence of the exact TX000138 duplicate.
-- 2. Preserve raw columns and add cleaned fields for transformed values.
-- 3. Apply documented transaction-specific project-ID corrections:
--    TX000316: missing project_id -> P003.
--    TX000729: P998 -> P007.
-- 4. Standardize cost categories using the documented mappings:
--    Sub-Contractor -> Subcontractors
--    materials [trailing space] -> Materials
-- 5. Remove dollar signs and commas from amount values,
--    then convert to DECIMAL(10, 2).
-- 6. Standardize payment_status using LOWER(TRIM(payment_status)).
-- 7. Preserve negative applied credits.

-- Exception handling:
-- 1. Keep source project IDs visible and flag corrected records.
-- 2. Apply project-ID corrections only to the specified transactions.
-- 3. Validate cleaned project IDs against cleaned projects and cleaned
--    project/category pairs against cleaned budgets.

-- Reporting treatment:
-- Paid and approved transactions, plus negative applied credits,
-- form net incurred cost.
-- Report pending transactions separately as pending cost exposure.
-- Maximum cost exposure = net incurred cost + pending cost exposure.
-- Do not assign approval probabilities to pending transactions.

-- Expected results:
-- 11203 rows after removing one exact duplicate.
-- Each transaction_id appears once.
-- Exactly two transaction-specific project-ID corrections.
-- Zero missing or unmatched cleaned project IDs.
-- Zero unmatched cleaned project/category pairs against cleaned budgets.
-- All populated source amounts convert successfully to DECIMAL(10, 2).
-- Three applied credits remain at -1800.00 each.
-- Standardized payment statuses: paid, approved, pending, applied.
-- Recalculate reporting totals from deduplicated data.


-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Cleaning step 1: Remove exact duplicate rows while preserving all raw columns.
-- Expected: 11203 rows and 11203 distinct transaction_id values.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    COUNT(*) AS row_count,
    COUNT(distinct transaction_id) AS total_unique_transaction_ids
FROM deduplicated;

-- PASS: 11203 rows and 11203 distinct transaction IDs.


-- Cleaning step 2: Preserve raw project_id and add project_id_clean.
-- Assign TX000316 to P003 and TX000729 to P007.
-- Keep all other project IDs unchanged.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    *,
    CASE
        WHEN transaction_id = 'TX000316' THEN 'P003'
        WHEN transaction_id = 'TX000729' THEN 'P007'
        ELSE project_id
        END AS project_id_clean
FROM deduplicated;

-- PASS: TX000316 maps from NULL to P003; TX000729 maps from P998 to P007.
-- Raw project IDs remain unchanged.


-- Add project_id_corrected_flag to identify the two documented corrections.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    *,
    CASE
        WHEN transaction_id = 'TX000316' THEN 'P003'
        WHEN transaction_id = 'TX000729' THEN 'P007'
        ELSE project_id
        END AS project_id_clean,
        transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag
FROM deduplicated;


-- Cleaning step 3: Preserve raw cost_category and add cost_category_clean.
-- Standardize Sub-Contractor to Subcontractors and materials to Materials.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)
SELECT
    cost_category,
    CASE
        WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
            THEN 'Subcontractors'
        WHEN LOWER(TRIM(cost_category)) = 'materials'
            THEN 'Materials'
        ELSE TRIM(cost_category)
        END AS cost_category_clean
FROM deduplicated;


-- Cleaning step 4: Normalize and convert amount.
-- Remove dollar signs and thousands separators, then safely cast to DECIMAL(10, 2).
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    amount,
    TRY_CAST(
        REPLACE(
            REPLACE(amount, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS amount_clean
FROM deduplicated;


-- Cleaning step 5: Standardize payment_statuses.
-- Use LOWER(TRIM(payment_status)) and preserve raw values for traceability.
WITH deduplicated AS (
    SELECT DISTINCT *
FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    payment_status,
    LOWER(TRIM(payment_status)) AS payment_status_clean
FROM deduplicated;


-- Cleaning step 6: Combine transformations and exception flags.
-- Deduplicate the source rows, then apply cleaning rules.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
)

SELECT
    *,
    CASE
        WHEN transaction_id = 'TX000316' THEN 'P003'
        WHEN transaction_id = 'TX000729' THEN 'P007'
        ELSE project_id
        END AS project_id_clean,
        transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
    CASE
        WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
            THEN 'Subcontractors'
        WHEN LOWER(TRIM(cost_category)) = 'materials'
            THEN 'Materials'
        ELSE TRIM(cost_category)
        END AS cost_category_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(amount, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS amount_clean,
    LOWER(TRIM(payment_status)) AS payment_status_clean
FROM deduplicated;


-- Validation 1: Confirm the grain is still one row per transaction.
-- Expected: 11,203 total rows and 11,203 distinct transaction IDs.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT transaction_id) AS unique_transaction_ids
FROM cleaned_cost_transactions;

-- PASS: 11,203 rows and 11,203 distinct transaction Ids.


-- Validation 2: Inspect transactions flagged for project ID correction.
-- Expected: Only TX000316 → P003 and TX000729 → P007.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT *
FROM cleaned_cost_transactions
WHERE project_id_corrected_flag = TRUE;


-- Validation 3: Confirm corrected-flag counts.
-- Expected: 2 TRUE and 11,201 FALSE.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    project_id_corrected_flag,
    COUNT(*) AS row_count
FROM cleaned_cost_transactions
GROUP BY project_id_corrected_flag;

-- PASS: 2 TRUE and 11,201 FALSE.


-- Validation 4: Check for amount conversion failures.
-- Expected: Zero rows with a populated raw amount and a NULL cleaned amount.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT *
FROM cleaned_cost_transactions
WHERE amount IS NOT NULL
  AND amount_clean IS NULL;

-- PASS: Zero rows with a populated raw amount and a NULL cleaned amount.


-- Validation 5: Check cleaned payment statuses and their counts.
-- Expected: paid, approved, pending, and applied summing to 11,203.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    payment_status,
    payment_status_clean,
    COUNT(*) AS row_count,
    SUM(COUNT(*)) OVER() AS total_rows

FROM cleaned_cost_transactions
GROUP BY
    payment_status_clean,
    payment_status;

-- PASS: 4 fields equaling 11,203.


-- Validation 6: Inspect the cleaned cost categories.
-- Expected: 'Sub-Contractor' to 'Subcontractors' and 'materials' to 'Materials'.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    cost_category,
    cost_category_clean,
    COUNT(*) AS row_count,
    SUM(COUNT(*)) OVER() AS total_rows
FROM cleaned_cost_transactions
GROUP BY
    cost_category_clean,
    cost_category
ORDER BY
    cost_category_clean,
    cost_category;

-- PASS: 6 fields 11,203 total.


-- Validation 7: Check that negative applied credits are preserved.
-- Expected: Three applied-credit rows, each with a negative amount_clean matching the raw amount.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    transaction_id,
    amount,
    amount_clean,
    payment_status_clean
FROM cleaned_cost_transactions
WHERE payment_status_clean = 'applied';

-- PASS: All three applied credits retain −1,800.00, totaling −5,400.00.


-- Validation 8: Check that every cleaned project ID matches a prject in
-- construction.cleaned_projects.
-- Expected: Zero mismatches.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    c.project_id,
    p.project_id,
    c.project_id_clean,
    c.transaction_id
FROM cleaned_cost_transactions AS c
LEFT JOIN construction.cleaned_projects AS p
    ON c.project_id_clean = p.project_id
WHERE p.project_id IS NULL;

-- PASS: Every cleaned project ID matches a project.


-- Validation 9: Summarize cleaned cost totals by payment status.
-- Expected: Four status groups totaling 11,203 transactions.
-- Paid, approved, and applied amounts form incurred cost; pending stays separate.
-- Applied credits should total -5,400.00.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT
    payment_status_clean,
    COUNT(*) AS row_count,
    SUM(amount_clean) AS total_amount
FROM cleaned_cost_transactions
GROUP BY payment_status_clean;

-- PASS: four status groups totaling 11,203 transactions,
-- with applied credits totaling −5,400.00.


-- Validation 10: Reconcile incurred cost and pending exposure to the full cleaned total.
-- Expected: Full cleaned total minus incurred cost minus pending exposure equals 0.00.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
),

cost_totals AS (
    SELECT
        SUM(amount_clean) AS full_cleaned_total,
        SUM(
            CASE
                WHEN payment_status_clean IN ('paid', 'approved', 'applied')
                THEN amount_clean
            ELSE 0
        END
        ) AS incurred_cost,
        SUM(
            CASE
                WHEN payment_status_clean = 'pending'
                THEN amount_clean
            ELSE 0
        END
        ) AS pending_exposure
    FROM cleaned_cost_transactions
)

SELECT
    full_cleaned_total,
    incurred_cost,
    pending_exposure,
    full_cleaned_total - (incurred_cost + pending_exposure) AS reconciliation_difference
FROM cost_totals;

-- PASS: Incurred cost plus pending exposure equals the full cleaned total, with a 0.00 difference.


-- Create the reusable cleaned_cost_transactions view.
-- Preserve raw values, cleaned fields, and data quality flags.
-- Open and select the persistent project database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Save the cleaned cost transactions view with raw columns and the correction flag.
CREATE OR REPLACE VIEW construction.cleaned_cost_transactions AS
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/cost_transactions.csv')
),

cleaned_cost_transactions AS (
    SELECT
        *,
        CASE
            WHEN transaction_id = 'TX000316' THEN 'P003'
            WHEN transaction_id = 'TX000729' THEN 'P007'
            ELSE project_id
            END AS project_id_clean,
            transaction_id IN ('TX000316', 'TX000729') AS project_id_corrected_flag,
        CASE
            WHEN LOWER(TRIM(cost_category)) = 'sub-contractor'
                THEN 'Subcontractors'
            WHEN LOWER(TRIM(cost_category)) = 'materials'
                THEN 'Materials'
            ELSE TRIM(cost_category)
            END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(amount, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
        ) AS amount_clean,
        LOWER(TRIM(payment_status)) AS payment_status_clean
    FROM deduplicated
)

SELECT *
FROM cleaned_cost_transactions;


-- Verify the saved view's row count and unique transaction IDs.
-- Expected: 11,203 rows and 11,203 distinct transaction IDs.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT transaction_id) AS distinct_transaction_ids
FROM construction.cleaned_cost_transactions;

-- PASS: Saved view returns 11,203 rows and 11,203 unique transactio IDs.
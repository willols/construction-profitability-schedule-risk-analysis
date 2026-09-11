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
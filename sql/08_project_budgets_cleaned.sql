-- Purpose:
-- Apply the documented cleaning rules established during project_budgets.csv
-- profiling to produce a reusable cleaned project_budgets dataset.

-- Grain:
-- One row per project and standardized cost category,
-- identified by budget_line_id.

-- Cleaning rules:
-- 1. Retain one occurrence of the exact BUD-P031-01 duplicate.
-- 2. Preserve raw cost_category values and produce a cleaned category
--    using the documented mappings:
--    General conditions -> General Conditions
--    Materials [trailing space] -> Materials
--    labor -> Labor
--    Sub-Contractors -> Subcontractors
-- 3. Remove dollar signs and commas from approved_budget_change
--    before numeric conversion.
-- 4. Convert cleaned monetary fields to DECIMAL(10, 2).

-- Exception handling:
-- 1. Preserve the source NULL in BUD-P057-04's original_budget_amount.
--    If the formula-derived 31672.00 candidate is used, expose it
--    separately and flag it as inferred.
-- 2. Preserve BUD-P997-01 and its source project_id P997.
--    Flag it as an orphan requiring stakeholder clarification.
--    Do not replace its project_id without authoritative evidence.
-- 3. Reconcile the orphan's budget separately from budgets linked
--    to known projects.

-- Expected results:
-- 673 rows after removing one exact duplicate.
-- Each budget_line_id appears once.
-- Documented category variants are standardized.
-- Cleaned monetary fields use DECIMAL(10, 2).
-- The missing original budget and orphan project remain visible.

-- Open and select the persistent project database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;

-- Cleaning step 1. Remove exact duplicate rows.
-- Use DISTINCT across all columns to retain one copy of each unique row.
SELECT DISTINCT *
FROM read_csv_auto('data/raw/project_budgets.csv');


-- Cleaning step 2: Standardize cost_category.
-- Normalize case and surrounding whitespace, then map
-- General conditions to General Conditions, Materials [trailing space] to Materials,
-- labor to Labor, and Sub-Contractors to Subcontractors
SELECT
    cost_category,
    CASE
        WHEN LOWER(TRIM(cost_category)) = 'general conditions'
            THEN 'General Conditions'
        WHEN LOWER(TRIM(cost_category)) = 'materials'
            THEN 'Materials'
        WHEN LOWER(TRIM(cost_category)) = 'labor'
            THEN 'Labor'
        WHEN LOWER(TRIM(cost_category)) = 'sub-contractors'
            THEN 'Subcontractors'
        ELSE TRIM(cost_category)
    END AS cost_category_clean
FROM read_csv_auto('data/raw/project_budgets.csv');


-- Cleaning step 3: Normalize and convert approved_budget_change.
-- Remove dollar signs and thousands separators, then safely cast to DECIMAL(10, 2).
SELECT
    approved_budget_change,
    TRY_CAST(
        REPLACE(
            REPLACE(approved_budget_change, '$', ''),
            ',','' ) AS DECIMAL(10, 2)
    ) AS approved_budget_change_clean
FROM read_csv_auto('data/raw/project_budgets.csv');


-- Cleaning step 4: Safely convert original_budget_amount and revised_budget_amount
-- to DECIMAL (10, 2)
-- Preserve the raw value for traceability.
SELECT
    original_budget_amount,
    TRY_CAST(original_budget_amount AS DECIMAL (10, 2)) AS  original_budget_amount_clean,
    revised_budget_amount,
    TRY_CAST(revised_budget_amount AS DECIMAL (10, 2)) AS revised_budget_amount_clean
FROM read_csv_auto('data/raw/project_budgets.csv');


-- Cleaning step 5: Flag missing source original-budget amounts.
-- Preserve the source NULL and make the missing value visible.
SELECT
    budget_line_id,
    original_budget_amount,
    original_budget_amount IS NULL AS original_budget_missing_flag
FROM read_csv_auto('data/raw/project_budgets.csv');


-- Cleaning step 6: Flag budget rows with no matching project
-- in construction.cleaned_projects.
-- Preserve the source project_id and budget row for clarification
-- and separate budget reconciliation.
SELECT
    b.budget_line_id,
    b.project_id,
    p.project_id IS NULL AS orphan_project_flag
FROM read_csv_auto('data/raw/project_budgets.csv') AS b
LEFT JOIN construction.cleaned_projects AS p
    ON b.project_id = p.project_id;


-- Cleaning step 7: Combine transformations and exception flags.
-- Deduplicate the source rows, then apply cleaning rules
-- and retain all budget rows when matching to cleaned projects.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
)
SELECT
    b.*,
    CASE
        WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
            THEN 'General Conditions'
        WHEN LOWER(TRIM(b.cost_category)) = 'materials'
            THEN 'Materials'
        WHEN LOWER(TRIM(b.cost_category)) = 'labor'
            THEN 'Labor'
        WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
            THEN 'Subcontractors'
        ELSE TRIM(b.cost_category)
    END AS cost_category_clean,
    TRY_CAST(
        REPLACE(
            REPLACE(b.approved_budget_change, '$', ''),
            ',', ''
        ) AS DECIMAL(10, 2)
    ) AS approved_budget_change_clean,
    TRY_CAST(
        b.original_budget_amount AS DECIMAL(10, 2)
    ) AS original_budget_amount_clean,
    TRY_CAST(
        b.revised_budget_amount AS DECIMAL(10, 2)
    ) AS revised_budget_amount_clean,
    b.original_budget_amount IS NULL AS original_budget_missing_flag,
    p.project_id IS NULL AS orphan_project_flag
FROM deduplicated AS b
LEFT JOIN construction.cleaned_projects AS p
    ON b.project_id = p.project_id;


-- Validation 1: Confirm the cleaned row count and budget-line uniqueness.
-- Expected: 673 rows and 673 distinct budget_line_id values.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),
cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT budget_line_id) AS unique_budget_line_ids
FROM cleaned_project_budgets;

-- PASS: 673 rows and 673 distinct budget_line_id values.


-- Validation 2: Verify the cost category mapping.
-- Expected: Equipment, General Conditions, Materials, Labor,
-- Subcontractors, Other, and Permits & Fees
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),
cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT DISTINCT
    cost_category,
    cost_category_clean
FROM cleaned_project_budgets
ORDER BY cost_category_clean, cost_category;

-- PASS: All documented category mappings are correct.
-- Seven standardized categories remain; other valid labels are preserved.


-- Validation 3: Check for monetary conversion failures.
-- Expected: Zero cases where a populated raw value becomes NULL after conversion.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),
cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT *
FROM cleaned_project_budgets
WHERE (
    approved_budget_change IS NOT NULL
    AND approved_budget_change_clean IS NULL
)
OR (
    original_budget_amount IS NOT NULL
    AND original_budget_amount_clean IS NULL
)
OR (
    revised_budget_amount IS NOT NULL
    AND revised_budget_amount_clean IS NULL
);

-- PASS: Zero conversion failures across all three monetary fields.


-- Validation 4: confirm BUD-P057-04’s source NULL is preserved and flagged
-- Expected: Only BUD-P057-04, with raw and cleaned original-budget
-- amounts both NULL and original_budget_missing_flag = TRUE.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),
cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT
    budget_line_id,
    original_budget_amount,
    original_budget_amount_clean,
    original_budget_missing_flag
FROM cleaned_project_budgets
WHERE original_budget_missing_flag = TRUE;

-- PASS: Only BUD-P057-04 is flagged; its raw and cleaned
-- original-budget amounts are both NULL.


-- Validation 5: Verify the orphan project_id P997.
-- Expected: Only BUD-P997-01, with project_id P997
-- and orphan_project_flag = TRUE.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),
cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT
    budget_line_id,
    project_id,
    orphan_project_flag
FROM cleaned_project_budgets
WHERE orphan_project_flag = TRUE;

-- PASS: Only BUD-P997-01 is flagged as an orphan;
-- its source project_id P997 is preserved.


-- Validation 6: Verify the three cleaned monetary fields are DECIMAL(10, 2).
-- Expected: All three cleaned monetary types to be DECIMAL(10, 2).
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),
cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT DISTINCT
    TYPEOF(approved_budget_change_clean),
    TYPEOF(original_budget_amount_clean),
    TYPEOF(revised_budget_amount_clean)
FROM cleaned_project_budgets;

-- PASS: All three cleaned monetary fields are DECIMAL(10, 2).


-- Validation 7: Budget-total reconciliation.
-- Compare deduplicated-source and cleaned totals for original_budget_amount,
-- approved_budget_change, and revised_budget_amount; expect zero differences.
-- Confirm matched-project totals + orphan totals = full cleaned totals.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),

cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
),

source_totals AS (
    SELECT
        SUM(TRY_CAST(original_budget_amount AS DECIMAL(10, 2)))
            AS source_original_budget_total,
        SUM(
            TRY_CAST(
                REPLACE(
                    REPLACE(approved_budget_change, '$', ''),
                    ',', ''
                ) AS DECIMAL(10, 2)
            )
        ) AS source_approved_budget_change_total,
        SUM(TRY_CAST(revised_budget_amount AS DECIMAL(10, 2)))
            AS source_revised_budget_total
    FROM deduplicated
),

cleaned_totals AS (
    SELECT
        SUM(original_budget_amount_clean)
            AS cleaned_original_budget_total,
        SUM(approved_budget_change_clean)
            AS cleaned_approved_budget_change_total,
        SUM(revised_budget_amount_clean)
            AS cleaned_revised_budget_total
    FROM cleaned_project_budgets
),

matched_totals AS (
    SELECT
        SUM(original_budget_amount_clean)
            AS matched_original_budget_total,
        SUM(approved_budget_change_clean)
            AS matched_approved_budget_change_total,
        SUM(revised_budget_amount_clean)
            AS matched_revised_budget_total
    FROM cleaned_project_budgets
    WHERE orphan_project_flag = FALSE
),

orphan_totals AS (
    SELECT
        SUM(original_budget_amount_clean)
            AS orphan_original_budget_total,
        SUM(approved_budget_change_clean)
            AS orphan_approved_budget_change_total,
        SUM(revised_budget_amount_clean)
            AS orphan_revised_budget_total
    FROM cleaned_project_budgets
    WHERE orphan_project_flag = TRUE
),

reconciliation AS (
    SELECT
        1 AS field_order,
        'original_budget_amount' AS monetary_field,
        s.source_original_budget_total AS source_total,
        c.cleaned_original_budget_total AS cleaned_total,
        m.matched_original_budget_total AS matched_total,
        o.orphan_original_budget_total AS orphan_total
    FROM source_totals AS s
    CROSS JOIN cleaned_totals AS c
    CROSS JOIN matched_totals AS m
    CROSS JOIN orphan_totals AS o

    UNION ALL

    SELECT
        2,
        'approved_budget_change',
        s.source_approved_budget_change_total,
        c.cleaned_approved_budget_change_total,
        m.matched_approved_budget_change_total,
        o.orphan_approved_budget_change_total
    FROM source_totals AS s
    CROSS JOIN cleaned_totals AS c
    CROSS JOIN matched_totals AS m
    CROSS JOIN orphan_totals AS o

    UNION ALL

    SELECT
        3,
        'revised_budget_amount',
        s.source_revised_budget_total,
        c.cleaned_revised_budget_total,
        m.matched_revised_budget_total,
        o.orphan_revised_budget_total
    FROM source_totals AS s
    CROSS JOIN cleaned_totals AS c
    CROSS JOIN matched_totals AS m
    CROSS JOIN orphan_totals AS o
)

SELECT
    monetary_field,
    source_total,
    cleaned_total,
    cleaned_total - source_total AS cleaning_difference,
    matched_total,
    orphan_total,
    cleaned_total - (matched_total + orphan_total) AS split_difference
FROM reconciliation
ORDER BY field_order;

-- PASS: All three source and cleaned totals match; matched + orphan totals
-- equal full cleaned totals. Orphan amounts: 42000.00 original,
-- 0.00 approved change, and 42000.00 revised.


-- Create the reusable cleaned_budget view.
-- Preserve raw values, cleaned fields, and data quality flags.
-- Open and select the persistent project database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;

-- Save the cleaned budgets view with raw columns and exception flags.
CREATE OR REPLACE VIEW construction.cleaned_project_budgets AS

WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/project_budgets.csv')
),

cleaned_project_budgets AS (
    SELECT
        b.*,
        CASE
            WHEN LOWER(TRIM(b.cost_category)) = 'general conditions'
                THEN 'General Conditions'
            WHEN LOWER(TRIM(b.cost_category)) = 'materials'
                THEN 'Materials'
            WHEN LOWER(TRIM(b.cost_category)) = 'labor'
                THEN 'Labor'
            WHEN LOWER(TRIM(b.cost_category)) = 'sub-contractors'
                THEN 'Subcontractors'
            ELSE TRIM(b.cost_category)
        END AS cost_category_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(b.approved_budget_change, '$', ''),
                ',', ''
            ) AS DECIMAL(10, 2)
        ) AS approved_budget_change_clean,
        TRY_CAST(
            b.original_budget_amount AS DECIMAL(10, 2)
        ) AS original_budget_amount_clean,
        TRY_CAST(
            b.revised_budget_amount AS DECIMAL(10, 2)
        ) AS revised_budget_amount_clean,
        b.original_budget_amount IS NULL AS original_budget_missing_flag,
        p.project_id IS NULL AS orphan_project_flag
    FROM deduplicated AS b
    LEFT JOIN construction.cleaned_projects AS p
        ON b.project_id = p.project_id
)

SELECT *
FROM cleaned_project_budgets;


-- Verify the saved view's row count and unique budget-line IDs.
-- Expected: 673 rows and 673 distinct budget_line IDs.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT budget_line_id) AS distinct_budget_line_ids
FROM construction.cleaned_project_budgets;

-- PASS: Saved view returns 673 rows and 673 distinct budget-line IDs.
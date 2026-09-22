-- Purpose:
-- Apply documented cleaning rules to change_orders.csv
-- to create a reusable view for change-order and profitability analysis.

-- Grain:
-- One row per change order.
-- change_order_id uniquely identifies each row after exact duplicate removal.

-- Cleaning rules:
-- 1. Remove exact duplicate rows, retaining one CO0013 record.
-- 2. Standardize status using LOWER(TRIM(status)).
-- 3. Remove dollar signs and commas from requested_revenue_change
--    before converting to DECIMAL(10,2).
-- 4. Convert estimated_cost_change, approved_revenue_change,
--    and billed_amount to DECIMAL(10,2).
-- 5. Flag change orders with no matching project in cleaned_projects.
-- 6. Flag approved change orders with a missing approval date.
-- 7. Preserve change_order_type and reason without standardization.

-- Source preservation:
-- Leave the raw CSV unchanged.
-- Retain original columns alongside cleaned values and exception flags.
-- Preserve recorded zeros, NULLs, and negative monetary values.

-- Exception handling:
-- Preserve CO9999's unmatched project_id P994 and flag the record.
-- Do not assign a replacement project ID without authoritative evidence.
-- Preserve CO0001's missing approval date and flag the record.
-- Do not infer an approval date.

-- Reporting boundary:
-- Preserve CO0119's billed amount and post-cutoff billing date.
-- Apply reporting-cutoff treatment in the analytical layer.
-- Preserve requested/approved differences and partial billing
-- as business observations, not cleaning errors.


-- Attach the project database and set it as the active database.
ATTACH IF NOT EXISTS 'construction.duckdb' AS construction;
USE construction;


-- Implement documented change-order cleaning rules.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
)

SELECT
    co.*,
    (p.project_id IS NULL) AS unmatched_project_id_flag,
    (co.status_clean = 'approved' AND co.approval_date IS NULL)
      AS approved_missing_approval_date_flag
FROM cleaned_change_orders AS co
LEFT JOIN construction.cleaned_projects AS p
    ON co.project_id = p.project_id;


-- Validation 1: Confirm one row per change order after cleaning and joining.
-- Expected: 145 rows and 145 distinct change_order_id values.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT change_order_id) AS unique_change_order_id_count
FROM final_output;

-- PASS: Total count and change order id count are both 145.


-- Validation 2: Check monetary conversion failures and exception flag counts.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT
    COUNT(*) FILTER (
        WHERE requested_revenue_change IS NOT NULL
          AND requested_revenue_change_clean IS NULL
    ) AS requested_revenue_change_conversion_failure,
    COUNT(*) FILTER (
        WHERE estimated_cost_change IS NOT NULL
          AND estimated_cost_change_clean IS NULL
    ) AS estimated_cost_change_conversion_failure,
    COUNT(*) FILTER (
        WHERE approved_revenue_change IS NOT NULL
          AND approved_revenue_change_clean IS NULL
    ) AS approved_revenue_change_conversion_failure,
    COUNT(*) FILTER (
        WHERE billed_amount IS NOT NULL
          AND billed_amount_clean IS NULL
    ) AS billed_amount_conversion_failure,
    COUNT(*) FILTER (
        WHERE unmatched_project_id_flag = TRUE
    ) AS unmatched_project_id_flag_count,
    COUNT(*) FILTER (
        WHERE approved_missing_approval_date_flag = TRUE
    ) AS approved_missing_approval_date_flag_count
FROM final_output;

-- PASS: Zero populated source values failed conversion across all four monetary fields.
-- PASS: One unmatched-project flag and one approved-missing-approval-date flag.


-- Validation 3: Confirm exception flags identify the expected change orders.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT
    change_order_id,
    project_id,
    status_clean,
    approval_date,
    unmatched_project_id_flag,
    approved_missing_approval_date_flag
FROM final_output
WHERE
    unmatched_project_id_flag = TRUE
    OR approved_missing_approval_date_flag = TRUE;

-- PASS: CO0001 retains its NULL approval date and only the missing-approval flag.
-- PASS: CO9999 retains P994 and only the unmatched-project flag.


-- Validation 4: Confirm status_clean contains only the four expected statuses.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT
    status,
    status_clean,
    COUNT(*) AS status_frequency,
    SUM(COUNT(*)) OVER () AS total_rows
FROM final_output
GROUP BY status_clean, status;

-- PASS: Raw status variants map to the four expected cleaned statuses.
-- Cleaned counts: approved 102, pending 14, withdrawn 16, rejected 13.
-- Total: 145 rows.


-- Validation 5: Confirm cleaned columns and exception flags use intended types.
DESCRIBE
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT *
FROM final_output;

-- PASS: All four cleaned monetary columns are DECIMAL(10,2);
-- status_clean is VARCHAR and both exception flags are BOOLEAN.


-- Validation 6: Reconcile all four monetary totals to the deduplicated source.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
),

source_totals AS (
    SELECT
        SUM(
            TRY_CAST(
                REPLACE(
                    REPLACE(requested_revenue_change, '$', ''),
                    ',', ''
                ) AS DECIMAL(10,2)
            )
        ) AS source_requested_revenue_total,
        SUM(TRY_CAST(estimated_cost_change AS DECIMAL(10,2)))
            AS source_estimated_cost_total,
        SUM(TRY_CAST(approved_revenue_change AS DECIMAL(10,2)))
            AS source_approved_revenue_total,
        SUM(TRY_CAST(billed_amount AS DECIMAL(10,2)))
            AS source_billed_total
    FROM deduplicated
),

cleaned_totals AS (
    SELECT
        SUM(requested_revenue_change_clean)
            AS cleaned_requested_revenue_total,
        SUM(estimated_cost_change_clean)
            AS cleaned_estimated_cost_total,
        SUM(approved_revenue_change_clean)
            AS cleaned_approved_revenue_total,
        SUM(billed_amount_clean)
            AS cleaned_billed_total
    FROM final_output
)

SELECT
    s.source_requested_revenue_total,
    c.cleaned_requested_revenue_total,
    c.cleaned_requested_revenue_total
        - s.source_requested_revenue_total AS requested_revenue_difference,

    s.source_estimated_cost_total,
    c.cleaned_estimated_cost_total,
    c.cleaned_estimated_cost_total
        - s.source_estimated_cost_total AS estimated_cost_difference,

    s.source_approved_revenue_total,
    c.cleaned_approved_revenue_total,
    c.cleaned_approved_revenue_total
        - s.source_approved_revenue_total AS approved_revenue_difference,

    s.source_billed_total,
    c.cleaned_billed_total,
    c.cleaned_billed_total
        - s.source_billed_total AS billed_difference
FROM source_totals AS s
CROSS JOIN cleaned_totals AS c;

-- PASS: Source and cleaned totals match; all four differences are 0.00.


-- Validation 7: Confirm source NULLs and recorded zeros are preserved.
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT *
FROM final_output
WHERE (
    TRY_CAST(
        REPLACE(
            REPLACE(requested_revenue_change, '$', ''),
            ',', ''
        ) AS DECIMAL(10,2)
    ) = 0
    AND requested_revenue_change_clean IS DISTINCT FROM 0
)
OR (
    requested_revenue_change IS NULL
    AND requested_revenue_change_clean IS NOT NULL
)
OR (
    TRY_CAST(estimated_cost_change AS DECIMAL(10,2)) = 0
    AND estimated_cost_change_clean IS DISTINCT FROM 0
)
OR (
    estimated_cost_change IS NULL
    AND estimated_cost_change_clean IS NOT NULL
)
OR (
    TRY_CAST(approved_revenue_change AS DECIMAL(10,2)) = 0
    AND approved_revenue_change_clean IS DISTINCT FROM 0
)
OR (
    approved_revenue_change IS NULL
    AND approved_revenue_change_clean IS NOT NULL
)
OR (
    TRY_CAST(billed_amount AS DECIMAL(10,2)) = 0
    AND billed_amount_clean IS DISTINCT FROM 0
)
OR (
    billed_amount IS NULL
    AND billed_amount_clean IS NOT NULL
);

-- PASS: Zero rows returned.


-- Create change_orders view.
CREATE OR REPLACE VIEW construction.cleaned_change_orders AS
WITH deduplicated AS (
    SELECT DISTINCT *
    FROM read_csv_auto('data/raw/change_orders.csv')
),

cleaned_change_orders AS (
    SELECT
        *,
        LOWER(TRIM(status)) AS status_clean,
        TRY_CAST(
            REPLACE(
                REPLACE(requested_revenue_change, '$', ''),
                ',','' ) AS DECIMAL(10, 2)
                  ) AS requested_revenue_change_clean,
        TRY_CAST(estimated_cost_change AS DECIMAL(10,2))
          AS estimated_cost_change_clean,
        TRY_CAST(approved_revenue_change AS DECIMAL(10,2))
          AS approved_revenue_change_clean,
        TRY_CAST(billed_amount AS DECIMAL(10,2))
          AS billed_amount_clean
    FROM deduplicated
),

final_output AS (
    SELECT
        co.*,
        (p.project_id IS NULL) AS unmatched_project_id_flag,
        (co.status_clean = 'approved' AND co.approval_date IS NULL)
        AS approved_missing_approval_date_flag
    FROM cleaned_change_orders AS co
    LEFT JOIN construction.cleaned_projects AS p
        ON co.project_id = p.project_id
)

SELECT *
FROM final_output;

-- View validation 1:
SELECT
    COUNT(*) AS row_total,
    COUNT(DISTINCT change_order_id) AS unique_change_order_count
FROM construction.cleaned_change_orders;

-- PASS: both rows returned 145.

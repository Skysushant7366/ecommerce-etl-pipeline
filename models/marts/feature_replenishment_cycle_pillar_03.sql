{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🧼 PILLAR 3 (V2 FIXED): REPLENISHMENT CYCLE (Removing Same-Day Bulk/Cart Noise)
-- =================================================================================

-- Naya Step: Ek hi din mein same category ke multiple items ko sirf 1 "Purchase Event" manenge
WITH daily_category_purchases AS (
    SELECT 
        user_id,
        product_category,
        DATE(order_created_at) AS purchase_date
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id, product_category, purchase_date
),

-- Ab is unique daily event ki sequence nikalenge
repeat_purchases AS (
    SELECT 
        user_id,
        product_category,
        purchase_date,
        ROW_NUMBER() OVER (PARTITION BY user_id, product_category ORDER BY purchase_date) AS purchase_sequence
    FROM daily_category_purchases
),

purchase_intervals AS (
    SELECT 
        a.user_id,
        a.product_category,
        a.purchase_date AS first_purchase,
        b.purchase_date AS next_purchase,
        -- Ab gap nikalenge (Jo ab 0 nahi aayega!)
        DATE_DIFF(b.purchase_date, a.purchase_date, DAY) AS days_between_purchase
    FROM repeat_purchases a
    JOIN repeat_purchases b 
        ON a.user_id = b.user_id 
        AND a.product_category = b.product_category
        AND a.purchase_sequence = b.purchase_sequence - 1
)

SELECT 
    product_category,
    COUNT(user_id) AS total_repeat_buyers,
    ROUND(AVG(days_between_purchase), 0) AS avg_days_to_replenish,
    MIN(days_between_purchase) AS min_days,
    MAX(days_between_purchase) AS max_days
FROM purchase_intervals
WHERE days_between_purchase > 0 -- Safe filter: 0 days walon ko completely nikaal do
GROUP BY product_category
HAVING total_repeat_buyers > 10 
ORDER BY avg_days_to_replenish ASC
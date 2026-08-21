{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 📱 PILLAR 4 (V2 FIXED): UPGRADE & LIFECYCLE ENGINE (Removing Same-Day Cart Noise)
-- =================================================================================

-- Step 1: Ek din ke orders ko ek single event banate hain aur us din ka average spend nikalte hain
WITH daily_durable_purchases AS (
    SELECT 
        user_id,
        product_category,
        DATE(order_created_at) AS purchase_date,
        AVG(sale_price) AS daily_avg_spend
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
      AND product_category IN ('Electronics', 'Outerwear & Coats', 'Jeans', 'Sweaters')
    GROUP BY user_id, product_category, purchase_date
),

-- Step 2: Sequence lagate hain
repeat_purchases AS (
    SELECT 
        user_id,
        product_category,
        purchase_date,
        daily_avg_spend,
        ROW_NUMBER() OVER (PARTITION BY user_id, product_category ORDER BY purchase_date) AS lifecycle_sequence
    FROM daily_durable_purchases
),

-- Step 3: Din aur Price ka gap nikalte hain
lifecycle_intervals AS (
    SELECT 
        a.user_id,
        a.product_category,
        a.daily_avg_spend AS initial_price,
        b.daily_avg_spend AS upgrade_price,
        DATE_DIFF(b.purchase_date, a.purchase_date, DAY) AS upgrade_days_gap
    FROM repeat_purchases a
    JOIN repeat_purchases b 
        ON a.user_id = b.user_id 
        AND a.product_category = b.product_category
        AND a.lifecycle_sequence = b.lifecycle_sequence - 1
)

-- Step 4: Final Output
SELECT 
    product_category,
    COUNT(user_id) AS total_upgraders,
    ROUND(AVG(upgrade_days_gap), 0) AS avg_upgrade_cycle_days,
    ROUND(AVG(upgrade_price - initial_price), 2) AS avg_price_jump_on_upgrade
FROM lifecycle_intervals
WHERE upgrade_days_gap > 0 -- Safe filter: 0 days walon ko completely nikaal do
GROUP BY product_category
HAVING total_upgraders >= 5
ORDER BY avg_upgrade_cycle_days DESC
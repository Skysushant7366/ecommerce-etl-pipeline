{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 📉 MODEL 8B (BOSS #2): THE ECONOMICS ENGINE (PRICE ELASTICITY OF DEMAND)
-- =================================================================================

WITH monthly_category_sales AS (
    -- Step 1: Har mahine ka Average Price aur Total Quantity nikalna
    SELECT 
        DATE_TRUNC(DATE(order_created_at), MONTH) AS sales_month,
        product_category,
        AVG(sale_price) AS avg_price,
        COUNT(order_id) AS total_quantity_sold
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY sales_month, product_category
),

price_fluctuation_tracker AS (
    -- Step 2: Time-Travel (LAG function) - Pichle mahine ka data aaj ki row mein lana
    SELECT 
        sales_month,
        product_category,
        avg_price AS current_price,
        LAG(avg_price) OVER (PARTITION BY product_category ORDER BY sales_month) AS prev_month_price,
        total_quantity_sold AS current_quantity,
        LAG(total_quantity_sold) OVER (PARTITION BY product_category ORDER BY sales_month) AS prev_month_quantity
    FROM monthly_category_sales
),

elasticity_math AS (
    -- Step 3: Pure Economics - Percentage Change nikalna
    SELECT 
        sales_month,
        product_category,
        current_price,
        prev_month_price,
        -- % Change in Price
        ROUND(((current_price - prev_month_price) / NULLIF(prev_month_price, 0)) * 100, 2) AS pct_change_price,
        current_quantity,
        prev_month_quantity,
        -- % Change in Quantity (Demand)
        ROUND(((current_quantity - prev_month_quantity) / NULLIF(prev_month_quantity, 0)) * 100, 2) AS pct_change_quantity
    FROM price_fluctuation_tracker
    WHERE prev_month_price IS NOT NULL 
)

-- Step 4: The Final Output (CFO Action Matrix)
SELECT 
    sales_month,
    product_category,
    current_price,
    pct_change_price,
    pct_change_quantity,
    
    -- The Master Formula: | % Change in Qty / % Change in Price |
    ROUND(ABS(pct_change_quantity / NULLIF(pct_change_price, 0)), 2) AS price_elasticity_score,

    -- 🚀 LONE WOLF BUSINESS ACTION
    CASE 
        WHEN ABS(pct_change_quantity / NULLIF(pct_change_price, 0)) > 1.5 
             THEN '🧊 HIGHLY ELASTIC: Very Price Sensitive! Do not increase prices here.'
        WHEN ABS(pct_change_quantity / NULLIF(pct_change_price, 0)) < 0.7 
             THEN '💎 INELASTIC (GOLD MINE): Brand loyal. Safe to increase price for more margin!'
        ELSE '⚖️ UNITARY/NORMAL: Standard market reaction.'
    END AS elasticity_action_plan

FROM elasticity_math
-- Filter: Sirf un mahinon ka data dikhao jahan price kam se kam 2% change hua ho (warna noise aayega)
WHERE ABS(pct_change_price) > 2.0 

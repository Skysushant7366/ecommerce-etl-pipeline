{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🏬 MODEL 8E (REFINED): DYNAMIC GMROI BY PRODUCT CONSUMPTION FREQUENCY
-- =================================================================================

WITH category_financials AS (
    SELECT 
        product_category,
        COUNT(order_id) AS total_units_sold,
        SUM(sale_price) AS total_revenue,
        SUM(product_cost) AS total_cogs
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status = 'Complete'
    GROUP BY product_category
),

dynamic_inventory_holding AS (
    SELECT 
        product_category,
        total_units_sold,
        total_revenue,
        total_cogs,
        (total_revenue - total_cogs) AS gross_margin,

        -- 🧠 REAL-WORLD TURNOVER: Category ke nature ke hisaab se annual turns
        CASE 
            WHEN product_category IN ('Socks', 'Intimates', 'Tops & Tees', 'Accessories') THEN 8.0   -- High Frequency
            WHEN product_category IN ('Pants & Capris', 'Dresses', 'Fashion Hoodies & Sweatshirts', 'Leggings', 'Shorts') THEN 5.0 -- Mid Frequency
            ELSE 3.5  -- Low Frequency / Durable (Jeans, Suits, Blazers, Outerwear & Coats)
        END AS estimated_annual_turns
    FROM category_financials
)

SELECT 
    product_category,
    total_units_sold,
    ROUND(total_revenue, 2) AS total_revenue_usd,
    ROUND(gross_margin, 2) AS total_gross_margin_usd,
    
    -- Estimated Avg Inventory = Total COGS / Annual Turns
    ROUND(total_cogs / estimated_annual_turns, 2) AS estimated_inventory_investment_usd,
    
    -- 🧠 GMROI = Gross Margin / Avg Inventory Investment
    ROUND((gross_margin / NULLIF(total_cogs / estimated_annual_turns, 0)), 2) AS gmroi_ratio,

    -- 🚀 LONE WOLF REALISTIC ACTION
    CASE 
        WHEN ROUND((gross_margin / NULLIF(total_cogs / estimated_annual_turns, 0)), 2) >= 4.0 
             THEN '🔥 CAPITAL EFFICIENCY CHAMPION: High margin & fast cash recovery!'
             
        WHEN ROUND((gross_margin / NULLIF(total_cogs / estimated_annual_turns, 0)), 2) BETWEEN 2.5 AND 3.9 
             THEN '✅ HEALTHY CASH GENERATOR: Sustainable stock levels.'
             
        ELSE '⚠️ CAPITAL INTENSIVE: Slow moving or low margin. Limit stock holding.'
    END AS gmroi_action_plan

FROM dynamic_inventory_holding

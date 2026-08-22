{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 👑 THE GRAND MASTER PRODUCT ECONOMICS 360 (THE CFO'S GOLDEN RECORD) - V1
-- Resolving 5 Financial & Economics Engines into a Single AI-Ready Table
-- =================================================================================

WITH base_products AS (
    -- Step 1: Saare unique products ikattha karna 06B aur 06C se
    SELECT product_id, product_name, product_category 
    FROM {{ ref('model_price_resistance_wall_06B') }}
    UNION DISTINCT
    SELECT product_id, product_name, product_category 
    FROM {{ ref('model_surge_pricing_inventory_06C') }}
),

overall_elasticity AS (
    -- Step 2: Elasticity table (08B) mein mahine (months) the. 
    -- Hum duplicate rows rokne ke liye category ka ek single "Average Elasticity" nikal rahe hain.
    SELECT 
        product_category,
        ROUND(AVG(price_elasticity_score), 2) AS avg_price_elasticity_score,
        ANY_VALUE(elasticity_action_plan) AS category_elasticity_action
    FROM {{ ref('model_price_elasticity_08B') }}
    GROUP BY product_category
)

SELECT 
    -- 🏷️ BASE INFO
    bp.product_id,
    bp.product_name,
    bp.product_category,
    
    -- 💰 LAYER 1: UNIT ECONOMICS & MARGIN (From 08D & 06B)
    p06b.retail_price,
    p06b.cost,
    p06b.absolute_margin,
    p06b.profit_margin_pct,
    p08d.true_margin_pct AS category_true_margin_pct,
    p08d.margin_action_plan AS category_margin_health,

    -- 📦 LAYER 2: INVENTORY & CAPITAL VELOCITY (From 06C & 08E)
    p06c.live_unsold_stock,
    p06c.total_capital_locked,
    p06c.days_to_stock_out,
    p06c.daily_burn_rate,
    p08e.gmroi_ratio AS category_gmroi_ratio,
    p08e.gmroi_action_plan AS category_gmroi_health,

    -- 📉 LAYER 3: DEMAND & ELASTICITY (From 06B, 06C & 08B)
    p06b.total_views,
    p06b.total_purchases,
    p06b.view_to_purchase_drop_rate,
    p06c.demand_growth_pct,
    e.avg_price_elasticity_score AS category_elasticity_score,
    e.category_elasticity_action,

    -- 👑 THE CFO'S CONFLICT RESOLUTION ENGINE (Master Action Column)
    CASE 
        -- Rule 1: Bleeding Cash & Dead Stock (KILL IT)
        WHEN p08d.margin_action_plan LIKE '%BLEEDING%' OR p08e.gmroi_action_plan LIKE '%DEAD WEIGHT%' 
             THEN '🚨 CRITICAL KILL: Category is bleeding cash/dead weight. Liquidate stock immediately at 40%+ discount.'
             
        -- Rule 2: High Demand, Stock Running Out + Inelastic (SURGE IT)
        WHEN p06c.dynamic_business_action LIKE '%URGENT SURGE%' AND e.category_elasticity_action LIKE '%INELASTIC%'
             THEN '💰 SURGE & EXPAND: Stock <15 days + Inelastic Demand! Hike price by 15% immediately.'
             
        -- Rule 3: The Golden Goose (Protect & Scale)
        WHEN p08e.gmroi_action_plan LIKE '%CHAMPION%' AND p08d.margin_action_plan LIKE '%CASH COW%'
             THEN '🏆 PROTECT & SCALE: Highest ROI and Margin. Never discount. Double ad spend.'
             
        -- Rule 4: Price Resistance Wall (High Views, Zero Buys)
        WHEN p06b.pricing_action_plan LIKE '%Drop price%' 
             THEN '⚠️ PRICE RESISTANCE: High views, low buys. Apply 10% Flash Sale to break friction.'
             
        -- Rule 5: Dead Inventory Trap
        WHEN p06c.dynamic_business_action LIKE '%DEAD STOCK%'
             THEN '🧨 DEAD CAPITAL: Apply BOGO/Clearance offers to free up warehouse space.'

        ELSE '✅ STANDARD OPERATIONS: Healthy economics, maintain current strategy.'
    END AS master_product_financial_action

FROM base_products bp
LEFT JOIN {{ ref('model_price_resistance_wall_06B') }} p06b ON bp.product_id = p06b.product_id
LEFT JOIN {{ ref('model_surge_pricing_inventory_06C') }} p06c ON bp.product_id = p06c.product_id
LEFT JOIN overall_elasticity e ON bp.product_category = e.product_category
LEFT JOIN {{ ref('model_contribution_margin_08D') }} p08d ON bp.product_category = p08d.product_category
LEFT JOIN {{ ref('model_retail_gmroi_08E') }} p08e ON bp.product_category = p08e.product_category
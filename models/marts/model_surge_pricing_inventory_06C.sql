{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 📦 MODEL 6C (MULTIVARIATE GOD-MODE): CAPITAL VELOCITY & SURGE PRICING ENGINE
-- =================================================================================

WITH system_time AS (
    -- Step 1: Time Machine (Dataset ka aakhiri din nikalna taaki Last 30 Days sahi se calculate ho)
    SELECT MAX(DATE(order_created_at)) AS current_db_date 
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
),

live_inventory AS (
    -- Step 2: 🏢 SUPPLY ENGINE (Godown mein aaj exact kitna stock bacha hai aur kitna paisa block hai?)
    SELECT 
        product_id,
        ANY_VALUE(product_name) AS product_name,
        ANY_VALUE(product_category) AS product_category,
        COUNT(id) AS live_unsold_stock,
        ROUND(SUM(cost), 2) AS total_capital_locked
    FROM {{ ref('stg_inventory_items') }} -- 👈 DBT Magic (Ref)
    WHERE sold_at IS NULL -- The God-Mode filter: Jo bika nahi, wo godown mein hai!
    GROUP BY product_id
),

demand_momentum AS (
    -- Step 3: 📈 DEMAND ENGINE (Pichle 30 din vs usse pichle 30 din ki sales velocity)
    SELECT 
        f.product_id,
        -- Last 30 Days (Current Momentum)
        SUM(CASE WHEN DATE_DIFF(s.current_db_date, DATE(f.order_created_at), DAY) <= 30 THEN 1 ELSE 0 END) AS demand_l30d,
        -- Previous 30 Days (Historical Baseline for Macro/Micro Trends)
        SUM(CASE WHEN DATE_DIFF(s.current_db_date, DATE(f.order_created_at), DAY) BETWEEN 31 AND 60 THEN 1 ELSE 0 END) AS demand_prev_30d
    FROM {{ ref('fct_order_items') }} f -- 👈 DBT Magic (Ref)
    CROSS JOIN system_time s
    WHERE f.order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY f.product_id
)

SELECT 
    i.product_id,
    i.product_name,
    i.product_category,
    i.live_unsold_stock,
    i.total_capital_locked,
    COALESCE(d.demand_l30d, 0) AS demand_l30d,
    COALESCE(d.demand_prev_30d, 0) AS demand_prev_30d,
    
    -- 🧠 ECONOMICS METRICS (Growth & Velocity)
    ROUND(SAFE_DIVIDE((COALESCE(d.demand_l30d, 0) - COALESCE(d.demand_prev_30d, 0)), NULLIF(d.demand_prev_30d, 0)) * 100, 2) AS demand_growth_pct,
    
    -- 🔥 BURN RATE METRICS (Kitne din mein godown khali hoga?)
    ROUND(SAFE_DIVIDE(COALESCE(d.demand_l30d, 0), 30), 2) AS daily_burn_rate,
    ROUND(SAFE_DIVIDE(i.live_unsold_stock, NULLIF(SAFE_DIVIDE(COALESCE(d.demand_l30d, 0), 30), 0)), 0) AS days_to_stock_out,
    
    -- 🚀 THE SURGE PRICING & CAPITAL ACTION PLAN
    CASE 
        WHEN COALESCE(d.demand_l30d, 0) = 0 
             THEN '💤 NO RECENT DEMAND: Stagnant Product. Blocked Capital.'
             
        -- SCENARIO 1: THE UBER SURGE (High Demand, Low Stock)
        WHEN ROUND(SAFE_DIVIDE(i.live_unsold_stock, NULLIF(SAFE_DIVIDE(d.demand_l30d, 30), 0)), 0) <= 15 AND SAFE_DIVIDE((d.demand_l30d - COALESCE(d.demand_prev_30d,0)), NULLIF(d.demand_prev_30d, 0)) > 0.0
             THEN '🚨 URGENT SURGE: Stock out in <15 days! Increase price by 10-15% immediately to maximize margins and slow burn.'
             
        -- SCENARIO 2: RESTOCK WARNING (High Demand, Healthy Stock but burning fast)
        WHEN ROUND(SAFE_DIVIDE(i.live_unsold_stock, NULLIF(SAFE_DIVIDE(d.demand_l30d, 30), 0)), 0) BETWEEN 16 AND 45 AND SAFE_DIVIDE((d.demand_l30d - COALESCE(d.demand_prev_30d,0)), NULLIF(d.demand_prev_30d, 0)) >= 0.15 
             THEN '📈 HIGH GROWTH: Restock urgently from supplier. Keep pricing stable to capture market share.'
             
        -- SCENARIO 3: THE DEAD STOCK TRAP (Low Demand, Huge Stock)
        WHEN ROUND(SAFE_DIVIDE(i.live_unsold_stock, NULLIF(SAFE_DIVIDE(d.demand_l30d, 30), 0)), 0) >= 90 AND SAFE_DIVIDE((d.demand_l30d - COALESCE(d.demand_prev_30d,0)), NULLIF(d.demand_prev_30d, 0)) <= -0.10 
             THEN '🧨 DEAD STOCK: Capital is blocked! Apply 30% Flash Sale / BOGO offers to liquidate inventory.'
             
        -- SCENARIO 4: MARGIN DRAIN (Demand is flat, stock is stagnant)
        WHEN ROUND(SAFE_DIVIDE(i.live_unsold_stock, NULLIF(SAFE_DIVIDE(d.demand_l30d, 30), 0)), 0) > 60 
             THEN '⚠️ SLOW BURN: Run targeted Ads and micro-discounts (5-10%) to stimulate baseline demand.'
             
        ELSE '✅ HEALTHY: Optimal inventory & demand velocity. Maintain current pricing.'
    END AS dynamic_business_action

FROM live_inventory i
LEFT JOIN demand_momentum d ON i.product_id = d.product_id

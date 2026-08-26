{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🏬 THE ULTIMATE PRODUCT ECONOMICS 360 V2.0 (THE CFO & OPERATIONS GOD-RECORD)
-- Upgrading V1 with Category Replenishment, Upgrade Lifecycle, Toxicity, Geospatial & Apriori
-- =================================================================================

WITH apriori_safe AS (
    -- 🛒 Anti-Fanout Logic: Har category ka sirf sabse best (Top Confidence) cross-sell utha rahe hain
    SELECT 
        anchor_category,
        cross_sell_category AS best_cross_sell_category,
        confidence_pct AS cross_sell_confidence_pct,
        apriori_action_plan
    FROM {{ ref('model_apriori_market_basket_08A') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY anchor_category ORDER BY confidence_pct DESC) = 1
),

geospatial_safe AS (
    -- 🌍 Anti-Fanout Logic: Ek product multiple DCs mein ho sakta hai, toh sabse worst margin wale DC ko utha rahe hain
    SELECT 
        product_id,
        avg_shipping_distance_km,
        true_net_profit_usd AS geospatial_net_profit_usd,
        geospatial_action_plan
    FROM {{ ref('model_geospatial_margin_bleed_07A') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY product_id ORDER BY true_net_profit_usd ASC) = 1
)

SELECT 
    m.*, -- V1 ki saari Product, Margin, Elasticity aur Inventory ki data as-it-is
    
    -- =========================================================
    -- 🔄 LAYER 4: CATEGORY REPLENISHMENT CYCLE (From Pillar 03)
    -- =========================================================
    p03.avg_days_to_replenish,
    p03.total_repeat_buyers AS category_repeat_buyers,
    
    -- =========================================================
    -- 📈 LAYER 5: UPGRADE LIFECYCLE & UPSELL (From Pillar 04)
    -- =========================================================
    p04.avg_upgrade_cycle_days,
    p04.avg_price_jump_on_upgrade,

    -- =========================================================
    -- ☠️ LAYER 6: TOXICITY & MARGIN BLEED (From Model 06A)
    -- =========================================================
    p06a.return_rate_pct AS product_return_rate_pct,
    p06a.true_margin_lost_to_returns,
    p06a.multivariate_health_status,
    p06a.root_cause_action_plan,

    -- =========================================================
    -- 🌍 LAYER 7: GEOSPATIAL LOGISTICS RISK (From Model 07A)
    -- =========================================================
    p07a.avg_shipping_distance_km,
    p07a.geospatial_net_profit_usd,
    p07a.geospatial_action_plan,

    -- =========================================================
    -- 🛒 LAYER 8: APRIORI MARKET BASKET (From Model 08A)
    -- =========================================================
    p08a.best_cross_sell_category,
    p08a.cross_sell_confidence_pct,
    p08a.apriori_action_plan

FROM {{ ref('master_product_economics_360') }} m

-- 🔗 JOINING THE 2 LEFTOVER CATEGORY PILLARS
LEFT JOIN {{ ref('feature_replenishment_cycle_pillar_03') }} p03 
    ON m.product_category = p03.product_category
LEFT JOIN {{ ref('feature_upgrade_lifecycle_pillar_04') }} p04 
    ON m.product_category = p04.product_category

-- 🔗 JOINING THE 3 NEW ADVANCED PRODUCT & CATEGORY ENGINES
LEFT JOIN {{ ref('model_toxic_velocity_trap_06A') }} p06a
    ON m.product_id = p06a.product_id
LEFT JOIN geospatial_safe p07a
    ON m.product_id = p07a.product_id
LEFT JOIN apriori_safe p08a
    ON m.product_category = p08a.anchor_category
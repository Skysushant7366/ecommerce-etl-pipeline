{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🏬 THE ULTIMATE PRODUCT ECONOMICS 360 V2.0 (THE CFO & OPERATIONS GOD-RECORD)
-- Upgrading V1 with Category Replenishment Cycle & Upgrade Lifecycle (Pillars 03 & 04)
-- =================================================================================

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
    p04.avg_price_jump_on_upgrade

FROM {{ ref('master_product_economics_360') }} m

-- 🔗 JOINING THE 2 LEFTOVER CATEGORY PILLARS
LEFT JOIN {{ ref('feature_replenishment_cycle_pillar_03') }} p03 
    ON m.product_category = p03.product_category
LEFT JOIN {{ ref('feature_upgrade_lifecycle_pillar_04') }} p04 
    ON m.product_category = p04.product_category
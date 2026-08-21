{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 👑 THE GRAND MASTER CUSTOMER 360 (THE GOLDEN RECORD) - V1
-- Resolving 25 Pillars + AI Features into a Single Table
-- =================================================================================

WITH base_users AS (
    SELECT DISTINCT id 
    FROM {{ ref('stg_users') }} -- 👈 DBT Magic (Ref)
    WHERE id IS NOT NULL
)

SELECT 
    u.id,

    -- =========================================================
    -- 👤 LAYER 1: IDENTITY, DEMOGRAPHICS & GEO 
    -- =========================================================
    COALESCE(p18.age, p11.user_age) AS user_age,
    COALESCE(p18.gender, p11.user_gender) AS user_gender,
    COALESCE(p18.country, p11.user_country, p24.country) AS user_country,
    COALESCE(p18.generational_cohort, p11.age_cohort) AS generational_cohort,
    p18.geo_market_segment,
    p24.climate_zone_segment,
    p24.seasonal_buying_pattern,
    p22.primary_browser,
    p22.device_persona,

    -- =========================================================
    -- 💰 LAYER 2: UNIT ECONOMICS, LTV & WALLET 
    -- =========================================================
    COALESCE(p10.total_lifetime_revenue, p14.total_revenue, 0) AS total_revenue,
    COALESCE(p10.total_successful_orders, p14.total_items_bought, 0) AS total_successful_orders,
    COALESCE(p10.average_order_value, p14.avg_item_price, 0) AS average_order_value,
    p14.profit_margin_percent,
    p14.total_absolute_profit,         -- Added for AI
    p14.profitability_segment,
    p19.spending_habit_segment,
    p07.is_discount_hunter,
    p10.ltv_segment,
    p04.target_next_90d_spend, 
    p10.personal_purchase_cycle_days,
    p10.days_since_last_order,
    p04.l365_total_spend,              -- Added for AI
    p04.l365_total_orders,             -- Added for AI
    p04.discount_dependency_ratio,     -- Added for AI
    p19.highest_price_paid,            -- Added for AI
    p19.premium_items_bought,          -- Added for AI
    p19.mid_range_items_bought,        -- Added for AI
    p19.budget_items_bought,           -- Added for AI

    -- =========================================================
    -- 🧠 LAYER 3: BEHAVIORAL INTENT & TASTE 
    -- =========================================================
    COALESCE(p15.top_favorite_brand, p05.product_brand) AS top_favorite_brand,
    p15.top_favorite_category,
    p15.brand_loyalty_segment,
    p13.primary_traffic_source,
    p13.browsing_persona,
    p16.preferred_shopping_time,
    COALESCE(p16.preferred_shopping_day, p09.preferred_shopping_day) AS preferred_shopping_day,
    p09.preferred_season,
    p09.weekend_orders,                -- Added for AI
    p09.weekday_orders,                -- Added for AI
    p12.live_intent_segment,
    p12.days_since_last_visit,
    p12.abandoned_cart_sessions,       -- Added for AI
    p12.total_product_views,           -- Added for AI
    p12.total_cart_adds,               -- Added for AI
    p25.ux_experience_segment,
    p25.rage_click_sessions,
    p13.avg_clicks_per_session,        -- Added for AI
    p15.distinct_brands_bought,        -- Added for AI
    p15.distinct_categories_bought,    -- Added for AI
    p25.max_clicks_in_single_session,  -- Added for AI
    p25.avg_session_duration_seconds,  -- Added for AI

    -- =========================================================
    -- 🛡️ LAYER 4: RISK, RETURNS & FRAUD 
    -- =========================================================
    COALESCE(p17.return_rate_percent, p08.return_rate_percentage, 0) AS return_rate_percent,
    p17.logistics_experience_segment,
    p17.avg_delivery_days,
    p23.risk_persona AS scraper_abuse_risk,
    COALESCE(p23.fraud_prevention_action, CAST(p01.is_fraud_suspect AS STRING)) AS master_fraud_flag,
    p01.max_users_on_same_ip,
    p01.discount_leech_ratio,          -- Added for AI
    p01.lifetime_daily_velocity,       -- Added for AI
    p01.max_orders_in_a_single_day,    -- Added for AI
    p08.total_items_returned,          -- Added for AI
    p08.total_refund_amount,           -- Added for AI
    p23.cancellation_rate_percent,     -- Added for AI

    -- =========================================================
    -- ⏳ LAYER 5: RFM SCORE & LIFECYCLE LOYALTY 
    -- =========================================================
    p21.recency_days,
    p21.rfm_code,
    p21.r_score,                       -- Added for AI
    p21.f_score,                       -- Added for AI
    p21.m_score,                       -- Added for AI
    p21.rfm_segment,
    p20.lifecycle_segment,
    p20.customer_tenure_days,

    -- =========================================================
    -- 👑 THE CONFLICT RESOLUTION ENGINE (Master Action Column)
    -- =========================================================
    CASE 
        WHEN p23.risk_persona LIKE '%Bot%' OR p01.is_fraud_suspect = 1 THEN 'BLOCK: Account under fraud review. Disable checkout.'
        WHEN p17.logistics_experience_segment LIKE '%Serial Returner%' THEN 'MARGIN PROTECT: Disable Free Returns and COD.'
        WHEN p14.profitability_segment LIKE '%Margin Killer%' THEN 'NO DISCOUNT: Push high-margin accessories only.'
        WHEN (p21.rfm_segment LIKE '%Lose Them%' OR p20.lifecycle_segment LIKE '%Slipping Away%') THEN 
            CASE 
                WHEN p19.spending_habit_segment LIKE '%High-Roller%' THEN 'VIP WIN-BACK: Call from concierge & offer free premium accessory.'
                ELSE CONCAT('WIN-BACK: Trigger ', p07.is_discount_hunter, ' style discount campaign.')
            END
        WHEN p21.rfm_segment LIKE '%Champions%' THEN 'LOYALTY: Do not discount. Invite to exclusive early-access drops.'
        ELSE 'STANDARD: Send localized catalog based on geo-seasonality.'
    END AS master_360_marketing_action

FROM base_users u
LEFT JOIN {{ ref('feature_fraud_detection_pillar_01') }} p01 ON u.id = p01.user_id
LEFT JOIN {{ ref('feature_ltv_prediction_04') }} p04 ON u.id = p04.user_id
LEFT JOIN {{ ref('feature_taste_matchmaker_pillar_05') }} p05 ON u.id = p05.user_id AND p05.brand_affinity_rank = 1
LEFT JOIN {{ ref('feature_price_sensitivity_pillar_07') }} p07 ON u.id = p07.user_id
LEFT JOIN {{ ref('feature_return_risk_pillar_08') }} p08 ON u.id = p08.user_id
LEFT JOIN {{ ref('feature_time_trends_pillar_09') }} p09 ON u.id = p09.user_id
LEFT JOIN {{ ref('feature_lifetime_value_pillar_10') }} p10 ON u.id = p10.user_id
LEFT JOIN {{ ref('feature_demographics_pillar_11') }} p11 ON u.id = p11.user_id
LEFT JOIN {{ ref('feature_cart_abandonment_pillar_12') }} p12 ON u.id = p12.user_id
LEFT JOIN {{ ref('feature_digital_persona_pillar_13') }} p13 ON u.id = p13.user_id
LEFT JOIN {{ ref('feature_profit_margin_pillar_14') }} p14 ON u.id = p14.user_id
LEFT JOIN {{ ref('feature_brand_affinity_pillar_15') }} p15 ON u.id = p15.user_id
LEFT JOIN {{ ref('feature_temporal_context_pillar_16') }} p16 ON u.id = p16.user_id
LEFT JOIN {{ ref('feature_logistics_experience_pillar_17') }} p17 ON u.id = p17.user_id
LEFT JOIN {{ ref('feature_demographics_geo_pillar_18') }} p18 ON u.id = p18.user_id
LEFT JOIN {{ ref('feature_price_tier_affinity_pillar_19') }} p19 ON u.id = p19.user_id
LEFT JOIN {{ ref('feature_customer_lifecycle_pillar_20') }} p20 ON u.id = p20.user_id
LEFT JOIN {{ ref('feature_rfm_score_pillar_21') }} p21 ON u.id = p21.user_id
LEFT JOIN {{ ref('feature_device_ecosystem_pillar_22') }} p22 ON u.id = p22.user_id
LEFT JOIN {{ ref('feature_fraud_risk_pillar_23') }} p23 ON u.id = p23.user_id
LEFT JOIN {{ ref('feature_geo_seasonality_pillar_24') }} p24 ON u.id = p24.user_id
LEFT JOIN {{ ref('feature_app_frustration_pillar_25') }} p25 ON u.id = p25.user_id
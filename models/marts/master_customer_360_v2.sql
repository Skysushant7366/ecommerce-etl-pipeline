{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 👑 THE ULTIMATE CUSTOMER 360 V2.0 (THE MARKETING & CRM GOD-RECORD)
-- Upgrading V1 with Purchase DNA, Survival Probability & Solvency Metrics
-- =================================================================================

SELECT 
    c.*, -- V1 ki saari tables ki mehnat (pichli table se aayegi)
    
    -- =========================================================
    -- 🧬 LAYER 6: THE PURCHASE DNA & GATEWAY DRUG (From 07B)
    -- =========================================================
    p7b.total_orders_in_chain,
    p7b.complete_category_journey,
    p7b.recursive_action_plan,
    
    -- =========================================================
    -- ⏳ LAYER 7: PREDICTIVE CHURN & SURVIVAL (From 08C)
    -- =========================================================
    p8c.survival_probability_pct,
    p8c.churn_action_plan,
    
    -- =========================================================
    -- 💳 LAYER 8: SOLVENCY & CAC PAYBACK (From 08F)
    -- =========================================================
    p8f.payback_order_number,
    p8f.days_to_payback,
    p8f.solvency_action_plan

FROM {{ ref('master_customer_360') }} c

-- 🔗 JOINING THE 3 NEW ADVANCED USER ENGINES
LEFT JOIN {{ ref('model_recursive_purchase_chain_07B') }} p7b 
    ON c.id = p7b.user_id
LEFT JOIN {{ ref('model_dynamic_rfm_churn_08C') }} p8c 
    ON c.id = p8c.user_id
LEFT JOIN {{ ref('model_solvency_cac_payback_08F') }} p8f 
    ON c.id = p8f.user_id
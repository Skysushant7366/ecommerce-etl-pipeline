{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🚨 PILLAR 23: PROMO ABUSE, BOT SCRAPING & FRAUD RISK ENGINE
-- =================================================================================

WITH order_risk_metrics AS (
    -- Step 1: User ke total orders aur Cancel/Return ki aadat nikalna
    SELECT 
        user_id,
        COUNT(order_item_id) AS total_items_attempted,
        SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS total_cancelled,
        SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) AS total_returned
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    GROUP BY user_id
),

click_risk_metrics AS (
    -- Step 2: User ke total clicks nikalna taaki bots pakde ja sakein
    SELECT 
        user_id,
        COUNT(id) AS total_clicks,
        COUNT(DISTINCT session_id) AS total_sessions
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)

SELECT 
    COALESCE(o.user_id, c.user_id) AS user_id,
    COALESCE(o.total_items_attempted, 0) AS total_items_attempted,
    COALESCE(o.total_cancelled, 0) AS total_cancelled,
    COALESCE(c.total_clicks, 0) AS total_clicks,
    
    -- 🧠 AI Proxy Metric: Cancellation Rate
    ROUND(SAFE_DIVIDE(o.total_cancelled, o.total_items_attempted) * 100, 2) AS cancellation_rate_percent,
    
    -- 🤖 AI Persona: The Fraud / Risk Segment
    CASE 
        WHEN COALESCE(c.total_clicks, 0) > 150 AND COALESCE(o.total_items_attempted, 0) = 0 THEN 'Suspicious Scraper / Bot (High Clicks, 0 Buys)'
        WHEN SAFE_DIVIDE(o.total_cancelled, o.total_items_attempted) >= 0.60 AND COALESCE(o.total_items_attempted, 0) >= 3 THEN 'Policy Abuser (Serial Canceller)'
        WHEN SAFE_DIVIDE(o.total_cancelled, o.total_items_attempted) BETWEEN 0.30 AND 0.59 AND COALESCE(o.total_items_attempted, 0) >= 2 THEN 'High Risk (Frequent Canceller)'
        ELSE 'Clean & Verified Customer'
    END AS risk_persona,
    
    -- 🚀 Real-Time Security & Checkout Action
    CASE 
        WHEN COALESCE(c.total_clicks, 0) > 150 AND COALESCE(o.total_items_attempted, 0) = 0 THEN 'SECURITY TRIGGER: Force Re-Captcha on next click. Throttle API requests.'
        WHEN SAFE_DIVIDE(o.total_cancelled, o.total_items_attempted) >= 0.60 AND COALESCE(o.total_items_attempted, 0) >= 3 THEN 'PAYMENT LOCK: Disable "Cash on Delivery" (COD). Require prepaid instruments only.'
        WHEN SAFE_DIVIDE(o.total_cancelled, o.total_items_attempted) BETWEEN 0.30 AND 0.59 AND COALESCE(o.total_items_attempted, 0) >= 2 THEN 'WARNING: Flag account for manual review before processing next high-value order.'
        ELSE 'Allow seamless 1-Click checkout.'
    END AS fraud_prevention_action

FROM order_risk_metrics o
FULL OUTER JOIN click_risk_metrics c 
    ON o.user_id = c.user_id
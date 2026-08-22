{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🛒 PILLAR 6 (FINAL): ENGAGEMENT & CART INTENT ENGINE (Rich Columns)
-- =================================================================================

WITH session_level_events AS (
    SELECT 
        user_id,
        session_id,
        -- Har session ka detail count
        SUM(CASE WHEN event_type = 'product' THEN 1 ELSE 0 END) AS product_views,
        SUM(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS cart_adds,
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL 
    GROUP BY user_id, session_id
)

SELECT 
    user_id,
    COUNT(session_id) AS total_sessions,
    
    -- Wapas add kiye gaye engagement columns
    SUM(product_views) AS total_product_views,
    SUM(cart_adds) AS total_cart_adds,
    
    -- Apna fixed logic (Abandonment vs Purchase)
    SUM(CASE WHEN cart_adds > 0 AND purchases = 0 THEN 1 ELSE 0 END) AS true_abandoned_sessions,
    SUM(CASE WHEN purchases > 0 THEN 1 ELSE 0 END) AS successful_purchasing_sessions

FROM session_level_events
GROUP BY user_id
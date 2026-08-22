{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🔥 PILLAR 12: REAL-TIME INTENT & CART ABANDONMENT ENGINE (CLICKSTREAM DATA)
-- =================================================================================

WITH session_activity AS (
    -- Step 1: User ke har website session ka post-mortem (Usne exactly kiya kya?)
    SELECT 
        user_id,
        session_id,
        MAX(CASE WHEN event_type = 'product' THEN 1 ELSE 0 END) AS viewed_product,
        MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS added_to_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS made_purchase,
        MAX(created_at) AS session_end_time,
        ANY_VALUE(traffic_source) AS session_traffic_source
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL 
    GROUP BY user_id, session_id
),

user_abandonment_metrics AS (
    -- Step 2: Poori history ko add karke user ka "Live Intent" nikalna
    SELECT 
        user_id,
        COUNT(DISTINCT session_id) AS total_sessions,
        SUM(viewed_product) AS total_product_views,
        SUM(added_to_cart) AS total_cart_adds,
        SUM(made_purchase) AS total_purchases,
        
        -- 🧠 ASLI JADOO: Agar Cart = 1 hai par Purchase = 0 hai, toh ye Abandoned Session hai!
        SUM(CASE WHEN added_to_cart = 1 AND made_purchase = 0 THEN 1 ELSE 0 END) AS abandoned_cart_sessions,
        
        MAX(session_end_time) AS latest_website_visit
    FROM session_activity
    GROUP BY user_id
)

SELECT 
    user_id,
    total_sessions,
    total_product_views,
    total_cart_adds,
    total_purchases,
    abandoned_cart_sessions,
    
    -- Kitne din pehle website par aakhiri baar aaya tha?
    DATE_DIFF(CURRENT_TIMESTAMP(), latest_website_visit, DAY) AS days_since_last_visit,
    
    -- 🤖 AI Persona: The Live Intent Segments
    CASE 
        WHEN abandoned_cart_sessions >= 3 AND total_purchases = 0 THEN 'Serial Cart Abandoner (High Hesitation)'
        WHEN abandoned_cart_sessions > 0 AND DATE_DIFF(CURRENT_TIMESTAMP(), latest_website_visit, DAY) <= 2 THEN 'Recent Abandoner (Hot Lead)'
        WHEN abandoned_cart_sessions > 0 THEN 'Cold Cart Abandoner'
        WHEN total_cart_adds = 0 AND total_product_views >= 5 THEN 'Heavy Window Shopper (Never Carts)'
        ELSE 'Standard Browser'
    END AS live_intent_segment,
    
    -- 🚀 NAYA COLUMN: Real-Time Marketing Action / Recommendation Trigger
    CASE 
        WHEN abandoned_cart_sessions >= 3 AND total_purchases = 0 THEN 'TRIGGER: Send 15% Flash Discount via Push Notification immediately.'
        WHEN abandoned_cart_sessions > 0 AND DATE_DIFF(CURRENT_TIMESTAMP(), latest_website_visit, DAY) <= 2 THEN 'TRIGGER: Send FOMO Email ("Items in your cart are selling out fast!").'
        WHEN abandoned_cart_sessions > 0 THEN 'TRIGGER: Retarget via Facebook/Instagram Ads with lower-priced alternatives.'
        WHEN total_cart_adds = 0 AND total_product_views >= 5 THEN 'UI CHANGE: Show "Bestsellers & High Rated" products on Homepage to build trust.'
        ELSE 'Maintain standard recommendation feed.'
    END AS live_marketing_action

FROM user_abandonment_metrics
{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🚚 PILLAR 17: LOGISTICS EXPERIENCE, PATIENCE & RETURN BEHAVIOR ENGINE
-- =================================================================================

WITH order_logistics AS (
    -- Step 1: Har item ka delivery time (days mein) aur return status nikalna
    SELECT 
        user_id,
        order_item_id,
        order_status,
        -- Delivery mein kitne din lage? (Sirf unka jo deliver hue hain)
        DATE_DIFF(delivered_at, order_created_at, DAY) AS delivery_days,
        -- Kya item wapas aaya?
        CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END AS is_returned
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status IN ('Complete', 'Returned', 'Shipped', 'Processing') -- Cancelled items hata diye
),

user_logistics_summary AS (
    -- Step 2: User ka overall experience aur return aadat
    SELECT 
        user_id,
        COUNT(order_item_id) AS total_items_processed,
        SUM(is_returned) AS total_returns,
        ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
        MAX(delivery_days) AS max_delivery_days_experienced
    FROM order_logistics
    GROUP BY user_id
)

SELECT 
    user_id,
    total_items_processed,
    total_returns,
    avg_delivery_days,
    max_delivery_days_experienced,
    
    -- 🧠 AI Metric: Return Rate Percentage (Kitne % items wapas karta hai)
    ROUND(SAFE_DIVIDE(total_returns, total_items_processed) * 100, 2) AS return_rate_percent,
    
    -- 🤖 AI Persona: The Patience & Trust Segment
    CASE 
        WHEN total_returns > 0 AND SAFE_DIVIDE(total_returns, total_items_processed) >= 0.50 THEN 'Serial Returner (High Cost to Serve)'
        WHEN avg_delivery_days >= 7 THEN 'Frustrated Buyer (Experienced Bad Logistics)'
        WHEN total_returns = 0 AND avg_delivery_days <= 3 THEN 'Highly Satisfied (Smooth Experience)'
        ELSE 'Standard Logistics Experience'
    END AS logistics_experience_segment,
    
    -- 🚀 Real-Time Recommendation & Retention Action
    CASE 
        WHEN total_returns > 0 AND SAFE_DIVIDE(total_returns, total_items_processed) >= 0.50 THEN 'RESTRICT RETURNS: Stop recommending "High-Return" categories like Shoes/Dresses. Hide free return banners.'
        WHEN avg_delivery_days >= 7 THEN 'RETENTION TRIGGER: Send "Sorry we were slow last time. Here is FREE EXPRESS DELIVERY" on next purchase.'
        WHEN total_returns = 0 AND avg_delivery_days <= 3 THEN 'UPSELL ZONE: High trust established. Recommend high-ticket/premium items safely.'
        ELSE 'Apply standard shipping policies.'
    END AS logistics_marketing_action

FROM user_logistics_summary
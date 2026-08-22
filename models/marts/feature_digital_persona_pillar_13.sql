{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🌐 PILLAR 13: DIGITAL PERSONA, BROWSING INTENT & TRAFFIC SOURCE ENGINE
-- =================================================================================

WITH user_events AS (
    -- Har user ka poora Digital Footprint nikal rahe hain
    SELECT 
        user_id,
        COUNT(DISTINCT session_id) AS total_sessions,
        COUNT(id) AS total_clicks, -- Ek click (page view, cart) ko hum id se count kar rahe hain
        
        -- Asli khel: Wo kis source aur browser se aaya
        ANY_VALUE(traffic_source) AS primary_traffic_source,
        ANY_VALUE(browser) AS primary_browser,
        MAX(created_at) AS last_click_time
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)

SELECT 
    user_id,
    total_sessions,
    total_clicks,
    
    -- AI Metric: Ek session mein average kitne pages/clicks kiye
    ROUND(total_clicks / NULLIF(total_sessions, 0), 1) AS avg_clicks_per_session,
    
    primary_traffic_source,
    primary_browser,
    
    -- 🤖 AI Persona: The Browsing Intensity
    CASE 
        WHEN (total_clicks / NULLIF(total_sessions, 0)) <= 4 THEN 'Decisive Buyer (Fast Checkout)'
        WHEN (total_clicks / NULLIF(total_sessions, 0)) BETWEEN 5 AND 10 THEN 'Standard Explorer'
        WHEN (total_clicks / NULLIF(total_sessions, 0)) > 10 THEN 'Deep Researcher / Confused Buyer'
        ELSE 'Unknown'
    END AS browsing_persona,
    
    -- 🚀 Real-Time UI & Marketing Action (Source ke basis par)
    CASE 
        WHEN primary_traffic_source = 'Adwords' THEN 'HIGH INTENT (Google Search): Recommend precise top-rated products. No heavy discounts needed.'
        WHEN primary_traffic_source = 'Facebook' THEN 'IMPULSE BUYER (Social Media): Show trending items, FOMO popups, and flash sales.'
        WHEN primary_traffic_source = 'Email' THEN 'RETARGETED LOYALIST: Show personalized "Based on your last purchase" items.'
        WHEN primary_traffic_source = 'YouTube' THEN 'VISUAL BUYER: Show products with video reviews and high-quality imagery.'
        ELSE 'ORGANIC BUYER: Show general bestsellers and category navigation.'
    END AS digital_marketing_action

FROM user_events
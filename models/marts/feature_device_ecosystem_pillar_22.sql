{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 💻 PILLAR 22: DEVICE ECOSYSTEM, TECH-SAVVY & OS PLATFORM ENGINE
-- =================================================================================

WITH user_browser_data AS (
    -- Step 1: User website par kis browser se sabse zyada clicks kar raha hai?
    SELECT 
        user_id,
        ANY_VALUE(browser) AS primary_browser,
        COUNT(id) AS total_clicks
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)

SELECT 
    user_id,
    primary_browser,
    
    -- 🤖 AI Persona: The Tech & Wealth Proxy (Based on Browser)
    CASE 
        WHEN primary_browser IN ('Safari', 'Mobile Safari') THEN 'Apple Ecosystem (High LTV Potential)'
        WHEN primary_browser IN ('Chrome', 'Firefox', 'Edge', 'IE') THEN 'Android/Windows Ecosystem (Value Focused)'
        ELSE 'Unknown/Other Ecosystem'
    END AS device_persona,
    
    -- 🚀 Real-Time UI & Payment Action
    CASE 
        WHEN primary_browser IN ('Safari', 'Mobile Safari') THEN 'UI TRIGGER: Show "Apple Pay" directly. Display Premium minimalistic UI.'
        WHEN primary_browser IN ('Chrome', 'Firefox', 'Edge', 'IE') THEN 'UI TRIGGER: Show "Google Pay / Cards". Emphasize comparison features and specs.'
        ELSE 'Standard Checkout UI'
    END AS device_marketing_action

FROM user_browser_data
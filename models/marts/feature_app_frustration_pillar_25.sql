{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🤬 PILLAR 25: APP FRUSTRATION, UX STRUGGLE & RAGE CLICK ENGINE
-- =================================================================================

WITH session_level_data AS (
    -- Step 1: Har session ki kundli nikalna (Kitne clicks, kitni der ruka, kya cart mein daala?)
    SELECT 
        user_id,
        session_id,
        COUNT(id) AS total_events_in_session,
        SUM(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS cart_events,
        TIMESTAMP_DIFF(MAX(created_at), MIN(created_at), SECOND) AS session_duration_seconds
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL
    GROUP BY user_id, session_id
),

user_frustration_summary AS (
    -- Step 2: User ke saare sessions ka nichod nikalna
    SELECT 
        user_id,
        COUNT(session_id) AS total_sessions,
        MAX(total_events_in_session) AS max_clicks_in_single_session,
        -- 🧠 The Proxy Logic: 30 se zyada click bina kisi cart add ke = Rage Click!
        SUM(CASE WHEN total_events_in_session > 30 AND cart_events = 0 THEN 1 ELSE 0 END) AS rage_click_sessions,
        ROUND(AVG(session_duration_seconds), 1) AS avg_session_duration_seconds
    FROM session_level_data
    GROUP BY user_id
)

SELECT 
    user_id,
    total_sessions,
    max_clicks_in_single_session,
    rage_click_sessions,
    avg_session_duration_seconds,

    -- 🤖 AI Persona: The UX Experience Segment
    CASE 
        WHEN rage_click_sessions > 0 THEN 'Frustrated User (Rage Clicker)'
        WHEN max_clicks_in_single_session BETWEEN 15 AND 30 AND avg_session_duration_seconds > 600 THEN 'Lost Explorer (Needs Guidance)'
        ELSE 'Smooth Navigator'
    END AS ux_experience_segment,

    -- 🚀 Real-Time Product & Support Action
    CASE 
        WHEN rage_click_sessions > 0 THEN 'SUPPORT TRIGGER: Pop up Live Chat immediately ("Having trouble finding something?"). Flag session for UX team.'
        WHEN max_clicks_in_single_session BETWEEN 15 AND 30 AND avg_session_duration_seconds > 600 THEN 'UI NUDGE: Simplify screen. Show "Top Categories" and "Recently Viewed" to get them back on track.'
        ELSE 'Maintain standard interface.'
    END AS ux_marketing_action

FROM user_frustration_summary
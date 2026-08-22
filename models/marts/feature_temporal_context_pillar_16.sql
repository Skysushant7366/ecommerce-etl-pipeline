{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- ⏱️ PILLAR 16: TEMPORAL SHOPPING CONTEXT & TIMING ENGINE
-- =================================================================================

WITH time_extracts AS (
    -- Step 1: Har order ka Ghanta (Hour) aur Din (Day) nikalna
    SELECT 
        user_id,
        EXTRACT(HOUR FROM order_created_at) AS order_hour,
        EXTRACT(DAYOFWEEK FROM order_created_at) AS order_dow -- 1 = Sunday, 7 = Saturday
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
),

user_time_summary AS (
    -- Step 2: User ne kis waqt aur kis din sabse zyada shopping ki
    SELECT 
        user_id,
        COUNT(*) AS total_successful_orders,
        
        -- Time of Day Bins
        SUM(CASE WHEN order_hour BETWEEN 0 AND 5 THEN 1 ELSE 0 END) AS late_night_orders,
        SUM(CASE WHEN order_hour BETWEEN 6 AND 11 THEN 1 ELSE 0 END) AS morning_orders,
        SUM(CASE WHEN order_hour BETWEEN 12 AND 17 THEN 1 ELSE 0 END) AS afternoon_orders,
        SUM(CASE WHEN order_hour BETWEEN 18 AND 23 THEN 1 ELSE 0 END) AS evening_orders,
        
        -- Weekday vs Weekend Bins
        SUM(CASE WHEN order_dow IN (1, 7) THEN 1 ELSE 0 END) AS weekend_orders,
        SUM(CASE WHEN order_dow IN (2, 3, 4, 5, 6) THEN 1 ELSE 0 END) AS weekday_orders
    FROM time_extracts
    GROUP BY user_id
)

SELECT 
    user_id,
    total_successful_orders,
    
    -- 🤖 AI Persona 1: The Time-of-Day Shopper
    CASE 
        WHEN late_night_orders >= (total_successful_orders * 0.4) THEN 'Night Owl (12 AM - 6 AM)'
        WHEN evening_orders >= (total_successful_orders * 0.4) THEN 'Evening Scroller (6 PM - 12 AM)'
        WHEN afternoon_orders >= (total_successful_orders * 0.4) THEN 'Office Hour Buyer (12 PM - 6 PM)'
        WHEN morning_orders >= (total_successful_orders * 0.4) THEN 'Morning Shopper (6 AM - 12 PM)'
        ELSE 'Anytime Shopper'
    END AS preferred_shopping_time,
    
    -- 🤖 AI Persona 2: The Day-of-Week Shopper
    CASE 
        WHEN weekend_orders >= (total_successful_orders * 0.6) THEN 'Weekend Warrior'
        WHEN weekday_orders >= (total_successful_orders * 0.8) THEN 'Weekday Routine Buyer'
        ELSE 'Flexible Day Shopper'
    END AS preferred_shopping_day,
    
    -- 🚀 Real-Time Marketing Action (Right Message, Right Time)
    CASE 
        WHEN late_night_orders >= (total_successful_orders * 0.4) THEN 'TIMING LOCK: Send Push Notifications strictly after 10 PM. High impulse tendency.'
        WHEN afternoon_orders >= (total_successful_orders * 0.4) THEN 'TIMING LOCK: Send emails at 1 PM (Lunch Break). Emphasize fast checkout.'
        WHEN weekend_orders >= (total_successful_orders * 0.6) THEN 'TIMING LOCK: Start promotional campaigns on Friday evening for this user.'
        WHEN morning_orders >= (total_successful_orders * 0.4) THEN 'TIMING LOCK: Send "Deal of the Day" SMS at 8 AM.'
        ELSE 'Apply standard dynamic Send-Time Optimization (STO).'
    END AS temporal_marketing_action

FROM user_time_summary
{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- ⏰ PILLAR 9 (V7 - COUNTRY EXPLICIT EDITION): WITH USER COUNTRY IN OUTPUT
-- =================================================================================

WITH base_order_data AS (
    SELECT DISTINCT
        order_id,
        user_id,
        COALESCE(user_country, 'United States') AS user_country,
        order_created_at
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
),

timezone_adjusted_data AS (
    SELECT 
        order_id,
        user_id,
        user_country,
        CASE 
            WHEN user_country IN ('United States', 'US', 'Colombia', 'Brasil', 'Brazil') THEN DATETIME(order_created_at, 'America/New_York')
            WHEN user_country IN ('United Kingdom', 'UK', 'Spain', 'France', 'Germany', 'Belgium', 'Deutschland', 'España') THEN DATETIME(order_created_at, 'Europe/London')
            WHEN user_country IN ('China', 'Japan', 'South Korea') THEN DATETIME(order_created_at, 'Asia/Shanghai')
            WHEN user_country = 'Australia' THEN DATETIME(order_created_at, 'Australia/Sydney')
            ELSE DATETIME(order_created_at, 'UTC')
        END AS local_order_time,
        CASE 
            WHEN user_country IN ('Australia', 'Brasil', 'Brazil', 'Colombia') THEN 'Southern_Hemisphere'
            ELSE 'Northern_Hemisphere'
        END AS hemisphere
    FROM base_order_data
),

time_stats AS (
    SELECT 
        order_id,
        user_id,
        user_country,
        EXTRACT(DAYOFWEEK FROM local_order_time) AS day_of_week, 
        EXTRACT(HOUR FROM local_order_time) AS hour_of_day,
        EXTRACT(MONTH FROM local_order_time) AS month_of_year,
        hemisphere
    FROM timezone_adjusted_data
),

aggregated_stats AS (
    SELECT 
        user_id,
        ANY_VALUE(user_country) AS user_country,
        COUNT(DISTINCT order_id) AS total_valid_orders,
        
        SUM(CASE WHEN day_of_week IN (1, 7) THEN 1 ELSE 0 END) AS weekend_orders,
        SUM(CASE WHEN day_of_week BETWEEN 2 AND 6 THEN 1 ELSE 0 END) AS weekday_orders,
        
        SUM(CASE WHEN hour_of_day BETWEEN 6 AND 11 THEN 1 ELSE 0 END) AS morning_orders,
        SUM(CASE WHEN hour_of_day BETWEEN 12 AND 16 THEN 1 ELSE 0 END) AS afternoon_orders,
        SUM(CASE WHEN hour_of_day BETWEEN 17 AND 21 THEN 1 ELSE 0 END) AS evening_orders,
        SUM(CASE WHEN hour_of_day >= 22 OR hour_of_day <= 5 THEN 1 ELSE 0 END) AS night_orders,
        
        SUM(CASE 
            WHEN hemisphere = 'Northern_Hemisphere' AND month_of_year IN (12, 1, 2) THEN 1 
            WHEN hemisphere = 'Southern_Hemisphere' AND month_of_year IN (6, 7, 8) THEN 1 
            ELSE 0 END) AS winter_orders,
        SUM(CASE 
            WHEN hemisphere = 'Northern_Hemisphere' AND month_of_year IN (6, 7, 8) THEN 1 
            WHEN hemisphere = 'Southern_Hemisphere' AND month_of_year IN (12, 1, 2) THEN 1 
            ELSE 0 END) AS summer_orders,
        SUM(CASE 
            WHEN hemisphere = 'Northern_Hemisphere' AND month_of_year IN (3, 4, 5) THEN 1 
            WHEN hemisphere = 'Southern_Hemisphere' AND month_of_year IN (9, 10, 11) THEN 1 
            ELSE 0 END) AS spring_orders,
        SUM(CASE 
            WHEN hemisphere = 'Northern_Hemisphere' AND month_of_year IN (9, 10, 11) THEN 1 
            WHEN hemisphere = 'Southern_Hemisphere' AND month_of_year IN (3, 4, 5) THEN 1 
            ELSE 0 END) AS autumn_orders

    FROM time_stats
    GROUP BY user_id
)

SELECT 
    user_id,
    user_country, 
    total_valid_orders AS total_valid_purchases,
    
    -- 🔥 FIX: AI ke liye raw numbers
    weekend_orders,
    weekday_orders,
    
    CASE 
        WHEN total_valid_orders >= 3 THEN 'High Confidence'
        WHEN total_valid_orders = 2 THEN 'Medium Confidence'
        ELSE 'Low Confidence (Guessed from 1 order)'
    END AS ai_confidence_score,
    
    CASE 
        WHEN weekend_orders > weekday_orders THEN 'Weekend Shopper'
        WHEN weekday_orders > weekend_orders THEN 'Weekday Shopper'
        ELSE 'Flexible / Mixed Shopper'
    END AS preferred_shopping_day,
    
    CASE 
        WHEN morning_orders >= afternoon_orders AND morning_orders >= evening_orders AND morning_orders >= night_orders AND morning_orders > 0 THEN 'Morning (6 AM - 12 PM)'
        WHEN afternoon_orders >= morning_orders AND afternoon_orders >= evening_orders AND afternoon_orders >= night_orders AND afternoon_orders > 0 THEN 'Afternoon (12 PM - 5 PM)'
        WHEN evening_orders >= morning_orders AND evening_orders >= afternoon_orders AND evening_orders >= night_orders AND evening_orders > 0 THEN 'Evening (5 PM - 10 PM)'
        WHEN night_orders >= morning_orders AND night_orders >= afternoon_orders AND night_orders >= evening_orders AND night_orders > 0 THEN 'Night Owl (10 PM - 6 AM)'
        ELSE 'Mixed / Unspecified'
    END AS preferred_shopping_time,
    
    CASE 
        WHEN winter_orders >= summer_orders AND winter_orders >= spring_orders AND winter_orders >= autumn_orders AND winter_orders > 0 THEN 'Winter/Holiday Shopper'
        WHEN summer_orders >= winter_orders and summer_orders >= spring_orders AND summer_orders >= autumn_orders AND summer_orders > 0 THEN 'Summer Shopper'
        WHEN spring_orders >= winter_orders AND spring_orders >= summer_orders AND spring_orders >= autumn_orders AND spring_orders > 0 THEN 'Spring Shopper'
        WHEN autumn_orders >= winter_orders AND autumn_orders >= summer_orders AND autumn_orders >= spring_orders AND autumn_orders > 0 THEN 'Autumn/Festive Shopper'
        ELSE 'All-Season Shopper'
    END AS preferred_season

FROM aggregated_stats
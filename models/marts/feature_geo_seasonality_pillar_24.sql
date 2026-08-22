{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🌦️ PILLAR 24: GEO-WEATHER, CLIMATE ZONE & SEASONALITY ENGINE
-- =================================================================================

WITH user_geo_behavior AS (
    -- Step 1: User ki Location aur Kis Mausam mein usne kharidari ki
    SELECT 
        user_id,
        ANY_VALUE(user_country) AS country,
        ANY_VALUE(user_state) AS state,
        COUNT(DISTINCT order_item_id) AS total_items,
        
        -- Proxy Metrics: Winter vs Summer Shopping Peaks
        -- (Maan rahe hain Q4/Q1 thand ka time hai, aur Q2/Q3 garmi ka - Northern Hemisphere default)
        SUM(CASE WHEN EXTRACT(MONTH FROM order_created_at) IN (11, 12, 1, 2) THEN 1 ELSE 0 END) AS winter_holiday_purchases,
        SUM(CASE WHEN EXTRACT(MONTH FROM order_created_at) IN (5, 6, 7, 8) THEN 1 ELSE 0 END) AS summer_purchases
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
)

SELECT 
    user_id,
    country,
    state,
    total_items,
    
    -- 🤖 AI Persona 1: The Climate Zone Proxy (Location se Mausam ka andaza)
    CASE 
        WHEN country IN ('Brasil', 'India', 'Colombia', 'Australia') THEN 'Tropical/Warm Zone (Lightweight & Summer focus)'
        WHEN country IN ('United Kingdom', 'Germany', 'France', 'Poland') THEN 'Cold/Temperate Zone (Layering & Winter focus)'
        -- 🔥 Micro-Segmentation (State-Level for USA)
        WHEN country = 'United States' AND state IN ('Florida', 'Texas', 'California', 'Hawaii') THEN 'US Sunbelt (Year-round warm)'
        WHEN country = 'United States' AND state IN ('New York', 'Illinois', 'Michigan', 'Alaska') THEN 'US Snowbelt (Heavy Winter)'
        ELSE 'Mixed/Standard Climate'
    END AS climate_zone_segment,
    
    -- 🤖 AI Persona 2: The Seasonal Buyer
    CASE 
        WHEN winter_holiday_purchases >= (total_items * 0.5) AND total_items > 1 THEN 'Holiday & Winter Heavy Shopper'
        WHEN summer_purchases >= (total_items * 0.5) AND total_items > 1 THEN 'Summer Wardrobe Shopper'
        ELSE 'Year-Round Balanced Shopper'
    END AS seasonal_buying_pattern,
    
    -- 🚀 Real-Time Merchandising & UI Action
    CASE 
        WHEN country IN ('Brasil', 'India', 'Colombia') THEN 'GEO-LOCK: Demote heavy jackets/sweaters from homepage. Boost breathable fabrics globally.'
        WHEN country = 'United States' AND state IN ('Florida', 'Hawaii') THEN 'GEO-LOCK: Hide snow gear. Show swimwear, shorts, and activewear year-round.'
        WHEN country = 'United States' AND state IN ('New York', 'Illinois', 'Alaska') THEN 'GEO-LOCK: Push thick coats, boots, and thermals heavily during Q4/Q1.'
        WHEN winter_holiday_purchases >= (total_items * 0.5) AND total_items > 1 THEN 'SEASONAL TRIGGER: This user buys heavily in Q4. Send "Early Black Friday VIP Access" in October.'
        ELSE 'Apply standard localized catalog sorting.'
    END AS geo_merchandising_action

FROM user_geo_behavior
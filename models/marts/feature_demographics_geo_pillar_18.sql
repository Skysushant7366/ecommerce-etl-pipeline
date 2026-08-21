{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🌍 PILLAR 18: DEMOGRAPHIC & GEO-CULTURAL PERSONALIZATION ENGINE
-- =================================================================================

WITH user_demographics AS (
    -- Step 1: Har user ka basic detail nikalna (Gender, Age, Country)
    SELECT 
        user_id,
        ANY_VALUE(user_age) AS age,
        ANY_VALUE(user_gender) AS gender,
        ANY_VALUE(user_country) AS country,
        ANY_VALUE(user_state) AS state,
        COUNT(order_id) AS total_orders
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)

SELECT 
    user_id,
    age,
    gender,
    country,
    state,
    
    -- 🤖 AI Persona 1: Generational Cohort (Umar ke hisaab se Soch)
    CASE 
        WHEN age BETWEEN 12 AND 26 THEN 'Gen Z (Trend & Hype Driven)'
        WHEN age BETWEEN 27 AND 42 THEN 'Millennials (Utility & Quality Focused)'
        WHEN age BETWEEN 43 AND 58 THEN 'Gen X (Brand Loyal & Premium)'
        WHEN age > 58 THEN 'Boomers (Comfort & Customer Service)'
        ELSE 'Unknown Generation'
    END AS generational_cohort,
    
    -- 🤖 AI Persona 2: Geo-Market Segment (Desh ke hisaab se purchasing power)
    CASE 
        WHEN country IN ('United States', 'United Kingdom', 'Australia', 'Germany', 'France') THEN 'Tier 1 Global (High Purchasing Power)'
        WHEN country IN ('Brasil', 'China', 'India', 'Japan', 'South Korea') THEN 'Emerging/High Volume Market'
        ELSE 'Standard Global Market'
    END AS geo_market_segment,
    
    -- 🚀 Real-Time AI Marketing Action (Right Tone for Right Age)
    CASE 
        WHEN age BETWEEN 12 AND 26 AND gender = 'F' THEN 'TRENDING ALERT: Show viral fashion styles and influencer collaborations. Focus on aesthetics.'
        WHEN age BETWEEN 12 AND 26 AND gender = 'M' THEN 'HYPE ALERT: Show sneakers, streetwear, and tech accessories.'
        WHEN age BETWEEN 27 AND 42 THEN 'LIFESTYLE MATCH: Highlight durability, verified reviews, and versatile work-to-weekend wear.'
        WHEN age > 42 THEN 'TRUST & COMFORT: Emphasize easy returns, premium fabrics, and classic fits. Use larger fonts in emails.'
        ELSE 'Apply standard demographic targeting.'
    END AS demographic_marketing_action

FROM user_demographics
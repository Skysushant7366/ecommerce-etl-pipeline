{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🧬 PILLAR 11: USER DEMOGRAPHICS & GENERATIONAL COHORT ENGINE
-- =================================================================================

WITH user_base AS (
    -- Flat table se unique users ka latest demographic data nikal rahe hain
    SELECT DISTINCT
        user_id,
        ANY_VALUE(user_age) AS user_age,
        ANY_VALUE(user_gender) AS user_gender,
        ANY_VALUE(user_country) AS user_country
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)

SELECT 
    user_id,
    user_age,
    user_gender,
    user_country,
    
    -- 📊 The Cohort Logic (Dividing ages into actionable segments)
    CASE 
        WHEN user_age < 18 THEN 'Under 18 (Teens)'
        WHEN user_age BETWEEN 18 AND 24 THEN '18-24 (Gen Z / College)'
        WHEN user_age BETWEEN 25 AND 34 THEN '25-34 (Millennials / Young Professionals)'
        WHEN user_age BETWEEN 35 AND 49 THEN '35-49 (Gen X / Established)'
        WHEN user_age >= 50 THEN '50+ (Seniors / Boomers)'
        ELSE 'Unknown'
    END AS age_cohort,
    
    -- 🎯 The "Real Tadka": Actionable Marketing Tone
    CASE 
        WHEN user_age BETWEEN 18 AND 24 THEN 'Trendy, FOMO-driven, Short-form (Reels/Shorts) style'
        WHEN user_age BETWEEN 25 AND 34 THEN 'Value-driven, Premium lifestyle, Career & Utility focused'
        WHEN user_age >= 35 THEN 'Quality, Durability, Family-oriented, Classic tone'
        ELSE 'Standard Catalog Tone'
    END AS recommended_ad_tone

FROM user_base
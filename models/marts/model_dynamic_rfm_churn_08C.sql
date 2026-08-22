{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- ⏳ MODEL 8C (BOSS #3): THE CHURN ENGINE (DYNAMIC RFM & SURVIVAL PROBABILITY)
-- =================================================================================

WITH user_base_stats AS (
    -- Step 1: Customer ka total history nikalna (Complete orders only)
    SELECT 
        user_id,
        MAX(DATE(order_created_at)) AS last_order_date,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(sale_price) AS total_spend
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status = 'Complete'
    GROUP BY user_id
),

rfm_scoring AS (
    -- Step 2: The Architect's RFM Logic (Recency, Frequency, Monetary Scores)
    SELECT 
        user_id,
        last_order_date,
        DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) AS recency_days,
        total_orders AS frequency,
        total_spend AS monetary_value,
        
        -- RECENCY SCORE (1 to 5)
        CASE 
            WHEN DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) <= 30 THEN 5
            WHEN DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) <= 60 THEN 4
            WHEN DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) <= 90 THEN 3
            WHEN DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) <= 180 THEN 2
            ELSE 1 
        END AS r_score,
        
        -- FREQUENCY SCORE (1 to 5)
        CASE 
            WHEN total_orders >= 5 THEN 5
            WHEN total_orders = 4 THEN 4
            WHEN total_orders = 3 THEN 3
            WHEN total_orders = 2 THEN 2
            ELSE 1 
        END AS f_score,
        
        -- MONETARY SCORE (1 to 5 based on Percentiles)
        NTILE(5) OVER (ORDER BY total_spend ASC) AS m_score
    FROM user_base_stats
)

-- Step 3: THE TIME-DECAY SURVIVAL ENGINE & ACTION PLAN
SELECT 
    user_id,
    recency_days,
    frequency,
    ROUND(monetary_value, 2) AS lifetime_value_usd,
    CAST(CONCAT(r_score, f_score, m_score) AS INT64) AS rfm_score,
    
    -- 🧠 THE DATA SCIENCE MATH: Exponential Decay Function
    ROUND(EXP(-1 * (recency_days / 90.0)) * 100, 2) AS survival_probability_pct,

    -- 🚀 LONE WOLF BUSINESS ACTION
    CASE 
        WHEN ROUND(EXP(-1 * (recency_days / 90.0)) * 100, 2) >= 80.0 AND frequency > 2 
             THEN '👑 CHAMPION: Very safe! Give VIP early access to new products.'
        
        WHEN ROUND(EXP(-1 * (recency_days / 90.0)) * 100, 2) BETWEEN 30.0 AND 79.9 
             THEN '✅ STABLE: Normal marketing flow.'
        
        WHEN ROUND(EXP(-1 * (recency_days / 90.0)) * 100, 2) BETWEEN 15.0 AND 29.9 AND monetary_value > 100 
             THEN '⚠️ SLIPPING AWAY: High value user. Send targeted product recommendations!'
        
        WHEN ROUND(EXP(-1 * (recency_days / 90.0)) * 100, 2) < 15.0 AND monetary_value > 200 
             THEN '🚨 CHURN ALERT (RED): Dying Whale! Send "We Miss You 40% OFF" coupon NOW!'
             
        ELSE '💤 LOW VALUE CHURN: Let them go, do not waste marketing budget.'
    END AS churn_action_plan

FROM rfm_scoring

{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 📊 PILLAR 21: THE DEDICATED RFM SCORE ENGINE (Recency, Frequency, Monetary)
-- =================================================================================

WITH user_raw_activity AS (
    -- Step 1: Har user ka Raw data nikalna
    SELECT 
        user_id,
        MAX(DATE(order_created_at)) AS last_order_date,
        COUNT(DISTINCT order_id) AS frequency,
        ROUND(SUM(sale_price), 2) AS monetary_value
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
),

dataset_today AS (
    -- Data ka aakhiri din taaki math fail na ho
    SELECT MAX(last_order_date) AS global_max_date FROM user_raw_activity
),

rfm_metrics AS (
    -- Step 2: Recency Days Calculate Karna
    SELECT 
        u.user_id,
        DATE_DIFF(d.global_max_date, u.last_order_date, DAY) AS recency_days,
        u.frequency,
        u.monetary_value
    FROM user_raw_activity u
    CROSS JOIN dataset_today d
),

rfm_scoring AS (
    -- Step 3: THE MATH MAGiC - NTILE(5) Scoring
    SELECT 
        user_id,
        recency_days,
        frequency,
        monetary_value,
        -- Recency: Kam din matlab score zyada (5 is Best) -> Isliye DESC
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score, 
        -- Frequency: Zyada orders matlab score zyada (5 is Best) -> Isliye ASC
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score, 
        -- Monetary: Zyada kharcha matlab score zyada (5 is Best) -> Isliye ASC
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM rfm_metrics
)

-- Step 4: Final Segmentation (Creating the RFM Brain)
SELECT 
    user_id,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    -- RFM Code banana (e.g., '555', '111', '455')
    CONCAT(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS rfm_code,
    
    -- 🤖 THE RFM MASTER SEGMENTATION
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions (555)'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score <= 3 THEN 'Recent & Promising'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Cant Lose Them (High Risk Whales)'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost / Hibernating'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN m_score = 5 THEN 'Big Spenders (Needs Nurturing)'
        ELSE 'Average / Standard Users'
    END AS rfm_segment,

    -- 🚀 DATA SCIENCE ACTION TRIGGER
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'REWARD: Give early access to new products. No discounts needed. Ask for referrals.'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score <= 3 THEN 'NURTURE: Offer onboarding support & limited-time discount to push them to next frequency tier.'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'URGENT WIN-BACK: High value churning! Personalized outreach, massive exclusive offer, assign customer success agent.'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'IGNORE: Do not waste marketing/ad spend here. Keep on standard cheap email list.'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'UPSELL: Recommend higher margin items. Highlight loyalty perks.'
        WHEN m_score = 5 THEN 'PREMIUM: Market only luxury items, offer VIP concierge service.'
        ELSE 'Standard algorithmic product recommendations.'
    END AS rfm_action

FROM rfm_scoring
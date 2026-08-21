{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🔄 PILLAR 20: DYNAMIC LIFECYCLE & TIERED CHURN ENGINE
-- =================================================================================

WITH user_timeline AS (
    -- Step 1: User ki pehli aur aakhiri kharidari ka din nikalna
    SELECT 
        user_id,
        MAX(DATE(order_created_at)) AS last_purchase_date,
        MIN(DATE(order_created_at)) AS first_purchase_date,
        COUNT(order_id) AS total_orders
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
),

lifecycle_metrics AS (
    -- Step 2: Aaj ke din se uska gap nikalna (Kitne din se gayab hai?)
    SELECT 
        user_id,
        total_orders,
        DATE_DIFF(CURRENT_DATE(), first_purchase_date, DAY) AS account_age_days,
        DATE_DIFF(CURRENT_DATE(), last_purchase_date, DAY) AS days_since_last_purchase
    FROM user_timeline
)

SELECT 
    user_id,
    total_orders,
    account_age_days,
    days_since_last_purchase,
    
    -- 🤖 AI Persona: Tiered Churn Status
    CASE 
        WHEN days_since_last_purchase <= 30 THEN 'Highly Active (0-30 Days)'
        WHEN days_since_last_purchase BETWEEN 31 AND 60 THEN 'Slipping Away (31-60 Days)'
        WHEN days_since_last_purchase BETWEEN 61 AND 90 THEN 'High Risk of Churn (61-90 Days)'
        WHEN days_since_last_purchase > 90 THEN 'Officially Churned (90+ Days)'
        ELSE 'Unknown'
    END AS dynamic_churn_status,
    
    -- 🚀 Real-Time AI Retention Action
    CASE 
        WHEN days_since_last_purchase <= 30 THEN 'ENGAGE: Ask for product reviews and referrals. Do not discount.'
        WHEN days_since_last_purchase BETWEEN 31 AND 60 THEN 'GENTLE NUDGE: Send "New Arrivals" newsletter based on their past category.'
        WHEN days_since_last_purchase BETWEEN 61 AND 90 THEN 'URGENT RE-ENGAGEMENT: Send a 10% personalized discount code expiring in 48 hours.'
        WHEN days_since_last_purchase > 90 THEN 'WIN-BACK CAMPAIGN: Send aggressive 20%+ discount or "We miss you" freebie.'
        ELSE 'Standard Monitoring.'
    END AS churn_marketing_action

FROM lifecycle_metrics
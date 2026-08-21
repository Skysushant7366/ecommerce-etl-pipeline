{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

WITH system_dates AS (
    SELECT DATE_SUB(MAX(DATE(order_created_at)), INTERVAL 90 DAY) AS snapshot_date
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
),

user_base AS (
    SELECT 
        user_id, 
        MIN(DATE(order_created_at)) AS join_date,
        MAX(DATE(order_created_at)) AS last_ever_order_date
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    GROUP BY user_id
),

windowed_data AS (
    SELECT 
        t.user_id,
        t.order_id,
        t.sale_price,
        (t.product_retail_price - t.sale_price) AS discount_amount, 
        t.order_status,
        DATE(t.order_created_at) AS order_date,
        DATE_DIFF(s.snapshot_date, DATE(t.order_created_at), DAY) AS days_before_snapshot
    FROM {{ ref('fct_order_items') }} t -- 👈 DBT Magic (Ref)
    CROSS JOIN system_dates s
)

SELECT 
    w.user_id,
    
    -- 🧠 1. CUSTOMER LIFELINE & LOYALTY
    DATE_DIFF((SELECT snapshot_date FROM system_dates), u.join_date, DAY) AS customer_tenure_days,
    
    -- 📊 2. THE PAST 365 DAYS (Features)
    COALESCE(SUM(CASE WHEN days_before_snapshot BETWEEN 0 AND 365 THEN w.sale_price END), 0) AS l365_total_spend,
    COUNT(DISTINCT CASE WHEN days_before_snapshot BETWEEN 0 AND 365 THEN w.order_id END) AS l365_total_orders,
    MIN(CASE WHEN days_before_snapshot BETWEEN 0 AND 365 THEN days_before_snapshot END) AS days_since_last_order,
    COALESCE(SAFE_DIVIDE(365, NULLIF(COUNT(DISTINCT CASE WHEN days_before_snapshot BETWEEN 0 AND 365 THEN w.order_id END), 0)), 365) AS avg_days_between_orders_l365,
    
    -- 🤑 3. DISCOUNT AFFINITY
    COALESCE(SAFE_DIVIDE(SUM(CASE WHEN days_before_snapshot BETWEEN 0 AND 365 AND w.discount_amount > 0 THEN w.discount_amount END), NULLIF(SUM(CASE WHEN days_before_snapshot BETWEEN 0 AND 365 THEN (w.sale_price + w.discount_amount) END), 0)), 0) AS discount_dependency_ratio,

    -- 🎯 THE TARGET [y]: NEXT 90 DAYS LTV (Ab isme actual dollar amounts aayenge)
    COALESCE(SUM(CASE WHEN days_before_snapshot BETWEEN -90 AND -1 THEN w.sale_price END), 0) AS target_next_90d_spend

FROM windowed_data w
JOIN user_base u ON w.user_id = u.user_id
-- 🔥 THE FIX: Yahan darwaza >= -90 tak khol diya taaki Target (agle 90 din) calculate ho sake!
WHERE w.days_before_snapshot >= -90 
GROUP BY w.user_id, u.join_date
{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =========================================================
-- 🛡️ ENGINE 1: IP BOT SWARM DETECTION (From stg_events)
-- =========================================================
WITH ip_risk AS (
  SELECT ip_address, COUNT(DISTINCT user_id) AS users_per_ip
  FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
  WHERE user_id IS NOT NULL
  GROUP BY ip_address
),
user_network_risk AS (
  SELECT e.user_id, MAX(ir.users_per_ip) AS max_users_on_same_ip, COUNT(DISTINCT e.session_id) AS total_sessions
  FROM {{ ref('stg_events') }} e -- 👈 DBT Magic (Ref)
  JOIN ip_risk ir ON e.ip_address = ir.ip_address
  WHERE e.user_id IS NOT NULL
  GROUP BY e.user_id
),

-- =========================================================
-- 💰 ENGINE 2: FINANCIAL & ABUSE LOGIC (From fct_order_items)
-- =========================================================
transactional_risk AS (
  SELECT
    user_id,
    MAX(user_country) AS user_country,
    COUNT(DISTINCT order_id) AS total_orders_ever,
    COUNT(order_item_id) AS total_items_purchased,
    SUM(sale_price) AS total_actual_paid,
    -- Promo leech calculation
    SUM(product_retail_price - sale_price) AS total_discount_claimed,
    -- Suspicious returns/cancels
    SUM(CASE WHEN order_status IN ('Returned', 'Cancelled') THEN 1 ELSE 0 END) AS total_suspicious_items,
    -- Account age
    DATE_DIFF(MAX(DATE(order_created_at)), MIN(DATE(order_created_at)), DAY) AS account_age_days
  FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
  GROUP BY user_id
),

-- =========================================================
-- ⏱️ ENGINE 3: VELOCITY SPIKE DETECTION 
-- =========================================================
user_daily_velocity AS (
  SELECT user_id, DATE(order_created_at) AS order_date, COUNT(DISTINCT order_id) AS orders_in_a_day
  FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
  GROUP BY user_id, order_date
),
max_velocity AS (
  SELECT user_id, MAX(orders_in_a_day) AS max_orders_in_a_single_day
  FROM user_daily_velocity
  GROUP BY user_id
)

-- =========================================================
-- 🎯 FINAL MERGE: THE V3 GOD-MODE GATEKEEPER
-- =========================================================
SELECT
  t.user_id,
  t.user_country,
  t.total_orders_ever,
  t.total_actual_paid,

  -- 🚩 CHEAT FLAG 1: Return/Cancel Abuse Rate (% mein)
  ROUND(SAFE_DIVIDE(t.total_suspicious_items, t.total_items_purchased) * 100, 2) AS return_abuse_pct,

  -- 🚩 CHEAT FLAG 2: Promo Leech Ratio (Free loota vs Paise diye)
  ROUND(SAFE_DIVIDE(t.total_discount_claimed, NULLIF(t.total_actual_paid, 0)), 2) AS discount_leech_ratio,

  -- 🚩 CHEAT FLAG 3: Lifetime Velocity vs Daily Spike Check
  ROUND(SAFE_DIVIDE(t.total_orders_ever, CASE WHEN t.account_age_days = 0 THEN 1 ELSE t.account_age_days END), 2) AS lifetime_daily_velocity,
  v.max_orders_in_a_single_day,

  -- 🚩 CHEAT FLAG 4: Network Bot Check (From Events)
  IFNULL(n.max_users_on_same_ip, 1) AS max_users_on_same_ip,
  IFNULL(n.total_sessions, 1) AS total_sessions,

  -- 🚨 MASTER SUSPECT FLAG (AI ke liye raw hints)
  CASE
    WHEN SAFE_DIVIDE(t.total_suspicious_items, t.total_items_purchased) >= 0.5 AND t.total_items_purchased > 2 THEN 1 
    WHEN SAFE_DIVIDE(t.total_discount_claimed, NULLIF(t.total_actual_paid, 0)) >= 1.5 THEN 1 -- Promo Abuser
    WHEN v.max_orders_in_a_single_day >= 4 THEN 1 -- Velocity abuser
    WHEN n.max_users_on_same_ip >= 3 THEN 1 -- IP Swarm Bot
    ELSE 0
  END AS is_fraud_suspect

FROM transactional_risk t
LEFT JOIN max_velocity v ON t.user_id = v.user_id
LEFT JOIN user_network_risk n ON t.user_id = n.user_id
WHERE t.total_orders_ever >= 3
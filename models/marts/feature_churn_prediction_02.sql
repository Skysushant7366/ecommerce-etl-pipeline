{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

WITH max_date_table AS (
  SELECT MAX(DATE(order_created_at)) as max_db_date
  FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
),

observation_window AS (
  SELECT DATE_SUB(max_db_date, INTERVAL 90 DAY) AS cutoff_date
  FROM max_date_table
),

feature_data AS (
  SELECT
    user_id,
    MAX(user_country) AS user_country,
    
    -- 1. BASE VOLUME (Purana wala)
    COUNT(DISTINCT order_id) AS historical_orders,
    SUM(sale_price) AS historical_spend,
    
    -- 2. 🚀 ADVANCED MULTIVARIATE: RECENCY ENGINE
    DATE_DIFF(MAX(cutoff_date), MAX(DATE(order_created_at)), DAY) AS recency_days_from_cutoff,
    
    -- 3. 🚀 ADVANCED MULTIVARIATE: VALUE ENGINE (AOV)
    SAFE_DIVIDE(SUM(sale_price), COUNT(DISTINCT order_id)) AS avg_order_value,
    
    -- 4. 🚀 ADVANCED MULTIVARIATE: PACING/VELOCITY ENGINE
    SAFE_DIVIDE(
        DATE_DIFF(MAX(DATE(order_created_at)), MIN(DATE(order_created_at)), DAY), 
        NULLIF(COUNT(DISTINCT order_id) - 1, 0)
    ) AS avg_days_between_orders,
    
    -- 5. 🚀 ADVANCED MULTIVARIATE: RISK ENGINE (Return Percentage)
    SAFE_DIVIDE(
        COUNT(CASE WHEN order_status = 'Returned' THEN 1 END), 
        COUNT(order_item_id)
    ) AS return_rate_percent,

    -- 6. 🚀 ADVANCED MULTIVARIATE: BASKET SIZE
    SAFE_DIVIDE(COUNT(order_item_id), COUNT(DISTINCT order_id)) AS avg_items_per_order

  FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
  CROSS JOIN observation_window
  -- STRICT SHIELD: Deewar ke us paar dekhna mana hai!
  WHERE DATE(order_created_at) < cutoff_date
  GROUP BY user_id
),

target_data AS (
  SELECT DISTINCT user_id, 1 AS bought_in_future
  FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
  CROSS JOIN observation_window
  WHERE DATE(order_created_at) >= cutoff_date
)

SELECT
  f.*,
  -- 🎯 THE TARGET: Deewar ke baad aaya ya bhag gaya?
  CASE WHEN t.bought_in_future IS NULL THEN 1 ELSE 0 END AS is_churned
FROM feature_data f
LEFT JOIN target_data t 
  ON f.user_id = t.user_id
WHERE f.historical_orders > 0
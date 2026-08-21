{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

WITH user_base AS (
  SELECT
    user_id,
    user_country,
    
    -- 1. RECENCY: Aaj se kitne din pehle aakhiri kharidari ki? (Low = Active User, High = Bhag gaya)
    DATE_DIFF(CURRENT_DATE(), MAX(DATE(order_created_at)), DAY) AS days_since_last_order,
    
    -- 2. FREQUENCY: Total kitne alag-alag orders place kiye?
    COUNT(DISTINCT order_id) AS total_orders,
    
    -- 3. MONETARY: Zindagi bhar mein total kitna paisa kharcha isne?
    SUM(sale_price) AS total_spend,

    -- 4. 🚀 ADVANCED MULTIVARIATE STATS (Jisse AI deep sochega)
    AVG(sale_price) AS avg_order_value,  -- Har order pe average kitna kharchta hai?
    COUNT(returned_at) AS total_returns, -- Kitni baar saman wapas kiya?
    
    -- Return Rate Percentage (Cheater/Bargain Hunter pakadne ke liye)
    SAFE_DIVIDE(COUNT(returned_at), COUNT(order_item_id)) AS return_rate

  FROM
    {{ ref('fct_order_items') }} -- 👈 YAHAN MAGIC HUA HAI!
  WHERE 
    order_created_at IS NOT NULL 
    
    -- 🛡️ ANTI-CHEATING SHIELD: Sirf wahi data jo final ho chuka hai. 
    AND order_status IN ('Complete', 'Returned', 'Cancelled')
    
  GROUP BY
    user_id,
    user_country
)

-- Final Data Filter
SELECT 
  * 
FROM 
  user_base
WHERE 
  total_orders > 0
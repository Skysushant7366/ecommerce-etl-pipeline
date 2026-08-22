{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

SELECT
    user_id,
    
    -- 1. 🚀 MULTIVARIATE: The "Hit and Run" Velocity (Spend density)
    -- Ek order mein average kitna paisa fook raha hai? Fraudsters ek hi baar mein max value nikalte hain.
    SAFE_DIVIDE(SUM(sale_price), COUNT(DISTINCT order_id)) AS avg_order_value,
    MAX(sale_price) AS max_single_item_spend,
    
    -- 2. 🚀 THE GEOGRAPHY ANOMALY (IP Hops Ratio)
    -- Agar 3 order kiye aur 3 alag desho se kiye = Fraud Risk High (100% hop rate). 
    SAFE_DIVIDE(COUNT(DISTINCT user_country), COUNT(DISTINCT order_id)) AS country_hop_ratio,
    
    -- 3. 🚀 THE NIGHT OWL METRIC (Time-Based Anomaly)
    -- Raat 12 baje se subah 5 baje (Odd Hours) tak kitne % orders hue? 
    SAFE_DIVIDE(
        COUNT(CASE WHEN EXTRACT(HOUR FROM order_created_at) BETWEEN 0 AND 5 THEN 1 END), 
        COUNT(order_item_id)
    ) AS midnight_activity_ratio,
    
    -- 4. 🚀 THE REFUND ABUSE INDEX
    -- Zindagi bhar mein isne kitne % saman wapas/cancel kiya? (Serial returners ko pakadne ke liye)
    SAFE_DIVIDE(
        COUNT(CASE WHEN order_status IN ('Returned', 'Cancelled') THEN 1 END), 
        COUNT(order_item_id)
    ) AS return_abuse_percent,
    
    -- 5. 🚀 FREQUENCY SPIKE (Short time, max hits)
    -- Agar banda 2 din mein 10 order maar de (High frequency in short time), toh ratio low aayega = Suspicious.
    SAFE_DIVIDE(
        DATE_DIFF(MAX(DATE(order_created_at)), MIN(DATE(order_created_at)), DAY), 
        NULLIF(COUNT(DISTINCT order_id) - 1, 0)
    ) AS avg_days_between_orders

FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
GROUP BY user_id
HAVING COUNT(DISTINCT order_id) > 0
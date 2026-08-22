{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- ☠️ MODEL 6A (MULTIVARIATE GOD-MODE): TOXIC VELOCITY & MARGIN BLEED ENGINE
-- =================================================================================

WITH product_raw_data AS (
    -- Step 1: Ek hi query mein Paisa, Logistics, Traffic aur Time ka nichod
    SELECT 
        product_id,
        ANY_VALUE(product_name) AS product_name,
        ANY_VALUE(product_category) AS product_category,
        
        -- 📊 Volume Metrics
        COUNT(order_item_id) AS total_sales_volume,
        SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) AS total_returns,
        
        -- 💰 Financial Metrics (The REAL Cost of Returns)
        SUM(sale_price) AS gross_revenue,
        SUM(product_cost) AS total_cogs, -- Cost of Goods Sold (Company ki laagat)
        SUM(CASE WHEN order_status = 'Returned' THEN sale_price ELSE 0 END) AS revenue_lost_to_returns,
        SUM(CASE WHEN order_status = 'Returned' THEN product_cost ELSE 0 END) AS sunk_cost_on_returns,
        
        -- 🎯 Root Cause 1: Traffic Source (Sabse zyada return kis channel se aaye?)
        ARRAY_AGG(traffic_source ORDER BY CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END DESC LIMIT 1)[OFFSET(0)] AS worst_traffic_source,
        
        -- 🚚 Root Cause 2: Logistics (Sabse zyada return kis Godown se aaye?)
        ARRAY_AGG(distribution_center_id ORDER BY CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END DESC LIMIT 1)[OFFSET(0)] AS worst_performing_dc,
        
        -- ⏱️ Velocity (Delivery ke kitne din baad reject kiya?)
        AVG(DATE_DIFF(returned_at, delivered_at, DAY)) AS avg_days_to_return
        
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status IN ('Complete', 'Returned')
      AND product_id IS NOT NULL
    GROUP BY product_id
)

SELECT 
    *,
    -- 🧠 Core Multivariate Calculations
    ROUND(SAFE_DIVIDE(total_returns, total_sales_volume) * 100, 2) AS return_rate_pct,
    ROUND(gross_revenue - total_cogs, 2) AS absolute_gross_margin,
    -- Actual Margin Bleed: Return aane par shipping aur handling ka profit loss
    ROUND(revenue_lost_to_returns - sunk_cost_on_returns, 2) AS true_margin_lost_to_returns,
    
    -- 🚨 THE TOXICITY ENGINE (Multivariate Segmentation)
    CASE 
        -- Rule 1: High Return + Heavy Financial Loss
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) >= 0.40 AND (revenue_lost_to_returns - sunk_cost_on_returns) > 50
             THEN '☠️ LETHAL TOXICITY: High Returns & Heavy Margin Bleed'
             
        -- Rule 2: High Return but Low Financial Loss (Cheap items)
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) >= 0.40 
             THEN '🚨 HIGH RETURNS: Quality Issue (Low Margin Impact)'
             
        -- Rule 3: Warning Zone
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) BETWEEN 0.20 AND 0.39 
             THEN '⚠️ ELEVATED RISK: Monitor Profitability'
             
        -- Rule 4: The Golden Goose
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) < 0.10 AND (gross_revenue - total_cogs) > 100
             THEN '🏆 GOLDEN PRODUCT: High Margin, Low Returns'
             
        ELSE 'Insufficient Data'
    END AS multivariate_health_status,
    
    -- 💸 ARCHITECT'S ROOT CAUSE ACTION PLAN (Pinpointing the exact problem)
    CASE 
        -- If returning instantly (<= 3 days) -> Product/Image mismatch or Impulse Ad Traffic
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) >= 0.40 AND avg_days_to_return <= 3 
             THEN CONCAT('DELIST & FIX: Returns happening in ', ROUND(avg_days_to_return, 0), ' days. Image mismatch. Highest fraud from ', worst_traffic_source)
             
        -- If returning late (> 3 days) -> Sizing issue or Godown damaging products
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) >= 0.40 AND avg_days_to_return > 3
             THEN CONCAT('LOGISTICS AUDIT: High returns likely due to fit or Godown damage. Investigate DC ID: ', CAST(worst_performing_dc AS STRING))
             
        -- If perfect product -> Scale the ads
        WHEN total_sales_volume >= 3 AND SAFE_DIVIDE(total_returns, total_sales_volume) < 0.10 
             THEN CONCAT('SCALE: Push Ads heavily on ', worst_traffic_source, '. Highly profitable.')
             
        ELSE 'Maintain normal operations.'
    END AS root_cause_action_plan

FROM product_raw_data

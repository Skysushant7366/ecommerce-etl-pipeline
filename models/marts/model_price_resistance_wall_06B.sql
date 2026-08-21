{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🧱 MODEL 6B (FIXED): THE PRICE RESISTANCE WALL (VIEWS vs PURCHASE ENGINE)
-- =================================================================================

WITH product_views AS (
    -- Step 1: Clickstream data se Views aur Traffic Source nikalna
    SELECT 
        CAST(REGEXP_EXTRACT(uri, r'/product/([0-9]+)') AS INT64) AS product_id,
        ANY_VALUE(traffic_source) AS primary_traffic_source,
        COUNT(id) AS total_views
    FROM {{ ref('stg_events') }} -- 👈 DBT Magic (Ref)
    WHERE event_type = 'product' AND uri LIKE '/product/%'
    GROUP BY product_id
),

actual_sales AS (
    -- Step 2: Actual Sales (Kharidari kitni hui?)
    SELECT 
        product_id,
        COUNT(order_item_id) AS total_actual_purchases,
        ROUND(AVG(sale_price), 2) AS avg_actual_sale_price
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY product_id
),

product_catalog AS (
    -- Step 3: Base Product Catalog aur uski Laagat (Cost)
    SELECT 
        id AS product_id,
        name AS product_name,
        category AS product_category,
        retail_price,
        cost
    FROM {{ ref('stg_products') }} -- 👈 DBT Magic (Ref)
)

SELECT 
    c.product_id,
    c.product_name,
    c.product_category,
    v.primary_traffic_source,
    
    -- 💰 Pricing & Margin Math
    c.retail_price,
    COALESCE(s.avg_actual_sale_price, c.retail_price) AS actual_selling_price,
    c.cost,
    ROUND(COALESCE(s.avg_actual_sale_price, c.retail_price) - c.cost, 2) AS absolute_margin,
    ROUND(SAFE_DIVIDE((COALESCE(s.avg_actual_sale_price, c.retail_price) - c.cost), COALESCE(s.avg_actual_sale_price, c.retail_price)) * 100, 2) AS profit_margin_pct,
    
    -- 📊 View-to-Purchase Funnel Math
    COALESCE(v.total_views, 0) AS total_views,
    COALESCE(s.total_actual_purchases, 0) AS total_purchases,
    
    -- 🧠 The Metric: Drop-off Rate (Dekha par liya nahi)
    ROUND(SAFE_DIVIDE((COALESCE(v.total_views, 0) - COALESCE(s.total_actual_purchases, 0)), NULLIF(v.total_views, 0)) * 100, 2) AS view_to_purchase_drop_rate,
    
    -- 🚀 THE PRICE RESISTANCE ENGINE (Segmentation)
    CASE 
        WHEN v.total_views >= 5 AND s.total_actual_purchases IS NULL 
             THEN '🧱 BRICK WALL: High Views, Zero Buys (Overpriced)'
        WHEN v.total_views >= 10 AND SAFE_DIVIDE(s.total_actual_purchases, v.total_views) <= 0.10 
             THEN '⚠️ HIGH FRICTION: Lots of views, few buys'
        WHEN s.total_actual_purchases > 0 AND SAFE_DIVIDE(s.total_actual_purchases, v.total_views) >= 0.30 
             THEN '🔥 SMOOTH CONVERSION: Perfect Pricing'
        ELSE 'Insufficient Traffic'
    END AS price_resistance_segment,
    
    -- 💸 MARGIN-AWARE MERCHANDISING ACTION PLAN
    CASE 
        -- Rule 1: High Margin Item (Safe to discount)
        WHEN v.total_views >= 5 AND s.total_actual_purchases IS NULL AND ROUND(SAFE_DIVIDE((c.retail_price - c.cost), c.retail_price) * 100, 2) >= 40.0
             THEN CONCAT('ACTION: High Margin (', ROUND(SAFE_DIVIDE((c.retail_price - c.cost), c.retail_price) * 100, 0), '%). Drop price by 10% for ', v.primary_traffic_source, ' traffic.')
             
        -- Rule 2: Low Margin Item (Never discount!)
        WHEN v.total_views >= 5 AND s.total_actual_purchases IS NULL AND ROUND(SAFE_DIVIDE((c.retail_price - c.cost), c.retail_price) * 100, 2) < 20.0
             THEN 'ACTION: Low Margin Product. DO NOT DROP PRICE. Offer EMI or free shipping.'
             
        -- Rule 3: Mid Margin with Friction
        WHEN v.total_views >= 10 AND SAFE_DIVIDE(s.total_actual_purchases, v.total_views) <= 0.10 AND ROUND(SAFE_DIVIDE((c.retail_price - c.cost), c.retail_price) * 100, 2) BETWEEN 20.0 AND 39.9
             THEN 'ACTION: Mid Margin. Run a 24-hour "Flash Sale" (FOMO) to break resistance.'
             
        -- Rule 4: Perfect Conversion
        WHEN s.total_actual_purchases > 0 AND SAFE_DIVIDE(s.total_actual_purchases, v.total_views) >= 0.30 
             THEN 'ACTION: Do not touch the price! Conversion is solid.'
             
        ELSE 'No Action Needed'
    END AS pricing_action_plan

FROM product_catalog c
LEFT JOIN product_views v ON c.product_id = v.product_id
LEFT JOIN actual_sales s ON c.product_id = s.product_id

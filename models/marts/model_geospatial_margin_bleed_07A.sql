{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🌍 MODEL 7A (ADVANCED SQL): GEOSPATIAL LOGISTICS & SPATIAL MARGIN BLEED
-- =================================================================================

WITH order_locations AS (
    -- Step 1: Customer aur Godown ki exact Location (Lat/Long) nikalna
    SELECT 
        oi.order_item_id,
        oi.product_id,
        oi.sale_price,
        ii.cost,
        u.latitude AS user_lat,
        u.longitude AS user_lon,
        dc.id AS distribution_center_id,
        dc.name AS distribution_center_name,
        dc.latitude AS dc_lat,
        dc.longitude AS dc_lon
    FROM {{ ref('fct_order_items') }} oi -- 👈 DBT Magic (Ref)
    JOIN {{ ref('stg_users') }} u -- 👈 DBT Magic (Ref)
      ON oi.user_id = u.id
    JOIN {{ ref('stg_inventory_items') }} ii -- 👈 DBT Magic (Ref)
      ON oi.inventory_item_id = ii.id
    -- Assuming hum raw dataset se DC table utha rahe hain kyunki ye change nahi hoti
    JOIN `bigquery-public-data.thelook_ecommerce.distribution_centers` dc 
      ON ii.product_distribution_center_id = dc.id
    WHERE oi.order_status NOT IN ('Cancelled', 'Returned')
)

SELECT 
    product_id,
    distribution_center_id,
    distribution_center_name,
    
    -- 📐 GEOSPATIAL MATH (Distance in Kilometers)
    -- ST_DISTANCE meter mein aata hai, isliye 1000 se divide kiya
    ROUND(AVG(ST_DISTANCE(ST_GEOGPOINT(dc_lon, dc_lat), ST_GEOGPOINT(user_lon, user_lat)) / 1000), 2) AS avg_shipping_distance_km,
    
    COUNT(order_item_id) AS total_orders,
    ROUND(SUM(sale_price - cost), 2) AS total_gross_margin_usd,
    
    -- 💸 FREIGHT LOGIC (Let's assume $0.05 per Kilometer shipping cost lagti hai)
    ROUND(SUM((ST_DISTANCE(ST_GEOGPOINT(dc_lon, dc_lat), ST_GEOGPOINT(user_lon, user_lat)) / 1000) * 0.05), 2) AS estimated_freight_cost_usd,
    
    -- 🚨 THE REAL PROFIT (Gross Margin minus Freight Cost)
    ROUND(SUM(sale_price - cost) - SUM((ST_DISTANCE(ST_GEOGPOINT(dc_lon, dc_lat), ST_GEOGPOINT(user_lon, user_lat)) / 1000) * 0.05), 2) AS true_net_profit_usd,

    -- 🚀 GEOSPATIAL BUSINESS ACTION PLAN
    CASE 
        WHEN SUM(sale_price - cost) - SUM((ST_DISTANCE(ST_GEOGPOINT(dc_lon, dc_lat), ST_GEOGPOINT(user_lon, user_lat)) / 1000) * 0.05) < 0 
             THEN '☠️ LETHAL BLEED: Shipping cost is killing margin! Restrict delivery radius or hike product price.'
        WHEN SUM(sale_price - cost) - SUM((ST_DISTANCE(ST_GEOGPOINT(dc_lon, dc_lat), ST_GEOGPOINT(user_lon, user_lat)) / 1000) * 0.05) < (SUM(sale_price - cost) * 0.20)
             THEN '⚠️ DANGER ZONE: Shipping is eating 80%+ of profit. Move stock to a closer Distribution Center.'
        ELSE '✅ HEALTHY LOGISTICS: Profitable distance.'
    END AS geospatial_action_plan

FROM order_locations
GROUP BY 
    product_id,
    distribution_center_id,
    distribution_center_name

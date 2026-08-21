{{
  config(
    materialized='table'
  )
}}

WITH order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

users AS (
    SELECT * FROM {{ ref('stg_users') }}
),

products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

inventory_items AS (
    SELECT * FROM {{ ref('stg_inventory_items') }}
),

distribution_centers AS (
    SELECT * FROM {{ ref('stg_distribution_centers') }}
),

final_fact_table AS (
    SELECT
        -- 1. Order Item & Logistics Details
        oi.id AS order_item_id,
        oi.order_id,
        oi.sale_price,
        oi.shipped_at,
        oi.delivered_at,
        oi.returned_at,
        
        -- 2. Order Details
        o.num_of_item,
        o.status AS order_status,
        o.created_at AS order_created_at,
        
        -- 3. User (Customer) Details
        u.id AS user_id,
        u.first_name,
        u.last_name,
        u.age AS user_age,
        u.gender AS user_gender,
        u.city AS user_city,
        u.state AS user_state,
        u.country AS user_country,
        u.traffic_source,
        
        -- 4. Product Details
        p.id AS product_id,
        p.name AS product_name,
        p.category AS product_category,
        p.department AS product_department,
        p.brand AS product_brand,
        p.cost AS product_cost,
        p.retail_price AS product_retail_price,
        
        -- 5. Inventory & Distribution Details
        i.id AS inventory_item_id,
        dc.id AS distribution_center_id,
        dc.name AS distribution_center_name,
        dc.latitude AS dc_latitude,
        dc.longitude AS dc_longitude

    FROM order_items oi
    
    LEFT JOIN orders o 
        ON oi.order_id = o.order_id
        
    LEFT JOIN users u 
        ON o.user_id = u.id
        
    LEFT JOIN products p 
        ON oi.product_id = p.id
        
    LEFT JOIN inventory_items i 
        ON oi.inventory_item_id = i.id
        
    LEFT JOIN distribution_centers dc 
        ON p.distribution_center_id = dc.id
)

SELECT * FROM final_fact_table
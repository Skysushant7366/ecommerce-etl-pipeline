{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 💰 PILLAR 7: PRICE SENSITIVITY & DISCOUNT HUNTER ENGINE
-- =================================================================================

WITH user_spend_behavior AS (
    SELECT 
        user_id,
        COUNT(order_item_id) AS total_items_bought,
        SUM(sale_price) AS total_spend,
        AVG(sale_price) AS avg_item_price,
        
        -- Check kar rahe hain ki kya customer ne retail price se kam (discount) par saman liya hai?
        SUM(CASE WHEN sale_price < product_retail_price THEN 1 ELSE 0 END) AS discounted_items_bought
        
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
)

SELECT 
    user_id,
    total_items_bought,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(avg_item_price, 2) AS avg_item_price,
    
    -- AI ke liye tag banate hain (Price Persona)
    CASE 
        WHEN avg_item_price >= 100 THEN 'Premium Shopper'
        WHEN avg_item_price BETWEEN 50 AND 99.99 THEN 'Mid-Tier Shopper'
        ELSE 'Budget Shopper'
    END AS price_persona,
    
    -- Discount Hunter Flag
    CASE 
        WHEN discounted_items_bought > 0 THEN 'Yes' 
        ELSE 'No' 
    END AS is_discount_hunter,
    
    discounted_items_bought

FROM user_spend_behavior
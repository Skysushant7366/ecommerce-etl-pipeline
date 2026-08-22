{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🎭 PILLAR 5: TASTE MATCHMAKER MATRIX (User-Brand/Category Affinity)
-- =================================================================================

WITH user_brand_spend AS (
    SELECT 
        user_id,
        product_category,
        product_brand,
        COUNT(order_item_id) AS total_items_bought,
        ROUND(SUM(sale_price), 2) AS total_spend_on_brand
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    -- Kachra orders filter karo
    WHERE order_status NOT IN ('Cancelled', 'Returned')
      AND product_brand IS NOT NULL
    GROUP BY user_id, product_category, product_brand
)

SELECT 
    user_id,
    product_category,
    product_brand,
    total_items_bought,
    total_spend_on_brand,
    -- Har user ka har category mein apna personal Favorite Brand Rank (Rank 1 = Sabse pasandida)
    DENSE_RANK() OVER (PARTITION BY user_id, product_category ORDER BY total_spend_on_brand DESC) AS brand_affinity_rank
FROM user_brand_spend
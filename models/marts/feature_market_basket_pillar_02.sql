{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🛒 PILLAR 2: MARKET BASKET ANALYSIS (The Bread & Butter)
-- =================================================================================

WITH order_items AS (
    SELECT 
        order_id, 
        product_category
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    -- Fraud aur cancelled orders ko pehle hi bahar phek do
    WHERE order_status NOT IN ('Cancelled', 'Returned')
),

-- Ek hi order_id ke andar items ka self-join (A ke sath B)
item_combinations AS (
    SELECT 
        a.product_category AS category_a,
        b.product_category AS category_b,
        COUNT(DISTINCT a.order_id) AS times_bought_together
    FROM order_items a
    JOIN order_items b 
        ON a.order_id = b.order_id 
        AND a.product_category < b.product_category -- Duplicates rokne ke liye
    GROUP BY category_a, category_b
)

SELECT 
    category_a,
    category_b,
    times_bought_together,
    -- Rank kar rahe hain ki Category A ke sath sabse zyada kya bikta hai
    DENSE_RANK() OVER (PARTITION BY category_a ORDER BY times_bought_together DESC) AS affinity_rank
FROM item_combinations
WHERE times_bought_together > 5 -- Kam se kam 5 baar sath bike ho, warna noise hoga
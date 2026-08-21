{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🛍️ PILLAR 15: BRAND LOYALTY, CATEGORY AFFINITY & AESTHETIC ENGINE
-- =================================================================================

WITH user_purchases AS (
    -- Step 1: User ne kaunsa brand aur category kitni baar kharida hai
    SELECT 
        user_id,
        product_brand,
        product_category,
        product_department,
        COUNT(order_item_id) AS items_bought
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
        AND product_brand IS NOT NULL
    GROUP BY user_id, product_brand, product_category, product_department
),

ranked_preferences AS (
    -- Step 2: User ka sabse pasandeeda (Rank 1) Brand aur Category nikalna
    SELECT 
        user_id,
        product_brand,
        product_category,
        product_department,
        items_bought,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY items_bought DESC) AS preference_rank
    FROM user_purchases
),

user_summary AS (
    -- Step 3: User ki shopping aadat ka nichod (Kitne alag brands try karta hai?)
    SELECT 
        user_id,
        COUNT(DISTINCT product_brand) AS distinct_brands_bought,
        COUNT(DISTINCT product_category) AS distinct_categories_bought,
        SUM(items_bought) AS total_items
    FROM user_purchases
    GROUP BY user_id
)

SELECT 
    s.user_id,
    s.distinct_brands_bought,
    s.distinct_categories_bought,
    r.product_brand AS top_favorite_brand,
    r.product_category AS top_favorite_category,
    r.product_department AS primary_department,
    
    -- 🤖 AI Persona 1: The Brand Loyalty Segment
    CASE 
        WHEN s.distinct_brands_bought = 1 AND s.total_items > 1 THEN 'Die-Hard Loyalist (Only buys 1 Brand)'
        WHEN s.distinct_brands_bought <= 3 AND s.total_items > 3 THEN 'Brand Conscious (Sticks to a few Brands)'
        ELSE 'Brand Agnostic (Price/Utility Focused)'
    END AS brand_loyalty_segment,

    -- 🤖 AI Persona 2: The Shopping Style
    CASE 
        WHEN s.distinct_categories_bought = 1 AND s.total_items > 1 THEN 'Niche Buyer (Single Category Focus)'
        ELSE 'Cross-Category Explorer'
    END AS category_shopping_style,
    
    -- 🚀 Real-Time Recommendation / Action Engine
    CASE 
        WHEN s.distinct_brands_bought = 1 AND s.total_items > 1 THEN CONCAT('BRAND LOCK: Show ONLY new arrivals from ', r.product_brand, '. Do not cross-sell cheaper brands.')
        WHEN s.distinct_brands_bought <= 3 AND s.total_items > 3 THEN CONCAT('PREFERENCE MATCH: Highlight ', r.product_brand, ' and similar premium brands.')
        
        -- 🔥 BUG FIXED HERE: Changed r.top_favorite_category to r.product_category
        ELSE CONCAT('UTILITY FOCUS: Recommend highest-rated items in ', r.product_category, ' regardless of brand. Sort by best discount.')
    END AS affinity_marketing_action

FROM user_summary s
JOIN ranked_preferences r 
    ON s.user_id = r.user_id 
    AND r.preference_rank = 1
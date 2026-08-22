{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🛒 MODEL 8A (BOSS #1): THE APRIORI ENGINE (SAME-CART MARKET BASKET)
-- =================================================================================

WITH cart_items AS (
    -- Step 1: Sirf successful orders ka data uthana
    SELECT 
        order_id, 
        product_category, 
        sale_price
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
),

category_totals AS (
    -- Step 2: Har category total kitni baar biki (Taaki hum Probability / Confidence nikal sakein)
    SELECT 
        product_category, 
        COUNT(DISTINCT order_id) AS total_orders
    FROM cart_items
    GROUP BY product_category
),

basket_pairs AS (
    -- Step 3: 🔥 THE MATCH-MAKER (Self-Join on same order_id)
    SELECT
        a.product_category AS anchor_category,     -- Jo item cart mein pehle daala (e.g., Jeans)
        b.product_category AS cross_sell_category, -- Jo item uske sath daala (e.g., Socks)
        COUNT(DISTINCT a.order_id) AS times_bought_together,
        SUM(a.sale_price + b.sale_price) AS combined_pair_revenue
    FROM cart_items a
    JOIN cart_items b
      ON a.order_id = b.order_id 
      AND a.product_category != b.product_category -- Ek hi category ke do item ko ignore karna
    GROUP BY anchor_category, cross_sell_category
)

-- Step 4: Final Apriori Output with Confidence Percentage
SELECT 
    p.anchor_category,
    p.cross_sell_category,
    p.times_bought_together,
    t.total_orders AS anchor_total_orders,
    
    -- 🧠 THE PROBABILITY ENGINE (Confidence %): Agar Anchor liya, toh Cross-sell lene ka kitna chance hai?
    ROUND((p.times_bought_together / t.total_orders) * 100, 2) AS confidence_pct,
    
    ROUND(p.combined_pair_revenue, 2) AS total_pair_revenue_usd,

    -- 🚀 LONE WOLF BUSINESS ACTION
    CASE 
        WHEN ROUND((p.times_bought_together / t.total_orders) * 100, 2) >= 15.0 
             THEN '🔥 DEADLY COMBO: Force a pop-up recommendation at checkout!'
        WHEN ROUND((p.times_bought_together / t.total_orders) * 100, 2) >= 5.0 
             THEN '📈 GOOD PAIRING: Create a discounted bundle.'
        ELSE '💤 WEAK PAIR: Do not bundle.'
    END AS apriori_action_plan

FROM basket_pairs p
JOIN category_totals t 
  ON p.anchor_category = t.product_category
WHERE p.times_bought_together > 10 -- Faltu random pairs ko hata diya jo galti se ek sath bik gaye

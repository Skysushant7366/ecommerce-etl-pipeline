{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🔄 MODEL 7B (ADVANCED SQL): RECURSIVE CTE - THE CUSTOMER PURCHASE CHAIN
-- =================================================================================

-- Step 1: Har customer ke orders ko line mein lagana (1st, 2nd, 3rd order...)
-- 🔥 THE FIX: Yahan 'WITH RECURSIVE' laga diya hai taaki BigQuery loop ko samajh sake
WITH RECURSIVE ranked_orders AS (
    SELECT 
        user_id,
        order_id,
        DATE(order_created_at) AS order_date,
        -- Har order me sabse mehangi category ko "Primary Category" maan rahe hain
        ARRAY_AGG(product_category ORDER BY sale_price DESC LIMIT 1)[OFFSET(0)] AS primary_category,
        SUM(sale_price) AS order_value,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY order_created_at ASC) AS order_sequence_num
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status = 'Complete'
    GROUP BY user_id, order_id, order_created_at
),

-- Step 2: 🔥 THE RECURSIVE LOOP (Khufiya Inception Engine)
recursive_chain AS (
    -- ⚓ Anchor Member: (Yahan se loop shuru hoga - sirf 1st Orders)
    SELECT 
        user_id,
        order_id,
        order_sequence_num,
        order_value AS lifetime_value_so_far,
        CAST(primary_category AS STRING) AS purchase_path -- Pehla kadam
    FROM ranked_orders
    WHERE order_sequence_num = 1

    UNION ALL

    -- 🔄 Recursive Member: (Yeh loop khud ko tab tak chalayega jab tak customer ke agle orders milte rahenge)
    SELECT 
        r.user_id,
        n.order_id,
        n.order_sequence_num,
        r.lifetime_value_so_far + n.order_value,
        CONCAT(r.purchase_path, ' ➔ ', n.primary_category) AS purchase_path -- Agle order ko chain me jodna
    FROM recursive_chain r
    JOIN ranked_orders n 
      ON r.user_id = n.user_id 
      AND n.order_sequence_num = r.order_sequence_num + 1 -- "Next Order" pakadna
)

-- Step 3: Aakhiri Result (Sirf wo customers jinhone kam se kam 3 baar shopping ki ho)
SELECT 
    user_id,
    MAX(order_sequence_num) AS total_orders_in_chain,
    MAX(lifetime_value_so_far) AS total_lifetime_value_usd,
    -- Sabse lamba path uthana
    ARRAY_AGG(purchase_path ORDER BY order_sequence_num DESC LIMIT 1)[OFFSET(0)] AS complete_category_journey,
    
    -- 🚀 RECURSIVE ACTION PLAN
    CASE 
        WHEN ARRAY_AGG(purchase_path ORDER BY order_sequence_num DESC LIMIT 1)[OFFSET(0)] LIKE '%Intimates ➔%Jeans%' 
             THEN '🎯 CROSS-SELL IDENTIFIED: Intimates leads to Jeans. Bundle them!'
        WHEN MAX(order_sequence_num) >= 4 
             THEN '🏆 SUPER LOYAL: Give VIP Early Access to next sale.'
        ELSE '📈 STANDARD JOURNEY: Push personalized Email Campaigns.'
    END AS recursive_action_plan

FROM recursive_chain
GROUP BY user_id
HAVING MAX(order_sequence_num) >= 3 -- Hum sirf unka DNA dekh rahe hain jo waapas aaye

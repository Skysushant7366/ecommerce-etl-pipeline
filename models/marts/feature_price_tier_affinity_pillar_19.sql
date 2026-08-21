{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 💳 PILLAR 19: PRICE TIER, WALLET SIZE & PREMIUM AFFINITY ENGINE
-- =================================================================================

WITH item_pricing AS (
    -- Step 1: Har item ko uske Daam (Price) ke hisaab se Tier mein baantna
    SELECT 
        user_id,
        order_item_id,
        sale_price,
        CASE 
            WHEN sale_price <= 30 THEN 'Budget (<$30)'
            WHEN sale_price > 30 AND sale_price <= 100 THEN 'Mid-Range ($30-$100)'
            WHEN sale_price > 100 THEN 'Premium/Luxury (>$100)'
        END AS price_tier
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status NOT IN ('Cancelled', 'Returned')
),

tier_summary AS (
    -- Step 2: Ginna ki user ne Budget, Mid-Range, aur Luxury mein kitne items liye
    SELECT 
        user_id,
        COUNT(order_item_id) AS total_items,
        SUM(CASE WHEN price_tier = 'Budget (<$30)' THEN 1 ELSE 0 END) AS budget_items_bought,
        SUM(CASE WHEN price_tier = 'Mid-Range ($30-$100)' THEN 1 ELSE 0 END) AS mid_range_items_bought,
        SUM(CASE WHEN price_tier = 'Premium/Luxury (>$100)' THEN 1 ELSE 0 END) AS premium_items_bought,
        MAX(sale_price) AS highest_price_paid
    FROM item_pricing
    GROUP BY user_id
)

SELECT 
    user_id,
    total_items,
    budget_items_bought,
    mid_range_items_bought,
    premium_items_bought,
    highest_price_paid,
    
    -- 🤖 AI Persona: The Wallet Size & Spending Habit
    CASE 
        WHEN premium_items_bought >= (total_items * 0.5) THEN 'High-Roller (Prefers Premium/Luxury)'
        WHEN budget_items_bought >= (total_items * 0.6) THEN 'Budget Shopper (Price Sensitive)'
        WHEN mid_range_items_bought >= (total_items * 0.5) THEN 'Value/Mid-Range Buyer'
        ELSE 'Mixed/Balanced Spender'
    END AS spending_habit_segment,
    
    -- 🚀 Real-Time AI Merchandising Action (UI ko control karna)
    CASE 
        WHEN premium_items_bought >= (total_items * 0.5) THEN 'PREMIUM UX: Hide cheap alternatives. Recommend high-end brands and "Exclusive Collections".'
        WHEN budget_items_bought >= (total_items * 0.6) THEN 'BUDGET UX: Default sorting to "Price: Low to High". Highlight clearance sales heavily.'
        WHEN mid_range_items_bought >= (total_items * 0.5) THEN 'VALUE UX: Emphasize "Best Value" and "Top Rated" tags. Balance price and quality.'
        ELSE 'Apply standard algorithmic sorting.'
    END AS pricing_marketing_action

FROM tier_summary
{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 💰 PILLAR 14: PRICE SENSITIVITY, PROFITABILITY & MARGIN ENGINE
-- =================================================================================

WITH user_financials AS (
    -- Step 1: Har user ka total kharcha aur company ki laagat (cost) nikalna
    SELECT 
        user_id,
        COUNT(order_item_id) AS total_items_bought,
        ROUND(SUM(sale_price), 2) AS total_revenue,
        ROUND(SUM(product_cost), 2) AS total_cost,
        ROUND(AVG(sale_price), 2) AS avg_item_price
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    -- Sirf wo orders lo jo successfully complete hue hain
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
)

SELECT 
    user_id,
    total_items_bought,
    total_revenue,
    total_cost,
    
    -- AI Metrics: Asli Profit aur Profit Margin %
    ROUND((total_revenue - total_cost), 2) AS total_absolute_profit,
    ROUND(SAFE_DIVIDE((total_revenue - total_cost), total_revenue) * 100, 2) AS profit_margin_percent,
    avg_item_price,
    
    -- 🤖 AI Persona: The Margin Segments
    CASE 
        WHEN SAFE_DIVIDE((total_revenue - total_cost), total_revenue) >= 0.50 AND avg_item_price >= 100 THEN 'The Golden Goose (High Ticket & High Margin)'
        WHEN SAFE_DIVIDE((total_revenue - total_cost), total_revenue) >= 0.50 THEN 'High Margin Buyer (Profitable)'
        WHEN SAFE_DIVIDE((total_revenue - total_cost), total_revenue) < 0.20 THEN 'Margin Killer (Low Profit / Budget Hunter)'
        ELSE 'Standard Margin Buyer'
    END AS profitability_segment,
    
    -- 🚀 Real-Time Business Action (Protecting the Company's Money)
    CASE 
        WHEN SAFE_DIVIDE((total_revenue - total_cost), total_revenue) >= 0.50 AND avg_item_price >= 100 THEN 'VIP NO-DISCOUNT ZONE: Offer early access & free fast shipping, but NEVER give price drops.'
        WHEN SAFE_DIVIDE((total_revenue - total_cost), total_revenue) >= 0.50 THEN 'Push higher volume. Offer "Buy 2 Get 1" because our margins can easily absorb the cost.'
        WHEN SAFE_DIVIDE((total_revenue - total_cost), total_revenue) < 0.20 THEN 'STOP DISCOUNTS. Cross-sell high-markup accessories (like socks/phone cases) to recover profit.'
        ELSE 'Apply standard promotional campaigns.'
    END AS financial_marketing_action

FROM user_financials
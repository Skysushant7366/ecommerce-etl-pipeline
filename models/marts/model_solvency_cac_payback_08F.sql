{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 💳 MODEL 8F (THE FINAL BOSS #6): THE SOLVENCY ENGINE (CAC PAYBACK & LTV)
-- =================================================================================

WITH order_margins AS (
    -- Step 1: Har order ka margin aur order sequence nikalna
    SELECT 
        user_id,
        order_id,
        MIN(DATE(order_created_at)) AS order_date,
        ROUND(SUM(sale_price - product_cost), 2) AS order_gross_margin_usd,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY MIN(order_created_at) ASC) AS order_sequence_number
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status = 'Complete'
    GROUP BY user_id, order_id
),

cumulative_financials AS (
    -- Step 2: The Running Total (Cumulative Margin)
    SELECT 
        user_id,
        order_id,
        order_sequence_number,
        order_date,
        order_gross_margin_usd,
        -- Har order ke baad total kamai kitni hui (Running Total)
        SUM(order_gross_margin_usd) OVER(PARTITION BY user_id ORDER BY order_sequence_number ASC) AS cumulative_margin_usd,
        -- Assuming constant CAC of $30 per user
        30.00 AS customer_acquisition_cost
    FROM order_margins
),

payback_flagging AS (
    -- Step 3: Identify the exact order where CAC was recovered
    SELECT 
        user_id,
        MAX(order_sequence_number) AS total_lifetime_orders,
        MAX(cumulative_margin_usd) AS lifetime_gross_margin_usd,
        
        -- Dhoondho pehla order kahan tha jisme cumulative margin >= 30 hua
        MIN(CASE WHEN cumulative_margin_usd >= customer_acquisition_cost THEN order_sequence_number END) AS payback_order_number,
        MIN(CASE WHEN cumulative_margin_usd >= customer_acquisition_cost THEN order_date END) AS payback_date,
        MIN(order_date) AS acquisition_date
    FROM cumulative_financials
    GROUP BY user_id
)

-- Step 4: THE CFO ACTION PLAN
SELECT 
    user_id,
    total_lifetime_orders,
    lifetime_gross_margin_usd,
    payback_order_number,
    DATE_DIFF(payback_date, acquisition_date, DAY) AS days_to_payback,
    
    -- 🚀 LONE WOLF SOLVENCY ACTION
    CASE 
        WHEN payback_order_number = 1 
             THEN '🔥 DAY 1 PROFITABLE: High quality user. We recovered CAC instantly!'
        WHEN payback_order_number IN (2, 3) 
             THEN '⏳ SUSTAINABLE GROWTH: Recovered CAC within 2-3 orders. Good retention.'
        WHEN payback_order_number > 3 
             THEN '⚠️ SLOW PAYBACK: Took too long to recover marketing cost. Need faster cross-sells.'
        WHEN payback_order_number IS NULL 
             THEN '☠️ CAC BLEEDER: Never recovered the $30 acquisition cost. Total Loss!'
    END AS solvency_action_plan

FROM payback_flagging

{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 💎 PILLAR 10 (V6 - MASTERMIND EDITION): LTV, DYNAMIC CHURN & MARKETING ACTION PLAN
-- =================================================================================

WITH user_financials AS (
    SELECT 
        user_id,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN order_status NOT IN ('Cancelled', 'Returned') THEN order_id END) AS total_successful_orders,
        COUNT(DISTINCT CASE WHEN order_status = 'Returned' THEN order_id END) AS total_returned_orders,
        COUNT(DISTINCT CASE WHEN order_status = 'Cancelled' THEN order_id END) AS total_cancelled_orders,
        
        COALESCE(ROUND(SUM(CASE WHEN order_status NOT IN ('Cancelled', 'Returned') THEN sale_price ELSE 0 END), 2), 0) AS total_lifetime_revenue,
        
        MIN(DATE(order_created_at)) AS first_purchase_date,
        MAX(DATE(order_created_at)) AS last_purchase_date
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    GROUP BY user_id
),

advanced_metrics AS (
    SELECT
        *,
        COALESCE(SAFE_DIVIDE(total_lifetime_revenue, total_successful_orders), 0) AS average_order_value,
        COALESCE(SAFE_DIVIDE(total_returned_orders, total_orders), 0) AS return_rate,
        
        DATE_DIFF(CURRENT_DATE(), last_purchase_date, DAY) AS days_since_last_order,
        COALESCE(DATE_DIFF(last_purchase_date, first_purchase_date, DAY), 0) AS customer_tenure_days,
        COALESCE(SAFE_DIVIDE(DATE_DIFF(last_purchase_date, first_purchase_date, DAY), (total_successful_orders - 1)), 0) AS avg_days_between_orders
        
    FROM user_financials
),

segmentation AS (
    SELECT 
        user_id,
        total_orders,
        total_successful_orders,
        total_returned_orders,
        total_cancelled_orders,
        total_lifetime_revenue,
        ROUND(average_order_value, 2) AS average_order_value,
        ROUND(return_rate * 100, 2) AS return_rate_percent,
        days_since_last_order,
        ROUND(avg_days_between_orders, 0) AS personal_purchase_cycle_days,
        
        -- 🤖 AI Persona Segments
        CASE 
            WHEN total_successful_orders = 0 AND total_returned_orders >= 3 THEN 'Toxic Returner'
            WHEN total_successful_orders = 0 AND total_returned_orders IN (1, 2) THEN 'Unlucky / Fit Issue'
            WHEN total_successful_orders = 0 AND total_cancelled_orders > 0 THEN 'Hesitant / Cancelled'
            WHEN total_successful_orders = 0 THEN 'Pure Window Shopper'
            
            WHEN total_lifetime_revenue >= 500 AND total_successful_orders >= 3 AND return_rate <= 0.2 THEN 'Whale (Super VIP)'
            WHEN total_lifetime_revenue >= 500 AND return_rate >= 0.4 THEN 'High Spender but Serial Returner'
            WHEN total_lifetime_revenue BETWEEN 150 AND 499.99 AND total_successful_orders >= 2 THEN 'Loyal Customer'
            
            WHEN total_successful_orders = 1 AND average_order_value >= 400 THEN 'High-Ticket (Durable) Buyer'
            WHEN total_successful_orders = 1 AND average_order_value < 400 AND days_since_last_order > 180 THEN 'Churned Low-Value Shopper'
            WHEN total_successful_orders = 1 THEN 'Recent One-Hit Wonder'
            
            -- 🧠 SUSHANT'S REFINED LOGIC: Soft tag for delayed buyers
            WHEN total_successful_orders > 1 AND avg_days_between_orders > 0 AND days_since_last_order > (avg_days_between_orders * 2) THEN 'Delayed Cycle (Cooling Down)'
            ELSE 'Active / Casual Shopper'
        END AS ltv_segment
    FROM advanced_metrics
)

-- 🎯 THE MASTERMIND OUTPUT: Adding the Strategy Column
SELECT 
    *,
    
    -- 🚀 NAYA COLUMN: Teri Marketing / Action Strategy
    CASE 
        WHEN ltv_segment = 'Toxic Returner' THEN 'BAN COD: Disable Cash on Delivery & apply strict return policies.'
        WHEN ltv_segment = 'Unlucky / Fit Issue' THEN 'Send sizing guide emails or offer chat support from styling experts.'
        WHEN ltv_segment = 'Hesitant / Cancelled' THEN 'Send "Price Drop" or "Low Stock" FOMO alerts to convert next time.'
        WHEN ltv_segment = 'Pure Window Shopper' THEN 'Send general retargeting ads; do not waste high discount budget.'
        
        WHEN ltv_segment = 'Whale (Super VIP)' THEN 'VIP TREATMENT: Assign dedicated support, send early access to sales.'
        WHEN ltv_segment = 'High Spender but Serial Returner' THEN 'Monitor closely. Exclude from "Free Return" promotions.'
        WHEN ltv_segment = 'Loyal Customer' THEN 'Enroll in Loyalty Points Program to push them towards Whale status.'
        
        WHEN ltv_segment = 'High-Ticket (Durable) Buyer' THEN 'DO NOT SPAM. Send cross-sell accessory emails (e.g., TV mount for TV) after 30 days.'
        WHEN ltv_segment = 'Churned Low-Value Shopper' THEN 'Send heavy "We Miss You" discount coupon (Win-back campaign).'
        WHEN ltv_segment = 'Recent One-Hit Wonder' THEN 'Send onboarding emails & product reviews to build trust.'
        
        -- 🧠 TERI TACTIC: Handling the "Delayed" guy properly
        WHEN ltv_segment = 'Delayed Cycle (Cooling Down)' THEN 'Send gentle reminder/discovery Ads. If no click in 7 days, trigger a personalized discount.'
        
        ELSE 'Maintain regular weekly newsletters and standard campaign flow.'
    END AS marketing_action_plan

FROM segmentation
{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- ⏳ PILLAR 20 (PRO-VERSION): DYNAMIC LIFECYCLE & TIERED CHURN ENGINE
-- =================================================================================

WITH user_order_dates AS (
    SELECT 
        user_id,
        MIN(DATE(order_created_at)) AS first_order_date,
        MAX(DATE(order_created_at)) AS last_order_date,
        COUNT(DISTINCT order_id) AS total_orders,
        -- 🔥 NAYA COLUMN: Average Order Value (AOV) nikal rahe hain aukaat/category ka andaza lagane ke liye
        ROUND(SUM(sale_price) / COUNT(DISTINCT order_id), 2) AS avg_order_value 
    FROM {{ ref('fct_order_items') }}
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
),

thresholds AS (
    -- 🛠️ ARCHITECTURAL REFINEMENT: Centralized Threshold & Category Price Config
    SELECT 
        60 AS onboarding_days_max,
        90 AS active_days_max,
        180 AS slipping_days_max,
        20 AS win_back_discount_pct, 
        10 AS urgency_discount_pct,
        150 AS high_ticket_aov_threshold -- 🔥 Naya Config: $150 se upar ki shopping (like Electronics/Jackets)
),

dataset_today AS (
    SELECT MAX(last_order_date) AS global_max_date FROM user_order_dates
)

SELECT 
    u.user_id,
    u.first_order_date,
    u.last_order_date,
    u.total_orders,
    u.avg_order_value,
    
    DATE_DIFF(d.global_max_date, u.last_order_date, DAY) AS days_since_last_order,
    DATE_DIFF(d.global_max_date, u.first_order_date, DAY) AS customer_tenure_days,
    
    -- 🤖 AI Persona: The Lifecycle Segment
    CASE 
        WHEN u.total_orders = 1 AND DATE_DIFF(d.global_max_date, u.first_order_date, DAY) <= t.onboarding_days_max THEN 'New User (Onboarding Phase)'
        WHEN u.total_orders = 1 AND DATE_DIFF(d.global_max_date, u.first_order_date, DAY) > t.onboarding_days_max THEN 'One-and-Done (Needs 2nd Purchase)'
        WHEN u.total_orders > 1 AND DATE_DIFF(d.global_max_date, u.last_order_date, DAY) <= t.active_days_max THEN 'Active Loyalist'
        WHEN u.total_orders > 1 AND DATE_DIFF(d.global_max_date, u.last_order_date, DAY) BETWEEN (t.active_days_max + 1) AND t.slipping_days_max THEN 'Slipping Away (At Churn Risk)'
        WHEN u.total_orders > 1 AND DATE_DIFF(d.global_max_date, u.last_order_date, DAY) > t.slipping_days_max THEN 'Dormant/Lost Customer'
        ELSE 'Unknown Cohort'
    END AS lifecycle_segment,
    
    -- 🚀 AUKAAT-AWARE MARKETING ACTION (No more blind 20%!)
    CASE 
        -- Rule 1: New Users
        WHEN u.total_orders = 1 AND DATE_DIFF(d.global_max_date, u.first_order_date, DAY) <= t.onboarding_days_max THEN 'NURTURE: Send "Welcome" series. Focus on brand trust.'
        
        -- Rule 2: One-and-Done
        WHEN u.total_orders = 1 AND DATE_DIFF(d.global_max_date, u.first_order_date, DAY) > t.onboarding_days_max THEN 
            CASE 
                WHEN u.avg_order_value >= t.high_ticket_aov_threshold THEN 'WIN-BACK (HIGH TICKET): Do NOT give % discount. Offer Flat $50 Cashback or Free Premium Warranty to protect margins.'
                ELSE CONCAT('WIN-BACK (STANDARD): Trigger Category-Adjusted ', t.win_back_discount_pct, '% discount on Apparel/Utility.')
            END
            
        -- Rule 3: Active Loyalists
        WHEN u.total_orders > 1 AND DATE_DIFF(d.global_max_date, u.last_order_date, DAY) <= t.active_days_max THEN 'VIP ENGAGEMENT: Zero Discounts. Offer Early Access & Priority Support.'
        
        -- Rule 4: Slipping Away
        WHEN u.total_orders > 1 AND DATE_DIFF(d.global_max_date, u.last_order_date, DAY) BETWEEN (t.active_days_max + 1) AND t.slipping_days_max THEN 
            CASE 
                WHEN u.avg_order_value >= t.high_ticket_aov_threshold THEN 'URGENCY (HIGH TICKET): Send "Free Accessories Set" on next premium order.'
                ELSE CONCAT('URGENCY (STANDARD): Send "We miss you! ', t.urgency_discount_pct, '% off apparel/footwear."')
            END
            
        -- Rule 5: Dormant
        WHEN u.total_orders > 1 AND DATE_DIFF(d.global_max_date, u.last_order_date, DAY) > t.slipping_days_max THEN 'REACTIVATION: Hail Mary campaign. Massive BOGO / Inventory clearance offers.'
        
        ELSE 'Apply standard lifecycle campaign.'
    END AS lifecycle_marketing_action

FROM user_order_dates u
CROSS JOIN dataset_today d
CROSS JOIN thresholds t
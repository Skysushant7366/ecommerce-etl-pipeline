{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 📐 MODEL 7C (MULTIVARIATE GOD-MODE): N-MONTH COHORT & REVENUE RETENTION MATRIX
-- =================================================================================

WITH user_first_touch AS (
    -- Step 1: Customer ka Janam (Acquisition Month) aur Unka Source nikalna
    SELECT 
        o.user_id,
        u.traffic_source,
        DATE_TRUNC(DATE(MIN(o.order_created_at)), MONTH) AS cohort_month
    FROM {{ ref('fct_order_items') }} o -- 👈 DBT Magic (Ref)
    JOIN {{ ref('stg_users') }} u ON o.user_id = u.id -- 👈 DBT Magic (Ref)
    WHERE o.order_status = 'Complete'
    GROUP BY o.user_id, u.traffic_source
),

user_activity AS (
    -- Step 2: Customer ka aage ka safar (Har mahine kitna kharida)
    SELECT 
        user_id,
        DATE_TRUNC(DATE(order_created_at), MONTH) AS activity_month,
        SUM(sale_price) AS monthly_revenue
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status = 'Complete'
    GROUP BY user_id, activity_month
),

cohort_size AS (
    -- Step 3: Base Matrix (Cohort mein total kitne log the aur kitna paisa laya Month 0 me)
    SELECT 
        f.cohort_month,
        f.traffic_source,
        COUNT(DISTINCT f.user_id) AS total_users_in_cohort,
        SUM(a.monthly_revenue) AS month_0_revenue
    FROM user_first_touch f
    JOIN user_activity a ON f.user_id = a.user_id AND f.cohort_month = a.activity_month
    GROUP BY f.cohort_month, f.traffic_source
),

cohort_retention AS (
    -- Step 4: The N-Month Logic (Date Math to find Month 1, Month 2, etc.)
    SELECT 
        f.cohort_month,
        f.traffic_source,
        DATE_DIFF(a.activity_month, f.cohort_month, MONTH) AS month_index,
        COUNT(DISTINCT a.user_id) AS retained_users,
        SUM(a.monthly_revenue) AS retained_revenue
    FROM user_first_touch f
    JOIN user_activity a ON f.user_id = a.user_id
    GROUP BY f.cohort_month, f.traffic_source, month_index
)

-- Step 5: THE MULTIVARIATE PIVOT (Staircase Triangle)
SELECT 
    s.cohort_month,
    s.traffic_source,
    s.total_users_in_cohort AS m0_original_users,
    ROUND(s.month_0_revenue, 2) AS m0_original_revenue_usd,
    
    -- 🧠 LAYER 1: USER RETENTION % (Kitne % log wapas aaye)
    ROUND(MAX(CASE WHEN r.month_index = 1 THEN r.retained_users ELSE 0 END) / s.total_users_in_cohort * 100, 2) AS m1_user_retention_pct,
    ROUND(MAX(CASE WHEN r.month_index = 2 THEN r.retained_users ELSE 0 END) / s.total_users_in_cohort * 100, 2) AS m2_user_retention_pct,
    ROUND(MAX(CASE WHEN r.month_index = 3 THEN r.retained_users ELSE 0 END) / s.total_users_in_cohort * 100, 2) AS m3_user_retention_pct,
    
    -- 💸 LAYER 2: NET REVENUE RETENTION (NRR) - CFO's Favorite Metric
    ROUND(MAX(CASE WHEN r.month_index = 1 THEN r.retained_revenue ELSE 0 END) / NULLIF(s.month_0_revenue, 0) * 100, 2) AS m1_revenue_retention_pct,
    ROUND(MAX(CASE WHEN r.month_index = 2 THEN r.retained_revenue ELSE 0 END) / NULLIF(s.month_0_revenue, 0) * 100, 2) AS m2_revenue_retention_pct,
    
    -- 🚀 LAYER 3: BUSINESS ACTION PLAN (Marketing Budget Allocation)
    CASE 
        WHEN ROUND(MAX(CASE WHEN r.month_index = 1 THEN r.retained_revenue ELSE 0 END) / NULLIF(s.month_0_revenue, 0) * 100, 2) > 10.0 
             THEN '🔥 HIGH LTV SOURCE: Users are spending heavy. Double the Ad spend here!'
        WHEN ROUND(MAX(CASE WHEN r.month_index = 1 THEN r.retained_users ELSE 0 END) / s.total_users_in_cohort * 100, 2) < 2.0 
             THEN '☠️ TOXIC TRAFFIC: Users bought once and bounced. Cut acquisition budget.'
        ELSE '⚠️ AVERAGE CHURN: Needs Retargeting Campaigns.'
    END AS cohort_action_plan

FROM cohort_size s
LEFT JOIN cohort_retention r 
  ON s.cohort_month = r.cohort_month 
  AND s.traffic_source = r.traffic_source
GROUP BY 
    s.cohort_month,
    s.traffic_source,
    s.total_users_in_cohort,
    s.month_0_revenue

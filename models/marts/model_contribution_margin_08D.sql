{{
    config(
        materialized='table'
    )
}}

-- =================================================================================
-- 🛡️ MODEL 8D (BOSS #4): THE MARGIN ENGINE (TRUE CONTRIBUTION MARGIN)
-- =================================================================================

WITH unit_economics AS (
    -- Step 1: Base metrics nikalna (Sirf successful sales)
    SELECT 
        product_category,
        COUNT(order_id) AS total_units_sold,
        SUM(sale_price) AS total_gross_revenue,
        -- 🔥 BUG FIXED: Yahan 'cost' ki jagah tera asil column 'product_cost' laga diya
        SUM(product_cost) AS total_cogs 
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    WHERE order_status = 'Complete'
    GROUP BY product_category
),

hidden_costs_applied AS (
    -- Step 2: The Architect's Real-World Deductions
    SELECT 
        product_category,
        total_units_sold,
        total_gross_revenue,
        total_cogs,
        
        -- Payment Gateway: 2.9% of sale + $0.30 per transaction
        (total_gross_revenue * 0.029) + (total_units_sold * 0.30) AS gateway_fees,
        
        -- Packaging & Handling: $1.50 per unit
        (total_units_sold * 1.50) AS packaging_costs
    FROM unit_economics
)

-- Step 3: THE TRUE MARGIN CALCULATOR & ACTION PLAN
SELECT 
    product_category,
    total_units_sold,
    ROUND(total_gross_revenue, 2) AS gross_revenue_usd,
    ROUND(total_cogs, 2) AS total_cogs_usd,
    ROUND(gateway_fees, 2) AS hidden_gateway_fees_usd,
    ROUND(packaging_costs, 2) AS hidden_packaging_usd,
    
    -- 🧠 THE ACCOUNTANCY MATH: True Contribution Margin
    ROUND(total_gross_revenue - total_cogs - gateway_fees - packaging_costs, 2) AS true_margin_usd,
    
    -- Margin Percentage
    ROUND(((total_gross_revenue - total_cogs - gateway_fees - packaging_costs) / total_gross_revenue) * 100, 2) AS true_margin_pct,

    -- 🚀 LONE WOLF BUSINESS ACTION
    CASE 
        WHEN ROUND(((total_gross_revenue - total_cogs - gateway_fees - packaging_costs) / total_gross_revenue) * 100, 2) < 0 
             THEN '☠️ BLEEDING CASH: Negative Margin! We are paying customers to take this. STOP selling immediately!'
             
        WHEN ROUND(((total_gross_revenue - total_cogs - gateway_fees - packaging_costs) / total_gross_revenue) * 100, 2) BETWEEN 0 AND 15 
             THEN '⚠️ DANGER ZONE (LOW MARGIN): Barely surviving. Increase price or reduce packaging cost.'
             
        WHEN ROUND(((total_gross_revenue - total_cogs - gateway_fees - packaging_costs) / total_gross_revenue) * 100, 2) >= 40 
             THEN '💰 CASH COW: Insane margins! Double the marketing budget here.'
             
        ELSE '✅ HEALTHY MARGIN: Standard retail profitability.'
    END AS margin_action_plan

FROM hidden_costs_applied

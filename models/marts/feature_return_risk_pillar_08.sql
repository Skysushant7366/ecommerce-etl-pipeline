{{
    config(
        materialized='incremental',
        unique_key='user_id'
    )
}}

-- =================================================================================
-- 🚫 PILLAR 8: RETURN RISK PREDICTOR (Identifying Serial Returners)
-- =================================================================================

WITH user_return_activity AS (
    SELECT 
        user_id,
        COUNT(order_item_id) AS total_items_ordered,
        
        -- Kitne items sach mein return kiye?
        SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) AS total_items_returned,
        
        -- Business ka kitna paisa wapas (refund) dena pada?
        ROUND(SUM(CASE WHEN order_status = 'Returned' THEN sale_price ELSE 0 END), 2) AS total_refund_amount
        
    FROM {{ ref('fct_order_items') }} -- 👈 DBT Magic (Ref)
    -- Cancelled orders ko count nahi kar rahe kyunki wo ship hone se pehle hi cancel ho jate hain
    WHERE order_status != 'Cancelled' 
    GROUP BY user_id
)

SELECT 
    user_id,
    total_items_ordered,
    total_items_returned,
    total_refund_amount,
    
    -- Return Rate Percentage (%)
    ROUND((total_items_returned / total_items_ordered) * 100, 2) AS return_rate_percentage,
    
    -- 🚩 AI Risk Flag (Persona)
    CASE 
        WHEN (total_items_returned / total_items_ordered) >= 0.50 AND total_items_ordered >= 3 THEN 'High Risk (Serial Returner)'
        WHEN total_items_returned > 0 THEN 'Moderate Risk'
        ELSE 'Low Risk (Safe)'
    END AS return_risk_persona

FROM user_return_activity
WHERE total_items_ordered > 0
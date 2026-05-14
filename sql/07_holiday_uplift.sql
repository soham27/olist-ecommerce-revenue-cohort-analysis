-- 07_holiday_uplift.sql

WITH order_level AS (
    SELECT
        order_id,
        MIN(order_purchase_timestamp) AS order_purchase_timestamp,
        SUM(price) AS order_revenue
    FROM sales_base
    GROUP BY order_id
),
tagged_orders AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        order_revenue,
        CASE
            WHEN EXTRACT(MONTH FROM order_purchase_timestamp) IN (11, 12)
                THEN 'Holiday'
            ELSE 'Non-Holiday'
        END AS period_type
    FROM order_level
)
SELECT
    period_type,
    COUNT(*) AS total_orders,
    ROUND(SUM(order_revenue)::numeric, 2) AS total_revenue,
    ROUND(AVG(order_revenue)::numeric, 2) AS avg_order_value
FROM tagged_orders
GROUP BY period_type;


-- This calculates the uplift percentage:

WITH order_level AS (
    SELECT
        order_id,
        MIN(order_purchase_timestamp) AS order_purchase_timestamp,
        SUM(price) AS order_revenue
    FROM sales_base
    GROUP BY order_id
),
period_summary AS (
    SELECT
        CASE
            WHEN EXTRACT(MONTH FROM order_purchase_timestamp) IN (11, 12)
                THEN 'Holiday'
            ELSE 'Non-Holiday'
        END AS period_type,
        AVG(order_revenue) AS avg_order_value
    FROM order_level
    GROUP BY 1
)
SELECT
    ROUND(
        100.0 * (
            MAX(CASE WHEN period_type = 'Holiday' THEN avg_order_value END) -
            MAX(CASE WHEN period_type = 'Non-Holiday' THEN avg_order_value END)
        ) /
        MAX(CASE WHEN period_type = 'Non-Holiday' THEN avg_order_value END),
        2
    ) AS holiday_uplift_pct
FROM period_summary;
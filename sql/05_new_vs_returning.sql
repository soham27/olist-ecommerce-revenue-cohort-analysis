-- 05_new_vs_returning.sql

WITH first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_ts
    FROM sales_base
    GROUP BY customer_unique_id
),
customer_orders AS (
    SELECT
        sb.order_id,
        sb.customer_unique_id,
        sb.order_purchase_timestamp,
        sb.price,
        CASE
            WHEN sb.order_purchase_timestamp = fp.first_purchase_ts THEN 'New'
            ELSE 'Returning'
        END AS customer_type
    FROM sales_base sb
    JOIN first_purchase fp
        ON sb.customer_unique_id = fp.customer_unique_id
)
SELECT
    customer_type,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS total_customers,
    ROUND(SUM(price)::numeric, 2) AS total_revenue,
    ROUND(AVG(price)::numeric, 2) AS avg_item_revenue
FROM customer_orders
GROUP BY customer_type
ORDER BY customer_type;


# Cleaner lternative approach using CTEs to calculate order-level revenue first (better than item-level for this comparison), which I should use in my final project write-up.
WITH order_revenue AS (
    SELECT
        order_id,
        customer_unique_id,
        MIN(order_purchase_timestamp) AS order_purchase_timestamp,
        SUM(price) AS order_revenue
    FROM sales_base
    GROUP BY order_id, customer_unique_id
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_ts
    FROM order_revenue
    GROUP BY customer_unique_id
)
SELECT
    CASE
        WHEN o.order_purchase_timestamp = f.first_purchase_ts THEN 'New'
        ELSE 'Returning'
    END AS customer_type,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT o.customer_unique_id) AS total_customers,
    ROUND(SUM(o.order_revenue)::numeric, 2) AS total_revenue,
    ROUND(AVG(o.order_revenue)::numeric, 2) AS avg_order_value
FROM order_revenue o
JOIN first_purchase f
    ON o.customer_unique_id = f.customer_unique_id
GROUP BY 1
ORDER BY 1;
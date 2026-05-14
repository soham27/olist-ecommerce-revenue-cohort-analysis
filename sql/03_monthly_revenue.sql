-- 03_monthly_revenue.sql

SELECT
    order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(SUM(price)::numeric, 2) AS product_revenue,
    ROUND(SUM(gross_revenue)::numeric, 2) AS gross_revenue,
    ROUND(AVG(price)::numeric, 2) AS avg_item_price
FROM sales_base
GROUP BY order_month
ORDER BY order_month;
-- 04_category_performance.sql

SELECT
    product_category_english,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(price)::numeric, 2) AS product_revenue,
    ROUND(AVG(price)::numeric, 2) AS avg_item_price
FROM sales_base
GROUP BY product_category_english
ORDER BY product_revenue DESC
LIMIT 15;

SELECT
    order_month,
    product_category_english,
    ROUND(SUM(price)::numeric, 2) AS revenue
FROM sales_base
GROUP BY order_month, product_category_english
ORDER BY order_month, revenue DESC;
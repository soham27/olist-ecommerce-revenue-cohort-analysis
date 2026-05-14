-- 01_sanity_checks.sql

SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation;

SELECT
    order_status,
    COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

SELECT *
FROM orders
LIMIT 10;

SELECT *
FROM order_items
LIMIT 10;

SELECT *
FROM customers
LIMIT 10;

SELECT *
FROM products
LIMIT 10;
-- 06_cohort_retention.sql

WITH order_level AS (
    SELECT DISTINCT
        order_id,
        customer_unique_id,
        DATE_TRUNC('month', order_purchase_timestamp) AS order_month
    FROM sales_base
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM order_level
    GROUP BY customer_unique_id
),
cohort_activity AS (
    SELECT
        o.customer_unique_id,
        f.cohort_month,
        o.order_month,
        (
            EXTRACT(YEAR FROM AGE(o.order_month, f.cohort_month)) * 12
            + EXTRACT(MONTH FROM AGE(o.order_month, f.cohort_month))
        ) AS month_number
    FROM order_level o
    JOIN first_purchase f
        ON o.customer_unique_id = f.customer_unique_id
),
cohort_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id) AS customers_in_period
    FROM cohort_activity
    GROUP BY cohort_month, month_number
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    cc.cohort_month,
    cs.cohort_size,
    cc.month_number,
    cc.customers_in_period,
    ROUND(
        100.0 * cc.customers_in_period / cs.cohort_size,
        2
    ) AS retention_rate
FROM cohort_counts cc
JOIN cohort_size cs
    ON cc.cohort_month = cs.cohort_month
ORDER BY cc.cohort_month, cc.month_number;
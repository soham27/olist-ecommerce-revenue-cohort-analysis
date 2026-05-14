/*
================================================================================
Project: Olist E-Commerce Revenue & Cohort Analysis
File:    08_create_reporting_views.sql
Purpose: Create Power BI-ready reporting views for the final dashboard.

Prerequisite:
    The `sales_base` view must already exist. It should contain delivered-order
    item-level records joined with customer, product, seller, category, and
    revenue fields.

Important metric definitions:
    - product_revenue: Revenue from item price only (`price`).
    - gross_revenue: Product price plus freight value, precomputed in `sales_base`.
    - avg_order_value: Order-level product revenue average, not item-level average.
    - customer_unique_id: Used to identify repeat customers across orders.
    - Holiday period: November and December.
    - Cohort month: First purchase month for each unique customer.
    - Retention rate: Percentage of customers from a cohort who purchased again
      in a later month number.

Power BI dependency:
    These view names are used directly by the Power BI report. Do not rename them
    unless the Power BI model is updated as well.

Views created:
    1. vw_monthly_revenue
    2. vw_category_performance
    3. vw_new_vs_returning
    4. vw_holiday_summary
    5. vw_holiday_uplift
    6. vw_cohort_retention
    7. vw_kpi_summary
================================================================================
*/

/*
================================================================================
1. Monthly Revenue Trend

Grain:
    One row per order month.

Purpose:
    Supports the monthly gross revenue line chart and shows revenue, orders,
    and unique customers over time.

Notes:
    - `product_revenue` is based on item price only.
    - `gross_revenue` includes freight value.
    - Sorting should be handled in Power BI or in the final SELECT query.
================================================================================
*/
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT
    order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(SUM(price)::numeric, 2) AS product_revenue,
    ROUND(SUM(gross_revenue)::numeric, 2) AS gross_revenue,
    ROUND(AVG(price)::numeric, 2) AS avg_item_price
FROM sales_base
GROUP BY order_month;


/*
================================================================================
2. Product Category Performance

Grain:
    One row per translated product category.

Purpose:
    Supports the Top Product Categories by Revenue visual.

Notes:
    - `total_items_sold` counts order-item rows, not distinct products.
    - `total_orders` counts distinct orders containing that category.
    - Category display-name cleanup is handled in Power BI Power Query.
================================================================================
*/
CREATE OR REPLACE VIEW vw_category_performance AS
SELECT
    product_category_english,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(price)::numeric, 2) AS product_revenue,
    ROUND(AVG(price)::numeric, 2) AS avg_item_price
FROM sales_base
GROUP BY product_category_english;


/*
================================================================================
3. New vs Returning Customer Performance

Grain:
    One row per customer type: New or Returning.

Purpose:
    Supports visuals comparing revenue and average order value for new versus
    returning customers.

Method:
    1. Collapse item-level data to order-level revenue.
    2. Identify each customer's first observed purchase timestamp.
    3. Classify an order as:
        - New: order timestamp equals the customer's first purchase timestamp.
        - Returning: any later order from the same customer.

Business interpretation:
    Shows whether revenue is primarily acquisition-driven or repeat-purchase-driven.
================================================================================
*/
CREATE OR REPLACE VIEW vw_new_vs_returning AS
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
GROUP BY 1;


/*
================================================================================
4. Holiday vs Non-Holiday Summary

Grain:
    One row per period type: Holiday or Non-Holiday.

Purpose:
    Provides supporting metrics for holiday-period performance analysis.

Method:
    - Holiday period is defined as November and December.
    - Revenue is calculated at the order level to avoid item-level duplication.

Notes:
    This view is optional for the final dashboard if the dashboard only uses the
    Holiday AOV Change KPI card.
================================================================================
*/
CREATE OR REPLACE VIEW vw_holiday_summary AS
WITH order_level AS (
    SELECT
        order_id,
        MIN(order_purchase_timestamp) AS order_purchase_timestamp,
        SUM(price) AS order_revenue
    FROM sales_base
    GROUP BY order_id
)
SELECT
    CASE
        WHEN EXTRACT(MONTH FROM order_purchase_timestamp) IN (11, 12)
            THEN 'Holiday'
        ELSE 'Non-Holiday'
    END AS period_type,
    COUNT(*) AS total_orders,
    ROUND(SUM(order_revenue)::numeric, 2) AS total_revenue,
    ROUND(AVG(order_revenue)::numeric, 2) AS avg_order_value
FROM order_level
GROUP BY 1;


/*
================================================================================
5. Holiday AOV Change

Grain:
    One row containing the holiday AOV percentage change.

Purpose:
    Supports the Holiday AOV Change KPI card.

Formula:
    Holiday AOV Change % =
        (Holiday Average Order Value - Non-Holiday Average Order Value)
        / Non-Holiday Average Order Value * 100

Interpretation:
    - Positive value: holiday-period orders had higher AOV.
    - Negative value: holiday-period orders had lower AOV.

Current dashboard result:
    The project dashboard shows a negative value, meaning holiday-period AOV was
    slightly lower than non-holiday AOV.
================================================================================
*/
CREATE OR REPLACE VIEW vw_holiday_uplift AS
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


/*
================================================================================
6. Customer Cohort Retention

Grain:
    One row per cohort month and month number.

Purpose:
    Supports the Customer Cohort Retention matrix/heatmap in Power BI.

Method:
    1. Create an order-level customer activity table.
    2. Identify each customer's first purchase month.
    3. Assign every later order to the customer's cohort month.
    4. Calculate the number of months between cohort month and order month.
    5. Count active customers for each cohort/month_number combination.
    6. Divide by original cohort size to calculate retention rate.

Important notes:
    - `month_number = 0` is the first-purchase month and will be 100%.
    - The final Power BI matrix filters out month 0 to focus on repeat purchases.
    - Retention values are already percentage-style numbers, e.g. 0.62 means 0.62%.
    - Recent cohorts have fewer later months available because the dataset ends.
================================================================================
*/
CREATE OR REPLACE VIEW vw_cohort_retention AS
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
    ROUND(100.0 * cc.customers_in_period / cs.cohort_size, 2) AS retention_rate
FROM cohort_counts cc
JOIN cohort_size cs
    ON cc.cohort_month = cs.cohort_month;


/*
================================================================================
7. Dashboard KPI Summary

Grain:
    One row containing top-level dashboard KPIs.

Purpose:
    Supports KPI cards for total gross revenue, total orders, product revenue,
    and average order value.

Method:
    - First collapse item-level data to one row per order.
    - Then calculate total and average order-level metrics.

Notes:
    - `total_gross_revenue` includes freight value.
    - `total_product_revenue` excludes freight value.
    - `avg_order_value` is based on product revenue per order.
================================================================================
*/
CREATE OR REPLACE VIEW vw_kpi_summary AS
WITH order_level AS (
    SELECT
        order_id,
        SUM(gross_revenue) AS gross_revenue,
        SUM(price) AS product_revenue
    FROM sales_base
    GROUP BY order_id
)
SELECT
    COUNT(order_id) AS total_orders,
    ROUND(SUM(gross_revenue)::numeric, 2) AS total_gross_revenue,
    ROUND(SUM(product_revenue)::numeric, 2) AS total_product_revenue,
    ROUND(AVG(product_revenue)::numeric, 2) AS avg_order_value
FROM order_level;


/*
================================================================================
Optional QA Checks

Run these manually after creating the views. They are intentionally commented out
so that this script can be executed cleanly as a production view-creation script.
================================================================================

-- Confirm reporting views exist.
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
      'vw_monthly_revenue',
      'vw_category_performance',
      'vw_new_vs_returning',
      'vw_holiday_summary',
      'vw_holiday_uplift',
      'vw_cohort_retention',
      'vw_kpi_summary'
  )
ORDER BY table_name;

-- Preview monthly revenue trend.
SELECT *
FROM vw_monthly_revenue
ORDER BY order_month
LIMIT 10;

-- Preview top product categories.
SELECT *
FROM vw_category_performance
ORDER BY product_revenue DESC
LIMIT 10;

-- Preview new vs returning customer summary.
SELECT *
FROM vw_new_vs_returning
ORDER BY customer_type;

-- Preview holiday AOV change.
SELECT *
FROM vw_holiday_uplift;

-- Preview cohort retention output.
SELECT *
FROM vw_cohort_retention
ORDER BY cohort_month, month_number
LIMIT 20;

-- Preview dashboard KPIs.
SELECT *
FROM vw_kpi_summary;

================================================================================
*/

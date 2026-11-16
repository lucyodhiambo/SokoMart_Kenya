--Q6 Compute every customer's lifetime revenue (completed orders), rank customers within their county

WITH customer_revenue AS (
   	SELECT c.county,c.customer_id,c.first_name || ' ' || c.last_name AS full_name,SUM(oi.line_total) AS total_spent
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.order_status = 'completed'
    GROUP BY c.county, c.customer_id, c.first_name, c.last_name
),
ranked AS (
    SELECT county,customer_id, full_name, total_spent,
        DENSE_RANK() OVER (PARTITION BY county
            ORDER BY total_spent DESC ) AS county_rank
    FROM customer_revenue
)
SELECT county, county_rank, customer_id, full_name, total_spent
FROM ranked
WHERE county_rank <= 3
ORDER BY county, county_rank, customer_id;

--Q7  2025 revenue and units sold per product (completed orders in 2025), numbered within category by revenue with ROW_NUMBER() (tie-break on product_id). Keep 1–3.

WITH product_sales AS (
    SELECT p.category,p.product_id,p.product_name, SUM(oi.line_total) AS revenue,SUM(oi.quantity)   AS units_sold
    FROM order_items oi
    JOIN orders o   ON o.order_id   = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01'
      AND o.order_date <  '2026-01-01'
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    select category, product_id, product_name, revenue, units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY revenue DESC, product_id ) AS rank_in_category
    FROM product_sales
)
SELECT category, rank_in_category, product_id, product_name, revenue, units_sold
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

--Q8 Monthly revenue for every month in the data (January 2025 – October 2026), the previous month's revenue with LAG(), and growth %. The first month has no previous month (NULL).

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date) AS month_start,
        SUM(oi.line_total)                AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
    GROUP BY DATE_TRUNC('month', o.order_date)
),
with_prev AS (
    SELECT month_start, revenue,
        LAG(revenue) OVER (ORDER BY month_start) AS prev_month_revenue
    FROM monthly
)
SELECT
    TO_CHAR(month_start, 'YYYY-MM') AS month,revenue,prev_month_revenue,
    ROUND(
        (revenue - prev_month_revenue) * 100.0 / NULLIF(prev_month_revenue, 0),
        2
    ) AS growth_pct
FROM with_prev
ORDER BY month_start;
/*Q9 For customers living in Nyeri, list every completed order placed in 2026, with
the customer's previous 2026 completed order amount (total_amount), the change, and a
direction label first order / up / down / same. Order by customer, then order date. Then a
summary query: total rows, distinct customers, first orders, orders bigger than the previous,
orders smaller than the previous.*/

WITH nyeri_orders AS (
    select o.customer_id,o.order_id,o.order_date,o.total_amount,
        LAG(o.total_amount) OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date, o.order_id
        ) AS previous_order_amount
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE c.county = 'Nyeri'
      AND o.order_status = 'completed'
      AND o.order_date >= '2026-01-01'
      AND o.order_date <  '2027-01-01'
)
select customer_id,order_id,order_date,total_amount,previous_order_amount,total_amount - previous_order_amount AS change_amount,
    CASE
        WHEN previous_order_amount IS NULL  THEN 'first order'
        WHEN total_amount > previous_order_amount   THEN 'up'
        WHEN total_amount < previous_order_amount   THEN 'down'
        ELSE 'same'
    END AS direction
FROM nyeri_orders
ORDER BY customer_id, order_date, order_id;

-- Part 2: summary of the same result
WITH nyeri_orders AS (
    SELECT o.customer_id,o.order_id,o.order_date,o.total_amount,
        LAG(o.total_amount) OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date, o.order_id
        ) AS previous_order_amount
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE c.county = 'Nyeri'
      AND o.order_status = 'completed'
      AND o.order_date >= '2026-01-01'
      AND o.order_date <  '2027-01-01'
)
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT(*) FILTER (WHERE previous_order_amount IS NULL)  AS first_orders,
    COUNT(*) FILTER (WHERE total_amount > previous_order_amount) AS bigger_than_previous,
    COUNT(*) FILTER (WHERE total_amount < previous_order_amount)AS smaller_than_previous
FROM nyeri_orders;

/*Q10  Monthly revenue with a running total that resets each calendar year, and a second running
total that never resets. Use an explicit frame (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW).*/
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date) AS month_start,SUM(oi.line_total)  AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT
    EXTRACT(YEAR FROM month_start)::INTEGER AS year, TO_CHAR(month_start, 'YYYY-MM') AS month,monthly_revenue,
    SUM(monthly_revenue) OVER (PARTITION BY EXTRACT(YEAR FROM month_start)
        ORDER BY month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS running_revenue_ytd,
    SUM(monthly_revenue) OVER (ORDER BY month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue_all_time
FROM monthly
ORDER BY month_start;

--
select * from orders limit 3;

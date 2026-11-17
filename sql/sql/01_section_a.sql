SET search_path TO sokomart, public;

select * from customers
limit 3;

select * from order_items
limit 3;

select * from orders
limit 3;

select * from payments
limit 3;

select * from payment_staging
limit 3;

select * from products
limit 3;

--PRACTICE DRILLS
--D1 List the products whose unit_price is above the average unit_price of all products. Show the 10 most expensive, then on a second query the count.
SELECT product_id,product_name,category,unit_price,
round((select avg(unit_price) from products),2) as overal_avgprice
FROM sokomart.products
WHERE unit_price > (
                    SELECT AVG(unit_price)
                    FROM sokomart.products
					)
ORDER BY unit_price DESC
LIMIT 10;

SELECT 	
	COUNT(product_id)
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products);


--D2List customers living in Mombasa who placed at least one order (any status) in December 2025

SELECT 
	customer_id, first_name, last_name, email
FROM customers
WHERE county = 'Mombasa'
	AND customer_id IN (SELECT customer_id FROM orders WHERE order_date BETWEEN '2025-12-01' AND '2025-12-31');

--D3Kisumu customers with failed payments

SELECT 
	COUNT(DISTINCT o.customer_id)
FROM orders o
JOIN customers c USING(customer_id)
WHERE c.county = 'Kisumu'
	AND order_id IN (SELECT order_id FROM payments WHERE payment_status = 'failed');

--D4 For each order_status, show the number of orders, the average number of lines per order and the average number of units per order. Compute the per-order figures in a subquery in FROM.


SELECT 
	order_status, orders, avg_lines_per_order, avg_units_per_order
	FROM (
		SELECT 
			o.order_status,
			COUNT(oi.order_id) AS orders,
			ROUND(AVG(oi.line_total), 2)  AS avg_lines_per_order,
			ROUND(AVG(oi.quantity),2) AS avg_units_per_order
		FROM order_items oi
		JOIN orders o USING(order_id)
		GROUP BY o.order_status
	);

--D5 Top 5 shipping counties by number of completed orders in 2026. Put the filtered orders in a CTE.

WITH shipping_counties AS(
	SELECT
		o.shipping_county, COUNT(*) AS completed_orders
	FROM orders o
	WHERE order_date BETWEEN '2026-01-01' AND '2026-12-31'
		AND order_status = 'completed'
	GROUP BY o.shipping_county
	ORDER BY completed_orders DESC
	LIMIT 5
) SELECT shipping_county,completed_orders
FROM shipping_counties;

--D6 Monthly completed orders in 2025


WITH monthly_count AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        COUNT(order_id) AS completed_orders
    FROM orders
    WHERE order_date >= '2025-01-01'
      AND order_date <  '2026-01-01'
      AND order_status = 'completed'
    GROUP BY DATE_TRUNC('month', order_date) -- 2025: completed orders per month
),
stats AS (
    SELECT
        month,
        completed_orders,
        AVG(completed_orders) OVER () AS avg_per_month
    FROM monthly_count
)
SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    completed_orders,
    ROUND(avg_per_month, 2) AS avg_per_month,
    CASE
        WHEN completed_orders > avg_per_month THEN 'above average'
        ELSE 'at/below average'
    END AS vs_average
FROM stats
ORDER BY month;

--D7 Write sokomart.fn_order_count(p_customer_id INTEGER) RETURNS INTEGER — the number of orders (any status) a customer has. Call it for customer 177 and for a customer that does not exist (-1).

CREATE OR REPLACE FUNCTION sokomart.fn_order_count(
    p_customer_id INTEGER
)
RETURNS INTEGER
LANGUAGE SQL
AS $$
    SELECT COUNT(*)::INTEGER
    FROM sokomart.orders
    WHERE customer_id = p_customer_id;
$$;

SELECT sokomart.fn_order_count(177) AS order_count;

SELECT sokomart.fn_order_count(-1) AS order_count;

--D8 Write sokomart.sp_set_customer_status(p_customer_id INTEGER, p_status VARCHAR). It raises an exception for a status other than active / inactive / suspended, and for a customer that does not exist. Inside BEGIN … ROLLBACK, set customer 177 to suspended, show it, roll back, show it is active again. Then show the exception for status 'vip'.
CREATE OR REPLACE PROCEDURE sokomart.sp_set_customer_status(
    IN p_customer_id INTEGER,
    IN p_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN

    -- Validation of the customer's status
    IF LOWER(p_status) NOT IN ('active', 'inactive', 'suspended') THEN
        RAISE EXCEPTION 'Invalid customer status: %. Allowed values are active, inactive, suspended.',
            p_status;
    END IF;

    -- Check whether the customer are existing
    IF NOT EXISTS (
        SELECT 1
        FROM sokomart.customers
        WHERE customer_id = p_customer_id
    ) THEN
        RAISE EXCEPTION 'Customer ID % does not exist.', p_customer_id;
    END IF;

    -- Update the customer status
    UPDATE sokomart.customers
    SET customer_status = LOWER(p_status)
    WHERE customer_id = p_customer_id;

END;
$$;

BEGIN;

CALL sokomart.sp_set_customer_status(177, 'suspended');

-- Check the updated status
SELECT customer_id, customer_status
FROM sokomart.customers
WHERE customer_id = 177;

ROLLBACK;

SELECT customer_id, customer_status
FROM sokomart.customers
WHERE customer_id = 177;

CALL sokomart.sp_set_customer_status(177, 'vip');
CALL sokomart.sp_set_customer_status(-1, 'suspended');


--D9 Beauty products whose stock_quantity is below the average Beauty stock. Put the Beauty products in a CTE and compare with a scalar subquery on that CTE.
WITH beauty_products AS (
    SELECT
        product_id,
        product_name,
        stock_quantity
    FROM sokomart.products
    WHERE category = 'Beauty'
)

SELECT
    product_id,
    product_name,
    stock_quantity,
    (
        SELECT AVG(stock_quantity)
        FROM products
    ) AS beauty_avg_stock
FROM products
WHERE stock_quantity < (
    SELECT AVG(stock_quantity)
    FROM products
)
ORDER BY stock_quantity ASC;

--D10 Write sokomart.sp_county_summary(IN p_county VARCHAR, OUT p_customers INTEGER, OUT p_revenue NUMERIC) returning the number of customers living in the county and their completed revenue. CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);

CREATE OR REPLACE PROCEDURE sokomart.sp_county_summary(
    IN p_county VARCHAR,
    OUT p_customers INTEGER,
    OUT p_revenue NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN

    -- Count customers in the specified county
    SELECT COUNT(*)::INTEGER
    INTO p_customers
    FROM sokomart.customers
    WHERE county = p_county;

    -- Calculate complete revenue
    SELECT COALESCE(SUM(o.total_amount), 0)
    INTO p_revenue
    FROM sokomart.orders o
    JOIN sokomart.customers c
        ON o.customer_id = c.customer_id
    WHERE c.county = p_county
      AND o.order_status = 'completed';

END;
$$;

CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);

select * from customers
limit 3;


--Q1

-- QUESTION 1: BIG SPENDERS OF 2025

WITH customer_revenue AS (SELECT
        c.customer_id, c.first_name || ' ' || c.last_name AS full_name,c.county,
        SUM(o.total_amount) AS total_spent_2025
    FROM sokomart.customers c
    JOIN sokomart.orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01'
      AND o.order_date < '2026-01-01'
    GROUP BY
        c.customer_id, c.first_name,c.last_name,c.county
						)

SELECT customer_id,full_name,county,total_spent_2025,
    (SELECT AVG(total_spent_2025)
     FROM customer_revenue) AS avg_spent_2025,
    total_spent_2025 -
    (SELECT AVG(total_spent_2025)
     FROM customer_revenue) AS amount_above_avg
FROM customer_revenue
WHERE total_spent_2025 >
      (SELECT AVG(total_spent_2025)
       FROM customer_revenue)
ORDER BY total_spent_2025 DESC;


--Q2 PREMIUM-PRICED PRODUCTS

SELECT p.product_id,p.product_name,p.category,p.unit_price,
        (
        SELECT AVG(p2.unit_price)
        FROM sokomart.products p2
        WHERE p2.category = p.category
          ) AS category_avg_price,

    p.unit_price -
    (
        SELECT AVG(p2.unit_price)
        FROM sokomart.products p2
        WHERE p2.category = p.category
    ) AS price_gap
FROM sokomart.products p
WHERE p.product_status = 'active'
AND p.unit_price >
    (
        SELECT AVG(p2.unit_price)
        FROM sokomart.products p2
        WHERE p2.category = p.category
    )
ORDER BY p.category,price_gap DESC;

--Q3 2026 MONTHLY PROFIT AND LOSS

WITH completed_order_lines AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS month,oi.line_total AS revenue, oi.quantity * p.cost_price AS cost
    FROM sokomart.orders o
    JOIN sokomart.order_items oi
        ON o.order_id = oi.order_id
    JOIN sokomart.products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2026-01-01'
      AND o.order_date < '2026-11-01'
),

monthly_totals AS (

    -- Calculate monthly revenue and cost.

    SELECT
        month,
        SUM(revenue) AS revenue,
        SUM(cost) AS cost

    FROM completed_order_lines

    GROUP BY month
),

monthly_profit AS (

    -- Calculate gross profit.

    SELECT
        month,
        revenue,
        cost,
        revenue - cost AS gross_profit

    FROM monthly_totals
),

calendar_months AS (

    -- Generate all 10 months,
    -- including months without completed sales.

    SELECT
        GENERATE_SERIES(
            DATE '2026-01-01',
            DATE '2026-10-01',
            INTERVAL '1 month'
        )::DATE AS month
)

--OUTPUT

SELECT
    cm.month,
    COALESCE(mp.revenue, 0) AS revenue,
    COALESCE(mp.cost, 0) AS cost,
    COALESCE(mp.gross_profit, 0) AS gross_profit,
    ROUND(
        COALESCE( mp.gross_profit * 100.0 / NULLIF(mp.revenue, 0), 0),
        2
    ) AS margin_pct
FROM calendar_months cm
LEFT JOIN monthly_profit mp
    ON cm.month = mp.month
ORDER BY cm.month;

--Q4 CROSS-CATEGORY SHOPPERS IN NAKURU

SELECT
    c.customer_id,c.first_name || ' ' || c.last_name AS full_name,c.county,sales.category_count, sales.total_spent
FROM sokomart.customers c
JOIN (
    SELECT
        o.customer_id, COUNT(DISTINCT p.category) AS category_count, SUM(oi.line_total) AS total_spent
    FROM sokomart.orders o
    JOIN sokomart.order_items oi
        ON o.order_id = oi.order_id
    JOIN sokomart.products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'completed'
    GROUP BY o.customer_id) AS sales
ON c.customer_id = sales.customer_id
WHERE c.county = 'Nakuru'
  AND sales.category_count >= 3
ORDER BY
    sales.category_count DESC,
    sales.total_spent DESC;

--Q5 PRODUCTS NOBODY HAS ORDERED

SELECT
    p.product_id, p.product_name,p.category,p.product_status,p.stock_quantity,p.created_at
FROM sokomart.products p
WHERE NOT EXISTS (
    SELECT 1
    FROM sokomart.order_items oi
    WHERE oi.product_id = p.product_id
)
ORDER BY
    p.category,
    p.product_name;  

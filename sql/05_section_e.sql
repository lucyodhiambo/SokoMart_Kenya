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


-- Question 21: Read a query plan (the Kisumu dashboard query)


-- Step 1 explain analyze  runs the query and reports what happened;
-- BUFFERS adds how many data pages were read. Screenshot the whole plan.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o ON o.customer_id = c.customer_id
JOIN sokomart.order_items i ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;


-- Step 2: the query itself note the row count.
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o  ON o.customer_id = c.customer_id
JOIN sokomart.order_items i ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;




*/
--Q22
-- (a) BEFORE: drop the secondary indexes (the block from the bottom of 05_indexes.sql)
DROP INDEX IF EXISTS sokomart.idx_customers_county, sokomart.idx_customers_registration_date,
    sokomart.idx_products_category, sokomart.idx_orders_customer_id, sokomart.idx_orders_order_date,
    sokomart.idx_orders_status_date, sokomart.idx_orders_customer_date,
    sokomart.idx_order_items_product_id, sokomart.idx_payments_order_id,
    sokomart.idx_payments_status_method, sokomart.idx_payments_payment_date,
    sokomart.idx_price_history_product_id, sokomart.idx_status_history_order_id;


-- Refresh the planner's statistics, then take the three plans (screenshot each one)
ANALYZE sokomart.customers, sokomart.products, sokomart.orders, sokomart.order_items, sokomart.payments;

-- Query 1: one customer's orders in date order
EXPLAIN ANALYZE
SELECT order_id, order_date, total_amount 
FROM sokomart.orders 
WHERE customer_id = 408 ORDER BY order_date;

-- Query 2: the payment(s) of one order
EXPLAIN ANALYZE
SELECT * FROM sokomart.payments WHERE order_id = 25000;

-- Query 3: every order line for one product
EXPLAIN ANALYZE
SELECT order_id, quantity, line_total
FROM sokomart.order_items 
WHERE product_id = 71;

-- (b) AFTER: create the indexes again (the same statements as 05_indexes.sql, without the psql-only lines)
CREATE INDEX IF NOT EXISTS idx_customers_county  ON sokomart.customers (county);
CREATE INDEX IF NOT EXISTS idx_customers_registration_date ON sokomart.customers (registration_date);
CREATE INDEX IF NOT EXISTS idx_products_category ON sokomart.products (category);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON sokomart.orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date  ON sokomart.orders (order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status_date ON sokomart.orders (order_status, order_date);
CREATE INDEX IF NOT EXISTS idx_orders_customer_date  ON sokomart.orders (customer_id, order_date);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id  ON sokomart.order_items (product_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON sokomart.payments (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_method ON sokomart.payments (payment_status, payment_method);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON sokomart.payments (payment_date);
CREATE INDEX IF NOT EXISTS idx_price_history_product_id  ON sokomart.product_price_history (product_id);
CREATE INDEX IF NOT EXISTS idx_status_history_order_id  ON sokomart.order_status_history (order_id);

ANALYZE sokomart.customers, sokomart.products, sokomart.orders, sokomart.order_items, sokomart.payments;

-- The same three plans again 
EXPLAIN ANALYZE
SELECT order_id, order_date, total_amount 
FROM sokomart.orders 
WHERE customer_id = 408 
ORDER BY order_date;

EXPLAIN ANALYZE
SELECT * FROM sokomart.payments WHERE order_id = 25000;

EXPLAIN ANALYZE
SELECT order_id, quantity, line_total 
FROM sokomart.order_items 
WHERE product_id = 71;

-- (c) Partial index: it only contains pending orders
CREATE INDEX IF NOT EXISTS idx_orders_pending_date
    ON sokomart.orders (order_date)
    WHERE order_status = 'pending';


ANALYZE sokomart.orders;

-- A plan that uses it (the query must repeat the index's condition: order_status = 'pending')
EXPLAIN ANALYZE
SELECT order_id, order_date, total_amount
FROM sokomart.orders
WHERE order_status = 'pending' AND order_date < '2026-10-25';

-- Size comparison
SELECT
    pg_size_pretty(pg_relation_size('sokomart.idx_orders_pending_date')) AS partial_index_size,
    pg_size_pretty(pg_relation_size('sokomart.idx_orders_order_date'))   AS full_index_size,
    pg_relation_size('sokomart.idx_orders_pending_date') AS partial_bytes,
    pg_relation_size('sokomart.idx_orders_order_date')   AS full_bytes;

-- Comparison table: fill in from YOUR plans (scan type, Execution Time and rows for each)


-- Question 23: Transactions you can see
-- Tip for DBeaver: run each statement one at a time (Ctrl+Enter) so that BEGIN, the
-- changes and ROLLBACK/COMMIT all happen in the same session, and screenshot each step.
-- ------------------------------------------------------------

-- (a) Try a 10% Beauty price cut, then undo it
SELECT ROUND(AVG(unit_price), 2) AS avg_beauty_price_before
FROM sokomart.products
WHERE category = 'Beauty';

BEGIN;

UPDATE sokomart.products
SET unit_price = ROUND(unit_price * 0.90, 2)
WHERE category = 'Beauty';

SELECT ROUND(AVG(unit_price), 2) AS avg_beauty_price_inside_transaction
FROM sokomart.products
WHERE category = 'Beauty';

ROLLBACK;

SELECT ROUND(AVG(unit_price), 2) AS avg_beauty_price_after_rollback
FROM sokomart.products
WHERE category = 'Beauty';

-- (b) Restock product 59, make a "mistake" on product 166, and undo only the mistake
SELECT product_id, product_name, stock_quantity
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;

BEGIN;

UPDATE sokomart.products
SET stock_quantity = stock_quantity + 40
WHERE product_id = 59;

INSERT INTO sokomart.audit_logs (table_name, record_id, action, old_data, new_data)
SELECT 'products', 59, 'UPDATE',
       jsonb_build_object('stock_quantity', stock_quantity - 40),
       jsonb_build_object('stock_quantity', stock_quantity, 'reason', 'restock +40')
FROM sokomart.products
WHERE product_id = 59;

SAVEPOINT after_restock;

-- ERRORs
UPDATE sokomart.products SET stock_quantity = 0 WHERE product_id = 166;

SELECT product_id, stock_quantity      
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;

ROLLBACK TO SAVEPOINT after_restock;         

COMMIT;

SELECT product_id, stock_quantity            
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;

SELECT table_name, record_id, action, old_data, new_data      
FROM sokomart.audit_logs
WHERE table_name = 'products' AND record_id = 59
ORDER BY audit_id DESC
LIMIT 1;

-- (c) A failed statement aborts the whole transaction
SELECT product_id, stock_quantity FROM sokomart.products WHERE product_id = 166;   -- before

BEGIN;

UPDATE sokomart.products SET stock_quantity = stock_quantity + 1 WHERE product_id = 166;

--  ERROR: violates chk_products_stock (stock cant be negative)
UPDATE sokomart.products SET stock_quantity = -5 WHERE product_id = 166;

-- ERROR: "current transaction is aborted, commands are ignored until end of transaction block"
SELECT product_id, stock_quantity FROM sokomart.products WHERE product_id = 166;

COMMIT;   -- reports ROLLBACK: the +1 was undone too

SELECT product_id, stock_quantity FROM sokomart.products WHERE product_id = 166;   -- unchanged


-- Question 24: Clean up the duplicate payments
-- A duplicate = same payment_id, order_id, payment_date, payment_method, amount,
-- payment_status and transaction_reference. We keep the first-loaded copy.
-- PARTITION BY treats NULL references as equal, so rows with no reference still match.
-- ------------------------------------------------------------

-- (a) the problem
WITH numbered AS (
    SELECT
        staging_id,
        -- with ORDER BY: numbers the copies 1, 2, 3 in load order
        ROW_NUMBER() OVER (
            PARTITION BY payment_id, order_id, payment_date, payment_method,
                         amount, payment_status, transaction_reference
            ORDER BY loaded_at, staging_id
        ) AS copy_no,
        -- without ORDER BY: counts ALL copies of the payment (an ORDER BY would make it a running count)
        COUNT(*) OVER (
            PARTITION BY payment_id, order_id, payment_date, payment_method,
                         amount, payment_status, transaction_reference
        ) AS copies
    FROM sokomart.payment_staging
)
SELECT
    COUNT(*) FILTER (WHERE copy_no = 1 AND copies > 1) AS duplicated_payments,
    COUNT(*) FILTER (WHERE copy_no > 1)                AS extra_rows_to_delete,
    MAX(copies)                                        AS max_copies
FROM numbered;

-- (b) The first 10 rows that will be deleted, with their copy number
WITH numbered AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY payment_id, order_id, payment_date, payment_method,
                         amount, payment_status, transaction_reference
            ORDER BY loaded_at, staging_id
        ) AS copy_no
    FROM sokomart.payment_staging s
)
SELECT staging_id, payment_id, transaction_reference, amount, source_file, loaded_at, copy_no
FROM numbered
WHERE copy_no > 1
ORDER BY staging_id
LIMIT 10;

-- (c) Before rows and distinct payments
SELECT
    COUNT(*)  AS staging_rows_before,
    COUNT(DISTINCT payment_id) AS distinct_payments_before
FROM sokomart.payment_staging;

BEGIN;

WITH numbered AS (
    SELECT
        staging_id,
        ROW_NUMBER() OVER (
            PARTITION BY payment_id, order_id, payment_date, payment_method,
                         amount, payment_status, transaction_reference
            ORDER BY loaded_at, staging_id
        ) AS copy_no
    FROM sokomart.payment_staging
),
extra_rows AS (
    SELECT staging_id FROM numbered WHERE copy_no > 1
)
DELETE FROM sokomart.payment_staging ps
USING extra_rows e
WHERE ps.staging_id = e.staging_id;

-- Check inside the transaction rows = distinct payments, and the amounts agree with payments
SELECT
    COUNT(*)  AS staging_rows_after,
    COUNT(DISTINCT payment_id) AS distinct_payments_after,
    SUM(amount) AS staged_amount_after,
    (SELECT SUM(p.amount)
     FROM sokomart.payments p
     WHERE p.payment_id IN (SELECT payment_id FROM sokomart.payment_staging)) AS same_payments_in_payments_table
FROM sokomart.payment_staging;

COMMIT;   -- if the check had looked wrong, ROLLBACK; would have undone the delete

-- (d) Make sure it can never happen again: one staging row per payment
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_staging_payment_id
    ON sokomart.payment_staging (payment_id);

--  ERROR: re-inserting an existing payment now fails (duplicate key)
INSERT INTO sokomart.payment_staging
    (staging_id, payment_id, order_id, payment_date, payment_method, amount,
     payment_status, transaction_reference, source_file, loaded_at)
SELECT
    (SELECT MAX(staging_id) + 1 FROM sokomart.payment_staging),
    payment_id, order_id, payment_date, payment_method, amount,
    payment_status, transaction_reference, source_file, NOW()
FROM sokomart.payment_staging
ORDER BY staging_id
LIMIT 1;




-- Question 25: Three months in a row (gaps and islands)
-- 1. customer_months: one row per customer per month with a completed order.
-- 2. numbered: month_no (a running month count) minus ROW_NUMBER() stays the same
--    for months that follow each other, and jumps when a month is skipped.
--    Each constant value is one "island" (one streak).
-- 3. streaks: group each island and keep those of 3 or more months.
-- 4. best: each customer's longest streak (earliest first if two are tied).

WITH customer_months AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_TRUNC('month', o.order_date)::DATE AS month_start
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
),
numbered AS (
    select customer_id,month_start,
        (EXTRACT(YEAR FROM month_start) * 12 + EXTRACT(MONTH FROM month_start))::INTEGER
            - ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_start)::INTEGER AS island_key
    FROM customer_months
),
streaks AS (
    SELECT
        customer_id,
        MIN(month_start) AS streak_start,
        MAX(month_start) AS streak_end,
        COUNT(*) AS streak_length
    FROM numbered
    GROUP BY customer_id, island_key
    HAVING COUNT(*) >= 3
),
best AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY streak_length DESC, streak_start
        ) AS rn
    FROM streaks s
)
SELECT
    b.customer_id,c.first_name || ' ' || c.last_name   AS full_name,
    c.county,
    TO_CHAR(b.streak_start, 'YYYY-MM')   AS streak_start_month,
    TO_CHAR(b.streak_end,   'YYYY-MM')   AS streak_end_month,
    b.streak_length
FROM best b
JOIN sokomart.customers c ON c.customer_id = b.customer_id
WHERE b.rn = 1
ORDER BY b.streak_length DESC, b.customer_id
LIMIT 10;

-- Second query: how many customers qualify, and the longest streak in the data
WITH customer_months AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_TRUNC('month', o.order_date)::DATE AS month_start
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
),
numbered AS (
    SELECT
        customer_id,
        month_start,
        (EXTRACT(YEAR FROM month_start) * 12 + EXTRACT(MONTH FROM month_start))::INTEGER
            - ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_start)::INTEGER AS island_key
    FROM customer_months
),
streaks AS (
    SELECT
        customer_id,
        MIN(month_start) AS streak_start,
        COUNT(*)         AS streak_length
    FROM numbered
    GROUP BY customer_id, island_key
    HAVING COUNT(*) >= 3
)
SELECT
    COUNT(DISTINCT customer_id) AS customers_with_3plus_streak,
    MAX(streak_length)          AS longest_streak
FROM streaks;

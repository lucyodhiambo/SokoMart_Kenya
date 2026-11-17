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

/*Question 11 — Customer tiers (Medium)
Scenario. The loyalty programme has four tiers by lifetime revenue:
Platinum ≥ KES 1,000,000; Gold ≥ 500,000; Silver ≥ 100,000; Bronze below 100,000.
Task. For customers with at least one completed order: compute lifetime revenue in an inner
derived table, assign the tier with CASE in a second derived table around it, then aggregate
per tier. revenue_share_pct is the tier's share of total completed revenue — compute that total
with a scalar subquery. Order from Platinum to Bronze.
Required concept. Nested derived tables, CASE, scalar subquery.
Expected output. tier, customer_count, min_spent, max_spent, avg_spent, revenue_share_pct (4 rows)*/

SELECT
    tier, COUNT(*) AS customer_count, MIN(total_spent) AS min_spent, MAX(total_spent) AS max_spent, ROUND(AVG(total_spent), 2)AS avg_spent,
    ROUND( 100.0 * SUM(total_spent) / (
            SELECT SUM(oi.line_total)
            FROM order_items oi
            JOIN orders o ON o.order_id = oi.order_id
            WHERE o.order_status = 'completed' ),2 )   AS revenue_share_pct
FROM (select customer_id,total_spent,
        CASE
            WHEN total_spent >= 1000000 THEN 'Platinum'
            WHEN total_spent >=  500000 THEN 'Gold'
            WHEN total_spent >=  100000 THEN 'Silver'
            ELSE 'Bronze'
        END AS tier
    FROM (SELECT o.customer_id,SUM(oi.line_total) AS total_spent
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        WHERE o.order_status = 'completed'
        GROUP BY o.customer_id
    ) AS customer_revenue
) AS customer_tiers
GROUP BY tier
ORDER BY CASE tier
             WHEN 'Platinum' THEN 1
             WHEN 'Gold'     THEN 2
             WHEN 'Silver'   THEN 3
             ELSE 4
         END;

/*Question 12 — What did Mombasa buy in October? (Medium)
Scenario. The Mombasa team wants a one-line shopping list per customer for October 2026.
Task. For customers living in Mombasa who have at least one non-cancelled order placed
in October 2026 (check this with EXISTS), list the distinct products on those October orders
as one string, alphabetical, separated by '; '. Order by product_count descending, then
customer_id. Second query: the number of customers that qualify.
Required concept. STRING_AGG(DISTINCT … ORDER BY …), EXISTS.
Expected output. customer_id, full_name, product_count, products_ordered*/

SELECT
    c.customer_id, c.first_name || ' ' || c.last_name  AS full_name,COUNT(DISTINCT p.product_id) AS product_count,
    STRING_AGG(DISTINCT p.product_name, '; ' ORDER BY p.product_name) AS products_ordered
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products p     ON p.product_id  = oi.product_id
WHERE c.county = 'Mombasa'
  AND o.order_status <> 'cancelled'
  AND o.order_date >= '2026-10-01'
  AND o.order_date <  '2026-11-01'
  AND EXISTS (
        SELECT 1
        FROM orders o2
        WHERE o2.customer_id  = c.customer_id
          AND o2.order_status <> 'cancelled'
          AND o2.order_date  >= '2026-10-01'
          AND o2.order_date  <  '2026-11-01'
  )
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY product_count DESC, c.customer_id;

-- Second query: how many customers qualify
SELECT COUNT(*) AS qualifying_customers
FROM customers c
WHERE c.county = 'Mombasa'
  AND EXISTS (
        SELECT 1
        FROM orders o
        WHERE o.customer_id  = c.customer_id
          AND o.order_status <> 'cancelled'
          AND o.order_date  >= '2026-10-01'
          AND o.order_date  <  '2026-11-01'
  );

/*Question 13 — Payment health by method, 2026 (Medium)
Scenario. The payments team suspects one channel fails more often than the others.
Task. Put 2026 payments (by payment_date) in a CTE. Per payment_method: total payments,
successful, failed, pending (each with COUNT(*) FILTER (WHERE …)), success rate %, and the total
amount of failed payments. Order by total_payments descending.
Required concept. FILTER clause, CTE.
Expected output. payment_method, total_payments, successful, failed, pending, success_rate_pct, failed_amount (4 rows)*/
with payments_2026 as (
    select payment_method, payment_status, amount
    from payments
    where payment_date >= '2026-01-01'
      and payment_date <  '2027-01-01'
)
select
    payment_method,count(*) as total_payments,count(*) filter (where payment_status = 'successful') as successful,
    count(*) filter (where payment_status = 'failed')     as failed,count(*) filter (where payment_status = 'pending')    as pending,
    round( 100.0 * count(*) filter (where payment_status = 'successful') / count(*), 2) as success_rate_pct,
    coalesce(sum(amount) filter (where payment_status = 'failed'), 0) as failed_amount
from payments_2026
group by payment_method
order by total_payments desc;

/*Question 14 — Which departments carry the profit? (Medium)
Scenario. The board asks which categories earned more gross profit than the average
category in 2025.
Task. CTE with 2025 revenue and gross profit per category. Return only the categories whose
gross profit is above the average category gross profit (use a scalar subquery on the CTE —
not a hard-coded number). Show the margin and how far above the average each one is, in %.
Order by gross_profit descending.
Required concept. CTE + scalar subqueries in SELECT and WHERE.
Expected output. category, revenue, gross_profit, margin_pct, avg_category_gross_profit, pct_above_avg*/

with category_2025 as (
    select p.category, sum(oi.line_total) as revenue, sum(oi.line_total - oi.quantity * p.cost_price) as gross_profit
    from orders o
    join order_items oi on oi.order_id = o.order_id
    join products p on p.product_id = oi.product_id
    where o.order_status = 'completed'
      and o.order_date >= '2025-01-01'
      and o.order_date < '2026-01-01'
    group by p.category
)
select category,revenue,gross_profit,
    round(100.0 * gross_profit / revenue, 2) as margin_pct,
    (select round(avg(gross_profit), 2) from category_2025) as avg_category_gross_profit,
    round(100.0 * (gross_profit - (select avg(gross_profit) from category_2025))/ (select avg(gross_profit) from category_2025),2) as pct_above_avg
from category_2025
where gross_profit > (select avg(gross_profit) from category_2025)
order by gross_profit desc;

/*Question 15 — One sales table with subtotals (Hard)
Scenario. Regional heads want 2026 revenue for Nairobi, Mombasa, Kisumu, Nakuru and Uasin Gishu
by category, with county subtotals, category subtotals and a grand total — in one query.
Task. CTE with the 2026 completed order lines for those five shipping counties. Aggregate
with GROUPING SETS ((county, category), (county), (category), ()). Label each row with
GROUPING(): county x category, county total, category total, grand total; show
ALL COUNTIES / ALL CATEGORIES instead of NULL. order_count = distinct orders.
Required concept. GROUPING SETS, GROUPING().
Expected output. grouping_level, county, category, revenue, order_count (36 rows)*/

with lines_2026 as (
    select o.order_id,o.shipping_county as county,p.category,oi.line_total
    from orders o
    join order_items oi on oi.order_id = o.order_id
    join products p on p.product_id = oi.product_id
    where o.order_status = 'completed'
      and o.order_date >= '2026-01-01'
      and o.order_date < '2027-01-01'
      and o.shipping_county in ('Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Uasin Gishu')
)
select
    case 2 * grouping(county) + grouping(category)
        when 0 then 'county x category'
        when 1 then 'county total'
        when 2 then 'category total'
        else 'grand total'
    end as grouping_level,
    coalesce(county, 'ALL COUNTIES') as county,
    coalesce(category, 'ALL CATEGORIES') as category,
    sum(line_total) as revenue,
    count(distinct order_id) as order_count
from lines_2026
group by grouping sets ((county, category),(county),(category),())
order by 2 * grouping(county) + grouping(category), county, category;


-- Question 16 (a): v_customer_purchase_summary
-- One row for every customer, including customers with no completed orders
-- (0 orders, 0 spent, NULL dates). Days are counted to 31 October 2026.


create or replace view sokomart.v_customer_purchase_summary as
with order_totals as (
    select o.customer_id, o.order_id,o.order_date,
        sum(oi.line_total) as order_revenue
    from sokomart.orders o
    join sokomart.order_items oi on oi.order_id = o.order_id
    where o.order_status = 'completed'
    group by o.customer_id, o.order_id, o.order_date
),
customer_totals as (
    select
        customer_id, count(*) as completed_orders, sum(order_revenue) as lifetime_spent, min(order_date) as first_order_ts,
        max(order_date) as last_order_ts
    from order_totals
    group by customer_id
)
select
    c.customer_id, c.first_name || ' ' || c.last_name as full_name,c.county,c.registration_date,
    coalesce(ct.completed_orders, 0) as completed_orders,coalesce(ct.lifetime_spent, 0) as lifetime_spent,
    round(ct.lifetime_spent / nullif(ct.completed_orders, 0), 2) as avg_order_value,
    ct.first_order_ts::date as first_order_date,
    ct.last_order_ts::date as last_order_date,
    date '2026-10-31' - ct.last_order_ts::date as days_since_last_order
from sokomart.customers c
left join customer_totals ct on ct.customer_id = c.customer_id;

-- Top 10 customers living in Kiambu by lifetime_spent
select *
from sokomart.v_customer_purchase_summary
where county = 'Kiambu'
order by lifetime_spent desc, customer_id
limit 10;

-- Rows in the view and customers with no completed orders
select
    count(*) as rows_in_view,
    count(*) filter (where completed_orders = 0) as customers_without_completed_orders
from sokomart.v_customer_purchase_summary;

-- ------------------------------------------------------------
-- Question 16 (b): mv_monthly_category_sales
-- One row per month and category for completed orders.
-- The unique index is required for REFRESH MATERIALIZED VIEW CONCURRENTLY.drop materialized view if exists sokomart.mv_monthly_category_sales;
create materialized view sokomart.mv_monthly_category_sales as
select
    to_char(date_trunc('month', o.order_date), 'YYYY-MM') as sales_month, p.category,
    count(distinct o.order_id) as orders,sum(oi.quantity) as units_sold,sum(oi.line_total) as revenue,
    sum(oi.line_total - oi.quantity * p.cost_price) as gross_profit
from sokomart.orders o
join sokomart.order_items oi on oi.order_id = o.order_id
join sokomart.products p on p.product_id = oi.product_id
where o.order_status = 'completed'
group by date_trunc('month', o.order_date), p.category;

create unique index uq_mv_monthly_category_sales
    on sokomart.mv_monthly_category_sales (sales_month, category);

-- December 2025 rows, biggest revenue first
select sales_month, category, orders, units_sold, revenue, gross_profit
from sokomart.mv_monthly_category_sales
where sales_month = '2025-12'
order by revenue desc;

-- Question 17: fn_customer_spend(customer, start date, end date)
-- Completed revenue for orders from the start date to the end of the end date.
-- Returns 0 (not NULL) when there is nothing; raises an error for a bad date range.

create or replace function sokomart.fn_customer_spend(
    p_customer_id integer,
    p_start_date date,
    p_end_date date
)
returns numeric
language plpgsql
as $$
begin
    if p_start_date is null or p_end_date is null then
        raise exception 'Start date and end date are both required.';
    end if;
    if p_end_date < p_start_date then
        raise exception 'End date (%) cannot be before start date (%).', p_end_date, p_start_date;
    end if;
    return coalesce((
        select sum(oi.line_total)
        from sokomart.orders o
        join sokomart.order_items oi on oi.order_id = o.order_id
        where o.customer_id = p_customer_id
          and o.order_status = 'completed'
          and o.order_date >= p_start_date
          and o.order_date < p_end_date + 1      -- the day is included
    ), 0);
end;
$$;

-- (1) Five numbers for customer 4000, plus an unknown customer (-1)
select
    sokomart.fn_customer_spend(4000, '2025-01-01', '2025-12-31') as spend_2025,
    sokomart.fn_customer_spend(4000, '2026-01-01', '2026-10-31') as spend_jan_oct_2026,
    sokomart.fn_customer_spend(4000, '2025-01-01', '2026-10-31') as spend_all_time,
    sokomart.fn_customer_spend(4000, '2025-12-01', '2025-12-31') as spend_december_2025,
    sokomart.fn_customer_spend(-1,   '2025-01-01', '2026-10-31') as spend_unknown_customer;
-- (2) The all-time value matches lifetime_spent in the Q16 view
select
    v.customer_id,
    v.lifetime_spent,
    sokomart.fn_customer_spend(v.customer_id, '2025-01-01', '2026-10-31') as fn_value,
    v.lifetime_spent = sokomart.fn_customer_spend(v.customer_id, '2025-01-01', '2026-10-31') as matches
from sokomart.v_customer_purchase_summary v
where v.customer_id = 4000;
-- (3) Using the function inside a query: top 5 Nairobi customers by December 2025 spend
select
    c.customer_id,
    c.first_name || ' ' || c.last_name                                  as full_name,
    sokomart.fn_customer_spend(c.customer_id, '2025-12-01', '2025-12-31') as december_2025_spend
from sokomart.customers c
where c.county = 'Nairobi'
order by december_2025_spend desc, c.customer_id
limit 5;
-- (4) EXPECTED ERROR: the end date is before the start date
select sokomart.fn_customer_spend(4000, '2026-02-01', '2026-01-01');


-- question 18: sp_update_product_price
-- locks the product row, validates, updates the price and writes to
-- product_price_history and audit_logs, all in one transaction.
create or replace procedure sokomart.sp_update_product_price(
    p_product_id integer,
    p_new_price numeric,
    p_reason varchar
)
language plpgsql
as $$
declare
    v_old_price numeric(12,2);
    v_cost numeric(12,2);
begin
    -- lock the row so nobody else changes this product's price at the same time
    select unit_price, cost_price
    into v_old_price, v_cost
    from sokomart.products
    where product_id = p_product_id
    for update;
    if not found then
        raise exception 'Product % does not exist.', p_product_id;
    end if;
    if p_new_price is null or p_new_price <= 0 then
        raise exception 'New price must be greater than zero (got %).', p_new_price;
    end if;
    if p_new_price < v_cost then
        raise exception 'New price % is below the cost price % for product %.', p_new_price, v_cost, p_product_id;
    end if;
    update sokomart.products
    set unit_price = p_new_price
    where product_id = p_product_id;
    insert into sokomart.product_price_history (product_id, old_price, new_price, change_reason)
    values (p_product_id, v_old_price, p_new_price, p_reason);
    insert into sokomart.audit_logs (table_name, record_id, action, old_data, new_data)
    values (
        'products',
        p_product_id,
        'UPDATE',
        jsonb_build_object('unit_price', v_old_price),
        jsonb_build_object('unit_price', p_new_price)
    );
end;
$$;


-- before
select product_id, product_name, unit_price, cost_price
from sokomart.products
where product_id = 71;

call sokomart.sp_update_product_price(71, 1099.00, 'Supplier price increase - Nov 2026');



-- after: new price, the history row and the audit row
select product_id, product_name, unit_price, cost_price
from sokomart.products
where product_id = 71;





select price_history_id, product_id, old_price, new_price, change_reason
from sokomart.product_price_history
where product_id = 71
order by price_history_id;
select table_name, record_id, action, old_data, new_data
from sokomart.audit_logs
where table_name = 'products' and record_id = 71
order by audit_id;
-- expected error: 500.00 is below the cost price
call sokomart.sp_update_product_price(71, 500.00, 'Test: below cost');






-- proof that nothing extra was written (still 1 history row, price unchanged)
select
    (select count(*) from sokomart.product_price_history where product_id = 71) as history_rows,
    (select unit_price from sokomart.products where product_id = 71) as current_price;



-- ------------------------------------------------------------
-- question 19 (a): trigger function + trigger trg_orders_status_audit
-- fires after an order is inserted, or after its order_status is updated.
-- on insert: old_status is null. on update: only when the status really changed.
-- each case also writes an audit_logs row.

create or replace function sokomart.fn_orders_status_audit()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' then
        insert into sokomart.order_status_history (order_id, old_status, new_status)
        values (new.order_id, null, new.order_status);
        insert into sokomart.audit_logs (table_name, record_id, action, old_data, new_data)
        values ('orders', new.order_id, 'INSERT', null,
                jsonb_build_object('order_status', new.order_status));
    elsif tg_op = 'UPDATE' and new.order_status is distinct from old.order_status then
        insert into sokomart.order_status_history (order_id, old_status, new_status)
        values (new.order_id, old.order_status, new.order_status);
        insert into sokomart.audit_logs (table_name, record_id, action, old_data, new_data)
        values ('orders', new.order_id, 'UPDATE',
                jsonb_build_object('order_status', old.order_status),
                jsonb_build_object('order_status', new.order_status));
    end if;
    return null;   -- the return value of an after row trig is ignored
end;
$$;
drop trigger if exists trg_orders_status_audit on sokomart.orders;
create trigger trg_orders_status_audit
after insert or update of order_status on sokomart.orders
for each row
execute function sokomart.fn_orders_status_audit();
-- question 19 (b): sp_update_order_status
-- allowed changes: pending -> completed, pending -> cancelled, completed -> returned.
-- completed: the payment becomes successful. cancelled: an unpaid (pending) payment becomes failed.
-- the trigger writes the history and audit rows by itself.

create or replace procedure sokomart.sp_update_order_status(
    p_order_id integer,
    p_new_status varchar
)
language plpgsql
as $$
declare
    v_current_status varchar;
begin
    select order_status
    into v_current_status
    from sokomart.orders
    where order_id = p_order_id
    for update;
    if not found then
        raise exception 'Order % does not exist.', p_order_id;
    end if;
    if not (
           (v_current_status = 'pending' and p_new_status in ('completed', 'cancelled'))
        or (v_current_status = 'completed' and p_new_status = 'returned')
    ) then
        raise exception 'Order % cannot change from % to %.', p_order_id, v_current_status, p_new_status;
    end if;
    update sokomart.orders
    set order_status = p_new_status
    where order_id = p_order_id;
    if p_new_status = 'completed' then
        update sokomart.payments
        set payment_status = 'successful'
        where order_id = p_order_id;
    elsif p_new_status = 'cancelled' then
        update sokomart.payments
        set payment_status = 'failed'
        where order_id = p_order_id
          and payment_status = 'pending';
    end if;
end;
$$;

-- question 19 (c): prove it on order 48882 (pending)
-- before
select o.order_id, o.order_status, p.payment_status
from sokomart.orders o
join sokomart.payments p on p.order_id = o.order_id
where o.order_id = 48882;
call sokomart.sp_update_order_status(48882, 'completed');
-- after: order and payment, the history row and the audit row
select o.order_id, o.order_status, p.payment_status
from sokomart.orders o
join sokomart.payments p on p.order_id = o.order_id
where o.order_id = 48882;
select order_id, old_status, new_status
from sokomart.order_status_history
where order_id = 48882
order by history_id;
select table_name, record_id, action, old_data, new_data
from sokomart.audit_logs
where table_name = 'orders' and record_id = 48882
order by audit_id;
-- a plain update (not the procedure): the trigger still logs it
update sokomart.orders set order_status = 'returned' where order_id = 48882;
select order_id, old_status, new_status
from sokomart.order_status_history
where order_id = 48882
order by history_id;
-- an update that does not touch order_status: no new history row (still 2)
update sokomart.orders set shipping_county = shipping_county where order_id = 48882;
select order_id, old_status, new_status
from sokomart.order_status_history
where order_id = 48882
order by history_id;
-- expected error: order 49961 is cancelled, and cancelled -> completed is not allowed
call sokomart.sp_update_order_status(49961, 'completed');
-- ------------------------------------------------------------
-- question 20: sp_place_order (all or nothing)
-- everything below runs in one transaction. if any step fails, the order,
-- the lines, the payment and the stock changes are all undone.
-- ------------------------------------------------------------
create or replace procedure sokomart.sp_place_order(
    p_customer_id integer, p_product_ids integer[], p_quantities integer[], p_payment_method varchar,
    inout p_order_id integer default null
)
language plpgsql
as $$
declare
    v_county varchar;
    v_status varchar;
    v_index integer;
    v_product_id integer;
    v_quantity integer;
    v_price numeric(12,2);
    v_available integer;
    v_items_total numeric(12,2) := 0;
    v_delivery_fee numeric(10,2);
    v_reference varchar;
begin
    -- 1. check the customer
    select county, customer_status
    into v_county, v_status
    from sokomart.customers
    where customer_id = p_customer_id;
    if not found then
        raise exception 'Customer % does not exist.', p_customer_id;
    end if;
    if v_status <> 'active' then
        raise exception 'Customer % is not active (status: %).', p_customer_id, v_status;
    end if;
    -- 2. check the arrays and the payment method
    if p_product_ids is null or p_quantities is null or coalesce(cardinality(p_product_ids), 0) = 0 then
        raise exception 'An order needs at least one product and one quantity.';
    end if;
    if cardinality(p_product_ids) <> cardinality(p_quantities) then
        raise exception 'Product list has % items but quantity list has % items.',
            cardinality(p_product_ids), cardinality(p_quantities);
    end if;
    if p_payment_method is null
       or p_payment_method not in ('M-Pesa', 'card', 'cash on delivery', 'bank transfer') then
        raise exception 'Unknown payment method: %.', p_payment_method;
    end if;
    -- 3. create the order (pending, today, delivered to the customer's county)
    insert into sokomart.orders (customer_id, order_date, order_status, shipping_county, delivery_fee, total_amount)
    values (p_customer_id, now(), 'pending', v_county, 0, 0)
    returning order_id into p_order_id;
    -- 4. for each product: take the stock, then add the order line
    for v_index in 1 .. cardinality(p_product_ids) loop
        v_product_id := p_product_ids[v_index];
        v_quantity := p_quantities[v_index];
        if v_quantity is null or v_quantity <= 0 then
            raise exception 'Quantity for product % must be greater than zero.', v_product_id;
        end if;
        -- the conditional update is the stock lock: it only succeeds if enough stock remains
        update sokomart.products
        set stock_quantity = stock_quantity - v_quantity
        where product_id = v_product_id
          and stock_quantity >= v_quantity
          and product_status = 'active'
        returning unit_price into v_price;
        if not found then
            select stock_quantity into v_available
            from sokomart.products
            where product_id = v_product_id;
            raise exception 'Cannot order product %: requested %, available %.',
                v_product_id, v_quantity, coalesce(v_available, 0);
        end if;
        insert into sokomart.order_items (order_id, product_id, quantity, unit_price, discount_percentage, line_total)
        values (p_order_id, v_product_id, v_quantity, v_price, 0, v_price * v_quantity);
        v_items_total := v_items_total + v_price * v_quantity;
    end loop;
    -- 5. delivery fee: free from 5,000 of items; otherwise by county
    v_delivery_fee := case
        when v_items_total >= 5000 then 0
        when v_county = 'Nairobi' then 200
        when v_county in ('Kiambu', 'Kajiado', 'Machakos') then 250
        else 350
    end;
    update sokomart.orders
    set delivery_fee = v_delivery_fee,
        total_amount = v_items_total + v_delivery_fee
    where order_id = p_order_id;
    -- 6. pending payment for the full amount (cash on delivery has no reference)
    if p_payment_method <> 'cash on delivery' then
        v_reference :=
              case p_payment_method when 'M-Pesa' then 'MPX' when 'card' then 'CRD' else 'BNK' end
           || to_char(now(), 'YYMM')
           || chr(65 + floor(random() * 26)::int) || chr(65 + floor(random() * 26)::int)
           || chr(65 + floor(random() * 26)::int) || chr(65 + floor(random() * 26)::int)
           || lpad(floor(random() * 10000)::int::text, 4, '0');
    end if;
    insert into sokomart.payments (order_id, payment_date, payment_method, amount, payment_status, transaction_reference)
    values (p_order_id, now(), p_payment_method, v_items_total + v_delivery_fee, 'pending', v_reference);
end;
$$;
-- a successful order for customer 177
select product_id, unit_price, stock_quantity
from sokomart.products
where product_id in (6, 73, 82)
order by product_id;
call sokomart.sp_place_order(177, array[6, 73, 82], array[1, 2, 3], 'M-Pesa', null);


-- the new order is customer 177's most recent order
select
    o.order_id, o.customer_id, o.order_status, o.shipping_county, o.delivery_fee, o.total_amount,
    (select sum(line_total) from sokomart.order_items where order_id = o.order_id) as items_total
from sokomart.orders o
where o.order_id = (select max(order_id) from sokomart.orders where customer_id = 177);
select order_id, product_id, quantity, unit_price, line_total
from sokomart.order_items
where order_id = (select max(order_id) from sokomart.orders where customer_id = 177)
order by product_id;
select order_id, payment_method, amount, payment_status, (transaction_reference is not null) as has_reference
from sokomart.payments
where order_id = (select max(order_id) from sokomart.orders where customer_id = 177);
select product_id, stock_quantity
from sokomart.products
where product_id in (6, 73, 82)
order by product_id;


-- the history row the q19 trigger wrote for the new order
select order_id, old_status, new_status
from sokomart.order_status_history
where order_id = (select max(order_id) from sokomart.orders where customer_id = 177)
order by history_id;




-- demo 2: an order that must fail (product 59 has only 1 unit), so nothing is saved
select
    (select count(*) from sokomart.orders) as order_count,
    product_id,
    stock_quantity
from sokomart.products
where product_id in (6, 59)
order by product_id;



-- expected error: product 59 has 1 unit, 2 requested
call sokomart.sp_place_order(408, array[6, 59], array[1, 2], 'card', null);








-- unchanged: same order count and same stock, even for product 6 (which was processed first)
select
    (select count(*) from sokomart.orders) as order_count,
    product_id,
    stock_quantity
from sokomart.products
where product_id in (6, 59)
order by product_id;



-- demo 3: complete the new order, refresh the materialized view, show november 2026
-- (postgresql does not allow a subquery inside call, so a do block finds the order id first)
do $$
declare
    v_order_id integer;
begin
    select max(order_id) into v_order_id
    from sokomart.orders
    where customer_id = 177;
    call sokomart.sp_update_order_status(v_order_id, 'completed');
end;
$$;
refresh materialized view concurrently sokomart.mv_monthly_category_sales;
select sales_month, category, orders, units_sold, revenue, gross_profit
from sokomart.mv_monthly_category_sales
where sales_month = '2026-11'
order by category;
``


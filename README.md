# SokoMart Kenya: Advanced SQL Project (Days 1 to 4)

A four-day PostgreSQL project that uses the database of SokoMart Kenya, a synthetic online shop selling electronics, groceries, fashion, home appliances and beauty products across Kenya. Every task is a realistic request from someone in the business, answered with SQL and finished with business insights and recommendations.

## Overview

Over four days the project builds from subqueries and CTEs (Day 1), through window functions (Day 2) and advanced aggregation with views, functions, procedures and triggers (Day 3), to query optimisation, transactions and business insights (Day 4). In total it covers 10 practice drills and 25 business questions.

## Tech Stack

- **Database:** PostgreSQL
- **Languages:** SQL and PL/pgSQL
- **Client:** DBeaver
- **Schema:** sokomart

## Repository Structure

- **sql folder:** one SQL file per section. The practice drills and Section A (Day 1), B_window_functions.sql (Day 2), C_advanced_aggregation.sql and D_views_functions_procedures_triggers.sql (Day 3), and E_optimisation_transactions.sql (Day 4).
- **images folder:** screenshots of the validation checks and query results.
- **README.md:** this file.

## The Database

The database has six main tables in the sokomart schema. Customers holds customer details such as county and status, while orders records each order's date, status, shipping county, delivery fee and total. The order_items table stores the product lines within each order, and products is the catalogue with category, unit price, cost price and stock. Payments tracks payment records and their status, and payment_staging holds incoming settlement data. Three further tables record history: product_price_history, order_status_history and audit_logs.

The SokoMart dataset was provided as part of the LuxDevHQ programme and is not included in this repository. Before any analysis, the loaded database was checked with a validation script covering record counts and data integrity. All 41 checks passed and none failed.

![Validation results](images/validation.png)

## The Revenue Rule

Every number in this project follows one rule: revenue is the sum of the order line totals for completed orders only. Delivery fees, and pending, cancelled and returned orders, are not revenue. Cost is quantity multiplied by cost price for the same lines, gross profit is revenue minus cost, and margin is gross profit divided by revenue. Date ranges are half-open (from the start date up to, but not including, the next day), because order dates include a time and BETWEEN would drop the last day.

## How to Run

1. Load the sokomart schema and its tables into a PostgreSQL database and run the validation script until every check passes.
2. Open the SQL files in DBeaver or psql. Each file starts with a line that sets the search path to sokomart, so it can be run from top to bottom.
3. Statements marked EXPECTED ERROR fail on purpose to demonstrate validation. Run those on their own.
4. From Day 3 onwards the scripts change data (prices, stock, orders and payments). To repeat the demonstrations, reset the database with the reset script and reload it first.

## Day 1: Subqueries and CTEs

Day 1 covers the core ways to ask a question inside a question. A scalar subquery compares each row with a value calculated on the spot, such as an average, so nothing is hard-coded. IN and EXISTS filter by another table, and EXISTS suits yes-or-no checks because it stops at the first match. A correlated subquery reruns for each row, a derived table summarises a subquery placed in FROM, and a CTE gives each step of a long query a readable name. NOT EXISTS finds records with no match, and it is safer than NOT IN, which returns nothing if a NULL appears.

### Practice drills

The ten drills start with subqueries that filter products above the average price, Mombasa customers who ordered in December 2025 and Kisumu customers with a failed payment. They continue with a derived table of per-order figures, CTEs for the top shipping counties and for monthly order counts compared with the average, and then introduce database programming: a function that returns a customer's order count, a stored procedure that validates a status change and is tested safely with a rollback, and a procedure with output parameters that returns a county summary.

Selected results: the average product price is about 12,117, and 65 products are priced above it. The most expensive is the Samsung Smart TV 65" at 113,700, and the ten most expensive products are all Electronics or Home Appliances. In December 2025, 204 Mombasa customers placed an order, and 155 Kisumu customers had at least one failed payment. Nairobi leads completed orders in 2026 with 7,774, ahead of Kiambu with 2,532 and Mombasa with 2,100.

![D1 top 10 products](images/d1_top10.png)

![D1 product count](images/d1_count.png)

![D2 results](images/d2.png)

![D3 results](images/d3.png)

### Q1: Big Spenders of 2025

Finds customers whose 2025 completed spend was above the average spend of customers who bought in 2025, using a CTE and a scalar subquery over it.

![Q1 results](images/q1.png)

**Findings:** 4,358 customers bought in 2025, and the average spend was about 118,800. 1,432 customers were above average. The top spender, Tabitha Njeru from Nairobi, spent about 2.0 million, nearly 17 times the average, and five of the ten biggest spenders live in Nairobi.

### Q2: Premium-Priced Products

Lists active products priced above the average of their own category, using a correlated subquery.

![Q2 results](images/q2.png)

**Findings:** 104 active products are priced above their category average. In Beauty, where the average is about 1,244, the biggest gaps belong to Nairobi Musk Perfume 100ml and Savanna Scents Perfume 100ml. In Electronics, where the average is about 33,130, the premium items include the Samsung Smart TV 65", the Lenovo Laptop Core i5 16GB and the LG Smart TV 65".

### Q3: 2026 Monthly Profit and Loss

Builds a monthly profit and loss for January to October 2026 from chained CTEs, with a generated calendar so months without sales still appear.

![Q3 results](images/q3.png)

**Findings:** Every month had completed sales. January was the strongest month, with revenue of about 57.8 million and gross profit of about 11.1 million, followed closely by August. February was the weakest. Margins stayed between 17.97 percent in June and 19.65 percent in May, so changes in profit came mainly from sales volume. Over the ten months, revenue was about 457.0 million at an 18.6 percent margin.

### Q4: Cross-Category Shoppers in Nakuru

Identifies Nakuru customers who bought from three or more product categories, using a derived table and COUNT(DISTINCT).

![Q4 results](images/q4.png)

**Findings:** 346 Nakuru customers bought from three or more categories, and 196 of them bought from all five. Nancy Githinji led with about 2.33 million in total spend.

### Q5: Products Nobody Has Ordered

Lists products that have never appeared on any order, using NOT EXISTS.

![Q5 results](images/q5.png)

**Findings:** 18 products have never been ordered. The active ones were all added in October 2026, so they are new listings that have not had time to sell. The rest are out of stock or discontinued, with zero stock.

## Day 2: Window Functions

A window function calculates across related rows but keeps every row, unlike GROUP BY, which collapses them. PARTITION BY defines the groups, ORDER BY sets the order within each group, and a frame sets which rows are included in a running calculation. Because a window function cannot be used in WHERE, the questions rank inside a CTE and filter in the outer query.

**Q6: County leaderboards.** DENSE_RANK finds the top three customers by lifetime revenue within each county, with tied customers sharing a rank. This returns 42 rows, three for each of the 14 counties. For example, the top Embu customer is Mwangi Kitonga, with about 2.2 million.

**Q7: Best sellers per category, 2025.** ROW_NUMBER picks the top three products in each category, breaking ties by product ID so every product gets a unique position. The leaders are the HP Laptop Core i5 16GB in Electronics (about 32.2 million), the Ramtons Gas Cooker 4 Burner in Home Appliances (about 14.1 million), the Afro Glow Hair Braids Long Value Pack in Beauty, Urban Kenya Jeans Skinny in Fashion and Kilele Ground Coffee 500g Value Pack in Groceries.

**Q8: Month-over-month growth.** LAG brings in the previous month's revenue, and NULLIF protects the growth calculation from division by zero. The first month has no previous month, so its growth is NULL. The biggest jumps were November 2025 (+70.7 percent) and August 2026 (+48.6 percent), and January and February fall back each year.

**Q9: Is each order bigger than the last?** For Nyeri customers in 2026, LAG partitioned by customer compares each completed order with that customer's previous one. Across 393 orders from 124 customers, 132 orders were bigger than the previous one and 137 were smaller, so spending per order was roughly flat.

**Q10: Year-to-date revenue.** Two running totals with an explicit frame: one restarts each January by partitioning on year, and one never resets. Completed revenue for 2025 was about 517.6 million, and the all-time total reached about 974.6 million by October 2026.

## Day 3: Advanced Aggregation and Database Objects

### Advanced aggregation (Section C)

**Q11: Customer tiers.** Nested derived tables and a CASE expression group customers into Platinum, Gold, Silver and Bronze by lifetime revenue, and a scalar subquery gives each tier's share of total revenue. There are 111 Platinum customers (17.6 percent of revenue), 279 Gold (19.3), 2,362 Silver (54.5) and 1,823 Bronze (8.6).

**Q12: What did Mombasa buy in October?** STRING_AGG with EXISTS builds a one-line shopping list per Mombasa customer. 152 customers qualify.

**Q13: Payment health by method, 2026.** COUNT with FILTER counts successful, failed and pending payments in a single pass. Of 23,817 payments in 2026, 2,201 failed (9.2 percent, worth about 49.7 million). Every method succeeds between 89 and 90 percent of the time, so no single channel is to blame.

**Q14: Which departments carry the profit?** A CTE and scalar subqueries find categories whose 2025 gross profit is above the average category. Electronics and Fashion qualify.

**Q15: One sales table with subtotals.** GROUPING SETS and GROUPING return county by category rows, county totals, category totals and a grand total in one query. It produces 36 rows, with a grand total of about 315.8 million from 13,733 orders in five counties.

### Views, functions, procedures and triggers (Section D)

**Q16: Views.** A view gives one row for every customer, including 425 of the 5,000 who never completed an order. A materialized view stores monthly sales by category for fast dashboards, with a unique index so it can be refreshed without blocking readers.

**Q17: Function.** A customer-spend function takes a customer and a date range, returns zero when there is nothing, and raises an error when the end date is before the start date. It matches the lifetime spend in the customer view.

**Q18: Price-change procedure.** The procedure locks the product row, rejects a price at or below zero or below cost, then updates the price and writes to the price history and the audit log together. Setting product 71 to 1,099 works, and a price of 500 is rejected because the cost is 974.21.

**Q19: Trigger and status procedure.** A trigger logs every order status change to the history and audit tables, and a procedure only allows pending to completed, pending to cancelled and completed to returned. Completing an order marks its payment successful. An update that does not touch the status writes no history row, and a cancelled order cannot be completed.

**Q20: Placing an order atomically.** One procedure validates the customer, takes stock with a conditional update, adds the order lines, sets the delivery fee, creates a pending payment and returns the new order number. If any step fails, everything is undone. When product 59 had only one unit, the failed order left no order and no stock change behind.

## Day 4: Optimisation, Transactions and Business Insights

### Q21: Reading a query plan

EXPLAIN with ANALYZE and BUFFERS shows how PostgreSQL really executed the Kisumu dashboard query. The plan was read for its top node, the join methods, the scan types on each table, the gap between estimated and actual row counts, and the planning and execution times. A sequential scan is not always bad: on a small table, reading everything can be cheaper than using an index.

### Q22: Proving the indexes help

The secondary indexes were dropped, the plans for three common lookups were recorded, the indexes were recreated and the plans were recorded again. Without indexes each lookup was a sequential scan of the whole table. With them, PostgreSQL jumps straight to the matching rows, and each query runs faster. PostgreSQL does not index foreign key columns automatically, and most of the indexes are exactly those join columns. A partial index covering only pending orders is also a fraction of the size of the full order date index, because it stores far fewer rows.

### Q23: Transactions

Transactions make a group of changes all-or-nothing. A 10 percent Beauty price cut was tried and rolled back, taking the average Beauty price from 1,243.84 to 1,119.46 inside the transaction and back to 1,243.84. A savepoint then undid one mistake while keeping a restock of product 59, which rose from 1 to 41 units. Finally, a failed statement aborted the whole transaction: the COMMIT reported a rollback, and the stock stayed unchanged.

### Q24: Cleaning up duplicate payments

Settlement files sent more than once left duplicates in the staging table. 200 payments were duplicated, with up to three copies each, giving 240 extra rows out of 2,640. ROW_NUMBER numbered the identical rows in load order, and the extra copies were deleted inside a transaction, leaving 2,400 rows for 2,400 distinct payments. The staged amount of about 60.2 million matches the same payments in the payments table. A unique index on the payment ID now makes re-inserting a payment fail.

### Q25: Three months in a row

A gaps-and-islands query finds customers with completed orders in at least three consecutive months. Subtracting a row number from a running month count gives the same value for months that follow each other, and each value marks one streak. 1,459 customers had a streak of three or more months, and the longest streak in the data is 22 months, from January 2025 to October 2026, achieved by at least ten customers.

## Business Insights and Recommendations

The overall picture: SokoMart is growing quickly, but its growth and profit rest on a narrow base, and money leaks at checkout.

1. **Growth is strong.** Revenue from January to October 2026 was about 457.0 million, against 378.4 million in the same months of 2025, an increase of 20.8 percent. Recommendation: plan stock and marketing around the peaks in November, December and August, where month-over-month growth reached 70.7 and 48.6 percent, and prepare for the January and February dip.

2. **Sales and profit come from different departments.** Electronics gives 62.9 percent of 2025 revenue but only a 13.4 percent margin. Fashion and Beauty give 14.4 percent of revenue but 34.9 percent of gross profit, with margins of 44.5 and 40.3 percent. Recommendation: promote Fashion and Beauty, for example in bundles, to lift profit without relying on low-margin Electronics.

3. **Revenue leans on one city and a few customers.** Nairobi accounts for about 39 percent of 2026 revenue, far ahead of Kiambu. Platinum and Gold customers are about 8.5 percent of buyers but bring 36.9 percent of revenue. Recommendation: reward the top tiers with a loyalty programme, and grow demand in the other counties.

4. **Checkout leaks money.** 9.2 percent of 2026 payments failed, worth about 49.7 million, and every payment method fails at a similar rate, which points to a shared cause. Recommendation: investigate the checkout and payment flow, and add retries and payment reminders.

5. **About 15 percent of orders end cancelled or returned.** None of that is revenue. Recommendation: review the reasons for cancellations and returns, starting with the highest-value categories.

6. **Settlement data contained duplicates.** 240 of 2,640 staging rows (9.1 percent) were repeats, which would have double-counted payments. Recommendation: keep the unique index on the payment ID, and check each settlement file for duplicates before loading it.

7. **A habit of repeat buying already exists.** 1,459 customers, about 32 percent of everyone who has bought, ordered in three or more consecutive months, and some bought in every one of the 22 months. Recommendation: target this group first with the planned subscription offer.

8. **There is untapped demand.** 425 of 5,000 customers (8.5 percent) never completed an order, and 18 products were never ordered, either new listings or discontinued and out-of-stock items. Recommendation: run an activation campaign for the 425 registered customers, and review the 18 products, retiring the discontinued ones.

## Key Skills Gained

- Breaking a business question into clear, reusable query steps
- Choosing between subqueries, CTEs and window functions
- Building views, functions, stored procedures and triggers with validation and error handling
- Keeping data safe with transactions, savepoints and rollbacks
- Reading query plans and proving that an index helps
- Turning query results into business findings and recommendations



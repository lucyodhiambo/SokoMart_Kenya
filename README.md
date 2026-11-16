# SokoMart_Kenya
 A Kenyan e-commerce database online shop selling electronics, groceries, fashion, home appliances and beauty products across Kenya.


## Overview

The goal of this project is to answer real business questions from relational data using advanced SQL: subqueries, CTEs, window functions, user-defined functions and stored procedures. The queries look at customers, products, orders and payments to find top spenders, price patterns, monthly profit and unsold stock.

## Tech Stack

- **Database:** PostgreSQL
- **Language:** SQL and PL/pgSQL
- **Schema:** sokomart

## Database Tables

The project uses six tables in the sokomart schema. The customers table holds customer details such as county and account status, while orders records each order's date, status, shipping county and total amount. The order_items table stores the individual product lines within each order, and products is the catalogue, with category, unit price, cost price and stock levels. Payments tracks payment records and their status, and payment_staging holds incoming payment data.

The SokoMart dataset was provided as part of the LuxDevHQ programme and is not included in this repository.

## Data Validation

Before running the analysis, the loaded database was checked with a validation script that covers record counts and data integrity. All 41 checks passed and none failed, which confirms the dataset was loaded correctly.

![Validation results](images/validation.png)

## SQL Concepts Demonstrated

- Scalar, correlated and derived-table subqueries
- IN, EXISTS and NOT EXISTS filtering
- Common Table Expressions (CTEs), including multi-step CTEs
- Window functions (AVG() OVER ())
- Joins (JOIN, LEFT JOIN, USING)
- Aggregation and date functions (DATE_TRUNC, TO_CHAR, GENERATE_SERIES)
- Conditional logic with CASE and null handling with COALESCE and NULLIF
- User-defined functions
- Stored procedures with input and output parameters, validation and error handling (RAISE EXCEPTION)
- Transaction control (BEGIN, ROLLBACK)

## Part 1: Practice Drills

The ten drills build core skills step by step. The first ones use subqueries to answer filtering questions, such as finding products priced above the average, Mombasa customers who ordered in December 2025, and Kisumu customers with failed payments. The next drills summarise orders by status, rank the top shipping counties for completed orders in 2026 using a CTE, and compare monthly completed orders in 2025 against the monthly average using a window function and a CASE expression.

The remaining drills move into database programming. They include a function that returns the number of orders a customer has placed, and a stored procedure that validates and updates a customer's status, raising clear errors for invalid input and tested safely inside a transaction with a rollback. There is also a query on Beauty products with below-average stock, and a stored procedure with output parameters that returns the number of customers and the completed revenue for a county.

### Selected Drill Results

**D1: Products above the average price.** The overall average unit price is about 12,117, and 65 products are priced above it. The most expensive is the Samsung Smart TV 65" at 113,700, followed by the Lenovo Laptop Core i5 16GB and the LG Smart TV 65". The ten most expensive products all come from Electronics and Home Appliances.

![D1 top 10 products](images/d1_top10.png)

![D1 product count](images/d1_count.png)

**D2: Mombasa customers who ordered in December 2025.** 199 Mombasa customers placed at least one order in December 2025.

![D2 results](images/d2.png)

**D3: Kisumu customers with failed payments.** 155 Kisumu customers had at least one order with a failed payment.

![D3 results](images/d3.png)

## Part 2: Business Questions

### Q1: Big Spenders of 2025

Finds customers whose total completed-order spend in 2025 was above the average spend per customer, showing how far above average each one is.

**Concepts:** CTE, scalar subqueries, joins, aggregation.

![Q1 results](images/q1.png)

**Findings:** The average completed spend per customer in 2025 was about 119,300. The top spender, Tabitha Njeru from Nairobi, spent about 2.0 million, nearly 17 times the average, and five of the ten biggest spenders live in Nairobi.

### Q2: Premium-Priced Products

Lists active products priced above the average price of their own category, with the price gap for each.

**Concepts:** Correlated subqueries.

![Q2 results](images/q2.png)

**Findings:** 104 active products are priced above the average of their own category. In Beauty, where the average is about 1,244, the biggest gaps belong to Nairobi Musk Perfume 100ml (6,500) and Savanna Scents Perfume 100ml (5,800). In Electronics, where the average is about 33,130, the premium items include the Samsung Smart TV 65" (113,700), the Lenovo Laptop Core i5 16GB (102,850) and the LG Smart TV 65" (102,749).

### Q3: 2026 Monthly Profit and Loss

Calculates monthly revenue, cost, gross profit and margin percentage for completed orders from January to October 2026. A generated calendar of months makes sure months with no sales still appear.

**Concepts:** Multi-step CTEs, GENERATE_SERIES, LEFT JOIN, COALESCE, NULLIF.

![Q3 results](images/q3.png)

**Findings:** Every month from January to October 2026 had completed sales. January had the highest revenue (about 57.8 million) and the highest gross profit (about 11.1 million), followed closely by August (about 57.6 million revenue and 10.8 million profit). February was the weakest month, with revenue of about 37.8 million and gross profit of about 6.8 million. Margins stayed in a narrow range, from 17.97 percent in June to 19.65 percent in May, which suggests that changes in profit came mainly from sales volume and not from changes in margin.

### Q4: Cross-Category Shoppers in Nakuru

Identifies Nakuru customers who bought from three or more product categories, ranked by number of categories and total spend.

**Concepts:** Derived table, COUNT(DISTINCT), multi-table joins.

![Q4 results](images/q4.png)

**Findings:** The top Nakuru shoppers each bought from five different product categories. Nancy Githinji led with total spend of about 2.33 million, followed by Carolyne Juma at about 2.30 million and Washington Hillow at about 1.72 million.

### Q5: Products Nobody Has Ordered

Lists products that have never appeared in any order, useful for spotting slow-moving or unsold stock.

**Concepts:** NOT EXISTS.

![Q5 results](images/q5.png)

**Findings:** 18 products have never been ordered. Among the products shown in the results, those with an active status were all added in October 2026, so they are new listings that have not had time to sell. The rest are marked out of stock or discontinued, with zero stock. These products are good candidates for review, such as retiring discontinued items from the catalogue.

## Repository Contents

- The SQL script containing three practice drills and the five business questions
- An images folder with screenshots of the validation checks and the query results for D1 to D3 and Q1 to Q5

## How to Run

1. Make sure the sokomart schema and its tables are loaded in your PostgreSQL database.
2. Open the SQL script in a client such as pgAdmin, DBeaver or psql.
3. The script starts with SET search_path TO sokomart, public;, so it can be run from both schemas.
4. Run each query on its own to see its result. The functions and procedures are created with CREATE OR REPLACE, so they can be re-run safely.

## Key Skills Gained

- Breaking a business question into clear, reusable query steps
- Choosing between subqueries and CTEs for readability
- Validating data and handling errors inside stored procedures
- Testing changes safely with transactions and ROLLBACK
- Reading query results to draw practical business findings


**Lucy Odhiambo**
Data Engineering trainee at LuxDevHQ | SQL | Power BI | Linux
GitHub: [github.com/lucyodhiambo](https://github.com/lucyodhiambo)

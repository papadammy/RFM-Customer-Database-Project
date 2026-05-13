CREATE DATABASE rfm_customer;
USE rfm_customer;

CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);


CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);


CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),

    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);


CREATE TABLE order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2),

    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);


SELECT * FROM customers LIMIT 10;


SELECT COUNT(DISTINCT customer_unique_id) FROM customers;

SELECT customer_unique_id, COUNT(*) AS num_orders
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY num_orders DESC;


/** PHASE 2  **/

SELECT * FROM orders LIMIT 1;
SELECT * FROM customers LIMIT 1;
SELECT * FROM order_payments LIMIT 1;

SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM order_payments;


SELECT COUNT(order_id) FROM
  (SELECT COUNT(*) AS payments_count, order_id 
	FROM order_payments
    GROUP BY order_id) AS aggr_order_count
;



SELECT COUNT(order_id) AS total_order_count 
FROM orders; 

SELECT COUNT(DISTINCT customer_unique_id) AS total_unique_customers
FROM customers;

SELECT MIN(order_purchase_timestamp) AS lower_date_range,
	MAX(order_purchase_timestamp) AS upper_date_range
FROM orders; 


SELECT
    SUM(customer_id IS NULL) AS customer_id_nulls,
    SUM(customer_unique_id IS NULL) AS unique_id_nulls
FROM customers;   

SELECT
    SUM(order_id IS NULL) AS order_id_nulls,
    SUM(customer_id IS NULL) AS customer_id_nulls
FROM orders;


SELECT
    SUM(order_id IS NULL) AS order_id_nulls,
    SUM(order_item_id IS NULL) AS order_item_id_nulls
FROM order_items;

SELECT
    SUM(order_id IS NULL) AS order_id_nulls,
    SUM(payment_sequential IS NULL) AS payment_seq_nulls
FROM order_payments;


SELECT COUNT(*)
FROM customers
WHERE customer_id IS NULL OR customer_id = '';


SELECT COUNT(*)
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

/** If > 0 → you have orphan records (bad data) **/


/** Phase 3: Building Analytical Dataset (SQL Extraction) **/

CREATE OR REPLACE VIEW payment_summary AS
SELECT
    order_id,
    SUM(payment_value) AS total_payment
FROM order_payments
GROUP BY order_id;


CREATE TABLE customer_transactions AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    DATE(o.order_purchase_timestamp) AS order_date,
    p.total_payment AS payment_value
FROM customers c
JOIN orders o 
    ON c.customer_id = o.customer_id
JOIN payment_summary p 
    ON o.order_id = p.order_id;
    
SELECT * FROM customer_transactions LIMIT 1;

DROP TABLE customer_rfm_base, customer_rfm_base2, customer_rfm_base3, customer_rfm_base4;

CREATE TABLE customer_rfm_base AS
SELECT
    customer_unique_id,
    MAX(order_date) AS last_purchase_date,
    DATEDIFF((SELECT MAX(order_date) FROM customer_transactions), MAX(order_date)) AS recency_days,
    COUNT(order_id) AS total_orders,
    SUM(payment_value) AS total_spent
FROM customer_transactions
GROUP BY customer_unique_id;

SELECT * FROM customer_rfm_base LIMIT 20;

CREATE TABLE customer_rfm_scores AS
SELECT 
	customer_unique_id,
	
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY total_orders) AS f_score,
    NTILE(5) OVER (ORDER BY total_spent) AS m_score
FROM customer_rfm_base;

SELECT * FROM customer_rfm_scores LIMIT 100;


CREATE OR REPLACE VIEW rfm_final AS
SELECT
    customer_unique_id,
	r_score,
    f_score,
    m_score,

    CONCAT(r_score, f_score, m_score) AS rfm_score

FROM customer_rfm_scores;


CREATE TABLE customer_segments AS
SELECT
    customer_unique_id,
    CASE
        -- 1. Champions
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 
            THEN 'Champions'

        -- 2. Loyal Customers
        WHEN f_score >= 4 AND m_score >= 3 
            THEN 'Loyal Customers'

        -- 3. Big Spenders
        WHEN m_score >= 4 AND f_score <= 3 
            THEN 'Big Spenders'

        -- 4. Frequent Low Spenders
        WHEN f_score >= 4 AND m_score <= 2 
            THEN 'Frequent Low Spenders'

        -- 5. Potential Loyalists
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 
            THEN 'Potential Loyalists'

        -- 6. At Risk
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 
            THEN 'At Risk'

        -- 7. New Customers
        WHEN r_score >= 4 AND f_score <= 2 
            THEN 'New Customers'

        -- 8. Lost Customers
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 
            THEN 'Lost Customers'

        -- 9. Everything else
        ELSE 'Needs Attention'
    END AS segment_label

FROM rfm_final;

SELECT * FROM customer_rfm_scores LIMIT 30;

DROP TABLE customer_rfm_scores2;


SELECT
    CASE
        WHEN frequency = 1 THEN '1 Purchase'
        WHEN frequency BETWEEN 2 AND 5 THEN '2-5 Purchases'
        WHEN frequency BETWEEN 6 AND 10 THEN '6-10 Purchases'
        ELSE '10+ Purchases'
    END AS purchase_group,
    COUNT(*) AS num_customers
FROM (
    SELECT
        customer_unique_id,
        COUNT(order_id) AS frequency
    FROM customer_transactions
    GROUP BY customer_unique_id
) t
GROUP BY purchase_group;



SELECT
    customer_unique_id,
    r_score,
    f_score,
    m_score,

    CASE
        -- Previously valuable but now inactive
        WHEN r_score <= 2 
             AND (f_score >= 4 OR m_score >= 4)
        THEN 'High-Value At Risk'

        -- Inactive across the board
        WHEN r_score <= 2 
             AND f_score <= 2 
             AND m_score <= 2
        THEN 'Lost Customers'

        -- Moderately inactive
        WHEN r_score <= 2
        THEN 'At Risk'

        -- Strong active customers
        WHEN r_score >= 4 
             AND f_score >= 4 
             AND m_score >= 4
        THEN 'Champions'

        ELSE 'Active'
    END AS risk_segment

FROM customer_rfm_scores;



SELECT
    CASE
        -- Previously valuable but now inactive
        WHEN r_score <= 2 
             AND (f_score >= 4 OR m_score >= 4)
        THEN 'High-Value At Risk'

        -- Inactive across the board
        WHEN r_score <= 2 
             AND f_score <= 2 
             AND m_score <= 2
        THEN 'Lost Customers'

        -- Moderately inactive
        WHEN r_score <= 2
        THEN 'At Risk'

        -- Strong active customers
        WHEN r_score >= 4 
             AND f_score >= 4 
             AND m_score >= 4
        THEN 'Champions'

        ELSE 'Active'
    END AS risk_segment,

    COUNT(customer_unique_id) AS customer_count

FROM customer_rfm_scores
GROUP BY risk_segment
ORDER BY customer_count DESC;



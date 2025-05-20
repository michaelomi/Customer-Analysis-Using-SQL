

-- SEGMENTATION ANALYSIS
-- Total users by age, gender, traffic source, and country.
SELECT age_group, 
    FORMAT(COUNT(id) * 1.0 / total.total_users, 'P') AS percentage_of_total,
    ROUND(AVG(age), 2) AS avg_age
FROM (
      SELECT id, age,
             CASE
                 WHEN age BETWEEN 12 AND 25 THEN 'Young (12 - 25)'
                 WHEN age BETWEEN 26 AND 48 THEN 'Middle (26 - 48)'
                 WHEN age BETWEEN 49 AND 70 THEN 'Old (49 - 70)'
                 ELSE 'Age out of range'
             END AS age_group
      FROM users
      ) A,
( SELECT COUNT(*) AS total_users 
  FROM users) total
GROUP BY age_group, total.total_users;
/*Middle (26 - 48)	38.78%	37
Old (49 - 70)	37.48%	59
Young (12 - 25)	23.74%	18
*/

-- Monthly Customer Retention and Churn Analysis by Cohort
WITH first_purchase AS (
    SELECT user_id, MIN(created_at) first_buy
    FROM orders
    GROUP BY user_id
),
cohort_analysis AS (
    SELECT DATEDIFF(MONTH, A.first_buy, B.created_at) AS period,
           COUNT(DISTINCT B.user_id) AS total_repurchase
    FROM first_purchase A
    INNER JOIN orders B
    ON A.user_id = B.user_id
    AND B.created_at >= A.first_buy
    GROUP BY DATEDIFF(MONTH, A.first_buy, B.created_at)
)
SELECT period,
       FORMAT(total_repurchase * 1.0 / FIRST_VALUE(total_repurchase) OVER(ORDER BY period), 'P') AS pct_retention,
       FORMAT(1 - total_repurchase * 1.0 / FIRST_VALUE(total_repurchase) OVER(ORDER BY period), 'P') AS pct_churn
FROM cohort_analysis;
/*0	100.00%	0.00%
1	4.76%	95.24%
2	3.84%	96.16%
3	3.28%	96.72%
4	3.00%	97.00%
5	2.76%	97.24%
6	2.46%	97.54%
7	2.17%	97.83%
8	2.05%	97.95%
9	1.93%	98.07%
10	1.78%	98.22%
11	1.53%	98.47%
12	1.52%	98.48%
13	1.41%	98.59%
14	1.30%	98.70%
15	1.21%	98.79%
16	1.14%	98.86%
17	1.04%	98.96%
18	0.98%	99.02%
19	0.88%	99.12%
20	0.85%	99.15%
21	0.82%	99.18%
22	0.74%	99.26%
23	0.69%	99.31%
24	0.66%	99.34%
*/


-- Repeat Purchases: Percentage of Customers who placed more than n orders
DECLARE @order_number INT;
SET @order_number = 1;

WITH customer_orders AS (
  SELECT 
    user_id, 
    COUNT(DISTINCT order_id) AS total_orders
  FROM orders
  GROUP BY user_id
)
SELECT
  COUNT(CASE WHEN total_orders > @order_number THEN 1 END) AS repeat_customers,
  COUNT(*) AS total_customers,
  FORMAT(1.0 *
  COUNT(CASE WHEN total_orders > @order_number THEN 1 END) / COUNT(*), 'P') AS customer_retention_rate
FROM customer_orders;
/* repeat_customers	total_customers	customer_retention_rate
30212	80044	37.74%
*/


-- CUSTOMER LIFETIME VALUE
WITH profit_per_order AS (SELECT 
    A.user_id,
    A.order_id,
    MONTH(A.created_at) AS month,
    ((C.retail_price * A.num_of_item) - (C.cost * A.num_of_item)) AS profit
  FROM orders A
  JOIN order_items B ON A.order_id = B.order_id AND A.status = 'Complete'
  JOIN products C ON B.product_id = C.id),

monthly_user_profit AS (
  SELECT 
    user_id,
    month,
    SUM(profit) AS total_monthly_profit
  FROM profit_per_order
  GROUP BY user_id, month),

average_monthly_profit AS (
  SELECT 
    user_id,
    ROUND(AVG(total_monthly_profit),2) AS avg_monthly_profit
  FROM monthly_user_profit
  GROUP BY user_id),

user_lifetime AS (
  SELECT 
  user_id,
  COUNT(month) AS lifetime_months
FROM monthly_user_profit
GROUP BY user_id)

SELECT 
  P.user_id,
  P.avg_monthly_profit,
  U.lifetime_months,
  ROUND((P.avg_monthly_profit * U.lifetime_months),2) AS cltv
FROM average_monthly_profit P
JOIN user_lifetime U ON P.user_id = U.user_id
ORDER BY lifetime_months DESC, cltv DESC;
/*
user_id	avg_monthly_profit	lifetime_months	cltv
54072	98.79	4	395.16
95822	73.07	4	292.28
49167	72.8	4	291.2
51001	37.15	4	148.6
49942	28.2	4	112.8
79961	13.84	4	55.36
85129	662.15	3	1986.45
77184	591.62	3	1774.86
87549	511.14	3	1533.42
82529	405.01	3	1215.03
23628	382.59	3	1147.77
4739	273.6	3	820.8
88548	272.85	3	818.55
96416	268.53	3	805.59
21221	266.21	3	798.63
5604	252.7	3	758.1
94169	248.18	3	744.54
78296	241.96	3	725.88
89275	227.96	3	683.88
13899	217.78	3	653.34
*/


-- RFM Analysis:
-- Segment customers into groups based on Recency, Frequency, and Monetary value using a scoring system.
WITH rfm_table AS(
SELECT
    user_id, 
    -- Concatenating Recency, Frequency, and Monetary scores into a single RFM score
    CONCAT(
        -- Recency Score
        CASE 
            WHEN DATEDIFF(DAY, MAX(delivered_at), (SELECT DATEADD(DAY, 1, MAX(delivered_at)) FROM order_items)) <= 458 THEN 1
            WHEN DATEDIFF(DAY, MAX(delivered_at), (SELECT DATEADD(DAY, 1, MAX(delivered_at)) FROM order_items)) <= 916 THEN 2
            WHEN DATEDIFF(DAY, MAX(delivered_at), (SELECT DATEADD(DAY, 1, MAX(delivered_at)) FROM order_items)) <= 1375 THEN 3
            ELSE 4
        END,
        -- Frequency Score
        CASE 
            WHEN COUNT(sale_price) <= 3 THEN 1
            WHEN COUNT(sale_price) <= 5 THEN 2
            WHEN COUNT(sale_price) <= 7 THEN 3
            ELSE 4
        END,
        -- Monetary Score
        CASE 
            WHEN CAST(SUM(sale_price) AS DECIMAL(10, 2)) <= 328.14 THEN 1
            WHEN CAST(SUM(sale_price) AS DECIMAL(10, 2)) <= 656.28 THEN 2
            WHEN CAST(SUM(sale_price) AS DECIMAL(10, 2)) <= 984.43 THEN 3
            ELSE 4
        END
    ) AS rfm_score
FROM order_items
WHERE status = 'Complete'
GROUP BY user_id
)
SELECT user_id, rfm_score
FROM rfm_table
WHERE rfm_score LIKE '%3' OR rfm_score LIKE '%4'
ORDER BY rfm_score DESC;
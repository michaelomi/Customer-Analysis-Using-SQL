# E-Commerce Customer Analysis for Revenue Optimization 🚀

## Overview 📊
In the fast-paced world of e-commerce, understanding customer behavior is critical to driving revenue, reducing churn, and optimizing marketing spend. This SQL-based project analyzes customer data to deliver actionable insights that help businesses target high-value customers, boost retention, and increase profitability 💰. Through customer segmentation, retention analysis, repeat purchase trends, Customer Lifetime Value (CLTV), and RFM (Recency, Frequency, Monetary) scoring, the project uncovers opportunities to maximize revenue and improve ROI 📈.

## Business Value 💡
This project addresses key e-commerce challenges with data-driven solutions:
- **Increases Revenue** 💸: Identifies high-value customers (e.g., CLTV up to $38,965.77) for personalized offers, potentially boosting sales by 10-20% (industry benchmark).
- **Reduces Churn** 🛑: Highlights a 95.24% churn rate after month 1, guiding timely re-engagement campaigns to retain customers.
- **Optimizes Marketing** 🎯: Segments customers by age (e.g., 38.78% aged 26-48), traffic source, and country, focusing ad spend on high-ROI demographics.
- **Encourages Loyalty** 🤝: Reveals a 37.74% repeat purchase rate, informing loyalty programs to increase order frequency.

## Key Analyses 🔍
The project uses SQL to perform five core analyses, each tied to a specific business outcome. Below are the analyses, their purpose, and their impact.

### 👥 1. Customer Segmentation 
- **Purpose**: Groups customers by age, gender, traffic source, and country to identify high-value demographics.
- **Key Insight**: The 26-48 age group dominates (38.78% of users, avg. age 37), followed by 49-70 (37.48%, avg. age 59) and 12-25 (23.74%, avg. age 18).
- **Business Impact**: Enables targeted marketing campaigns (e.g., ads for 26-48-year-olds) to maximize conversions and reduce ad waste 📢.
- **SQL Approach**: Uses subqueries and CASE statements to categorize users and calculate percentages.
- **Example Query**:
  ```sql
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
  ```
  
### 📉 2. Retention and Churn Analysis
- ** Purpose:** Tracks customer retention by cohort to understand loyalty and churn patterns.
- ** Key Insight:** Retention drops sharply after the first month (**4.76% retention**, **95.24% churn**), stabilizing at ~1–2% after 12 months.
- ** Business Impact:** Highlights the need for early re-engagement strategies (e.g., email campaigns, discounts) to recover at-risk customers, potentially retaining **5–10% more users**.
- ** SQL Approach:** Uses **CTEs** and `DATEDIFF` to calculate retention and churn percentages by month.
- **Example Query**:
```sql
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
```

### 🔁 3. Repeat Purchase Analysis

- **Purpose**: Measures the percentage of customers placing multiple orders.
- **Key Insight**: 37.74% of customers (30,212 out of 80,044) place more than one order.
- **Business Impact**: Suggests untapped potential for loyalty programs or incentives to increase repeat purchases, driving additional revenue.
- **SQL Approach**: Uses a CTE to count orders per customer and a variable to flexibly analyze retention at different order thresholds.
- **Example Query**:
```sql
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
```

### 💸 4. Customer Lifetime Value (CLTV)
- **Purpose**: Estimates the total profit a customer generates over their lifetime.
- **Key Insight**: Top customers generate significant CLTV (e.g., user 36483: $38,965.77 over 57 months), while others vary widely (e.g., $436.70 to $9,736.10).
- **Business Impact**: Identifies high-value customers for VIP treatment (e.g., exclusive offers) and informs acquisition budgets by setting cost-per-customer targets.
- **SQL Approach**: Combines profit per order (retail price minus cost) with lifetime months using multiple CTEs for accurate CLTV calculations.
- **Example Query**:
``` sql
WITH profit_per_order AS (
    SELECT 
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
        DATEDIFF(MONTH, MIN(created_at), MAX(created_at)) + 1 AS lifetime_months
    FROM orders
    GROUP BY user_id)
SELECT 
    P.user_id,
    P.avg_monthly_profit,
    U.lifetime_months,
    ROUND((P.avg_monthly_profit * U.lifetime_months),2) AS cltv
FROM average_monthly_profit P
JOIN user_lifetime U ON P.user_id = U.user_id
ORDER BY lifetime_months DESC, cltv DESC;
```

### 🔍 5. RFM Analysis
- **Purpose**: Segments customers based on Recency (last purchase), Frequency (order count), and Monetary value (total spend).
- **Key Insight**: Customers with high RFM scores (e.g., containing 3 or 4) are loyal and high-spending, ideal for targeted campaigns.
- **Business Impact**: Prioritizes marketing efforts on high-value segments, improving conversion rates and revenue.
- **SQL Approach**: Uses CASE statements to assign scores (1-4) for each RFM dimension, concatenating them into a single score.
- **Example Query**:
``` sql
WITH rfm_table AS(
SELECT
    user_id, 
    CONCAT(
        CASE 
            WHEN DATEDIFF(DAY, MAX(delivered_at), (SELECT DATEADD(DAY, 1, MAX(delivered_at)) FROM order_items)) <= 458 THEN 1
            WHEN DATEDIFF(DAY, MAX(delivered_at), (SELECT DATEADD(DAY, 1, MAX(delivered_at)) FROM order_items)) <= 916 THEN 2
            WHEN DATEDIFF(DAY, MAX(delivered_at), (SELECT DATEADD(DAY, 1, MAX(delivered_at)) FROM order_items)) <= 1375 THEN 3
            ELSE 4
        END,
        CASE 
            WHEN COUNT(sale_price) <= 3 THEN 1
            WHEN COUNT(sale_price) <= 5 THEN 2
            WHEN COUNT(sale_price) <= 7 THEN 3
            ELSE 4
        END,
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
```

## 📊 Results and Impact
The insights from this project translate directly into measurable business outcomes:
- **💰 Revenue Growth:** Targeting high-CLTV and high-RFM customers with personalized offers can increase sales by **10–20%**.
- **🔄 Churn Reduction:** Addressing the **95% month-1 churn** with re-engagement campaigns could retain **5–10% more customers**, adding thousands in revenue.
- **🎯 Marketing Efficiency:** Focusing ad spend on the **26–48 age group** (👥 **38.78%** of users) reduces **cost-per-acquisition** by prioritizing high-conversion segments.
- **💎 Loyalty Programs:** Lifting the **37.74% repeat purchase rate** by **5%** through incentives could generate **significant additional orders**.

## 🛠️ Technologies Used
- **🖥️ SQL:** Microsoft SQL Server for querying and analysis.
- **🤖 AI:** ChatGPT for assistance.

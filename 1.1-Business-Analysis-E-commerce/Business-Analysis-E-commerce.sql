-- Basic Analytics
-- Q1. SKU Level sales month on month
SELECT DATE_FORMAT(FROM_UNIXTIME(`Order Date`), '%Y-%m') AS Month, `SKUID`, SUM(`Pairs`) AS TotalPairs
FROM `order_details`
GROUP BY `SKUID`, Month
ORDER BY Month, `SKUID`;

-- Q2. Most sold SKUs in maharashtra
SELECT `SKUID`, SUM(`Pairs`) AS TotalPairs
FROM `order_details`
INNER JOIN `Orders` ON `order_details`.`Orderid` = `Orders`.`Orderid`
INNER JOIN `Users` ON `Orders`.`Userid` = `Users`.`Userid`
WHERE `State` = 'maharashtra'
GROUP BY `SKUID`
ORDER BY TotalPairs DESC;


-- Q3. State with highest % of orders as COD orders
SELECT `State`, COUNT(*) AS TotalOrders, SUM(CASE WHEN `Payment Type` = 'COD' THEN 1 ELSE 0 END) AS CODOrders, (SUM(CASE WHEN `Payment Type` = 'COD' THEN 1 ELSE 0 END) / COUNT(*)) * 100 AS CODPercentage
FROM `Orders`
INNER JOIN `Users` ON `Orders`.`Userid` = `Users`.`Userid`
GROUP BY `State`
ORDER BY CODPercentage DESC
LIMIT 1;


-- Q4. Find the percentage of returns booked out of the total orders placed in the last 30 Days?
SELECT (COUNT(DISTINCT `Returns`.`orderId`) / COUNT(DISTINCT `Orders`.`Orderid`)) * 100 AS ReturnPercentage
FROM `Orders`
LEFT JOIN `Returns` ON `Orders`.`Orderid` = `Returns`.`orderId`
WHERE (`Orders`.`Order Date` >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY)))
AND (`Returns`.`ReturnBookedOn` >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY)) OR `Returns`.`ReturnBookedOn` IS NULL);


-- Q5. All churned buyers (Buyers who have not placed a order in the last 30 days)
SELECT U.Userid AS BuyerID, MAX(O.`Order Date`) AS LastOrderDate, MAX(O.`Delivery Date`) AS LastDeliveryDate
FROM Users U
LEFT JOIN 
Orders O ON U.Userid = O.Userid
WHERE (O.`Order Date` < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY)) OR O.`Order Date` IS NULL)
GROUP BY BuyerID;


-- Q6. Find the total Users who have received refunds of more than Rs.10000 in the last 30 days?
SELECT 
    U.Userid AS UserID, 
    COUNT(DISTINCT O.Orderid) AS TotalOrdersPlaced, 
    COUNT(DISTINCT R.DisputeId) AS TotalReturnsBooked, 
    MAX(R.BuyerRefundedOn) AS LastRefundDate, 
    SUM(R.RefundValue) AS TotalRefundValue, 
    SUM(CASE WHEN R.ReturnType=1 THEN 1 ELSE 0 END) AS TotalGenuineReturns, 
    SUM(CASE WHEN R.ReturnType=2 THEN 1 ELSE 0 END) AS TotalNonGenuineReturns
FROM  Users U
LEFT JOIN Orders O ON U.Userid = O.Userid
LEFT JOIN Returns R ON O.Orderid = R.orderId
WHERE R.BuyerRefundedOn >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY))
GROUP BY UserID
HAVING TotalRefundValue > 10000;


-- Q7. SKU with most returns bifurcated into Genuine and Non Genuine
SELECT SKUID, COUNT(*) as TotalReturns, SUM(CASE WHEN ReturnType=1 THEN 1 ELSE 0 END) as GenuineReturns, SUM(CASE WHEN ReturnType=2 THEN 1 ELSE 0 END) as NonGenuineReturns, (SUM(CASE WHEN ReturnType=1 THEN 1 ELSE 0 END) / COUNT(*)) * 100 as GenuineContribution, (SUM(CASE WHEN ReturnType=2 THEN 1 ELSE 0 END) / COUNT(*)) * 100 as NonGenuineContribution
FROM order_details
INNER JOIN Returns ON order_details.Orderid = Returns.orderId
GROUP BY SKUID
ORDER BY TotalReturns DESC;


-- Q8. Buyer level Recency, Frequency analysis: To be able to figure out the avg frequency at which a buyer purchases and when was the last
SELECT Users.Userid, COUNT(DISTINCT Orders.Orderid) as TotalOrders, MAX(Orders.Order Date) as LastOrderDate, AVG(Orders.Order Date - LAG(Orders.Order Date) OVER (PARTITION BY Users.Userid ORDER BY Orders.Order Date)) as AvgFrequency
FROM Users
INNER JOIN Orders ON Users.Userid = Orders.Userid
GROUP BY Users.Userid;

-- Advanced Analytics
-- Q.1 Bucketing users into Large, Medium and small. Size is derived based on the sales contribution of
-- the user at a platform level. Definitions: (In terms of order Value)
-- - Large: TOP 25% contributors
-- - Medium: Next 50%
-- - Small: Last 25%
-- Expected Outcome: UserID, % Contribution to the platform sales and Size-bucket
WITH user_sales AS (
  SELECT Userid, SUM(Order_Value) as Total_Sales
  FROM Orders
  GROUP BY Userid
),
sales_percentiles AS (
  SELECT 
    Userid, 
    Total_Sales,
    NTILE(4) OVER (ORDER BY Total_Sales DESC) as Sales_Percentile
  FROM user_sales
)
SELECT 
  Userid, 
  Total_Sales / (SELECT SUM(Total_Sales) FROM user_sales) * 100 as Sales_Contribution_Percentage,
  CASE 
    WHEN Sales_Percentile = 1 THEN 'Large'
    WHEN Sales_Percentile = 2 OR Sales_Percentile = 3 THEN 'Medium'
    ELSE 'Small'
  END as Size_Bucket
FROM sales_percentiles;

-- Q.2 Cohort Analysis
SELECT 
  DATE_FORMAT(FROM_UNIXTIME(Signup_Date), '%Y-%m') as Signup_Month,
  PERIOD_DIFF(DATE_FORMAT(FROM_UNIXTIME(Order_Date), '%Y%m'), DATE_FORMAT(FROM_UNIXTIME(Signup_Date), '%Y%m')) as Months_Since_Signup,
  COUNT(DISTINCT Userid) as User_Count
FROM Users JOIN Orders ON Users.Userid = Orders.Userid
WHERE Order_Date >= Signup_Date
GROUP BY Signup_Month, Months_Since_Signup;

-- Q3. A seller is considered to have breached SLA if the order placed and order ready time stamps are
-- greater than 3 days. Find out the top 10 percentile of sellers causing delays on a platform level.
-- Expected Outcome: Seller ID, contribution on platform, Delay % of seller
WITH seller_delays AS (
  SELECT 
    sellerID, 
    COUNT(*) as Total_Orders, 
    SUM(CASE WHEN Order_Ready_Date - Order_Date > 3 * 24 * 60 * 60 THEN 1 ELSE 0 END) as Delayed_Orders
  FROM Orders
  GROUP BY sellerID
),
seller_percentiles AS (
  SELECT 
    sellerID, 
    Total_Orders,
    Delayed_Orders,
    NTILE(10) OVER (ORDER BY Delayed_Orders DESC) as Delay_Percentile
  FROM seller_delays
)
SELECT 
  sellerID, 
  Total_Orders * 100.0 / (SELECT SUM(Total_Orders) FROM seller_delays) as Contribution_Percentage,
  Delayed_Orders * 100.0 / Total_Orders as Delay_Percentage
FROM seller_percentiles
WHERE Delay_Percentile = 1;

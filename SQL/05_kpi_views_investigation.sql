--Writting first queries for the project Day 14 log:

USE CheckoutIntelligence;

--First question , we need to know the entire revenue for all the dataset

SELECT * 
from Customers;

SELECT * 
FROM Products;

select *
FROM Transaction_Details;

select *
FROM Transactions;

--What is the total revenue across all the dataset?
-- line revenue = Quantity price 
-- Need to Join Transaction details with products because in this analysis the revenue line item is Quantity x Price:

SELECT SUM(td.quantity * p.UnitPrice) AS Total_Revenue
FROM Transaction_Details td
LEFT JOIN Products p
	ON td.StockCode = p.StockCode;
--Keep negative quantities = net revenue after returns; exclude negative quantities = gross sales before returns.

-- First query for the project net total revenue , adding a view to it;
GO

CREATE VIEW vw_TotalRevenue AS 
SELECT SUM(td.quantity * p.UnitPrice) AS Total_Revenue
FROM Transaction_Details td
INNER JOIN Products p
	ON td.StockCode = p.StockCode;

GO

SELECT * FROM vw_TotalRevenue;

--Day 15 KPIS Queries
-- Following the progress for previously calculating Total Revenue.

-- 2nd query to write
--Question: How many total transactions (invoices) are in the dataset?
--Think about whether that should include or exclude the "C"-prefixed cancelled invoices before writing it 
-- — what would an Ops Director actually want that number to mean?

-- Counting Total Transactions excluding cancelled 'C' transactions.

SELECT COUNT(t.InvoiceNo) AS Total_Transactions
FROM Transactions t
WHERE t.InvoiceNo NOT LIKE 'C%';

-- found a data quality issue , let's run the diagnostic:

SELECT InvoiceNo, COUNT(*) 
FROM Transactions
WHERE InvoiceNo NOT LIKE 'C%'
AND InvoiceNo NOT LIKE '[0-9]%'
GROUP BY InvoiceNo;

-- found other values that were not neccesarily just cancelled transactions that are woth looking at 

SELECT * FROM Staging_OnlineRetail WHERE InvoiceNo LIKE 'A%';

-- Found different stock codes in the analysis

SELECT * FROM Products WHERE StockCode = 'B';

-- Worth a look because we found an bad accounting entry that could be affecting our total_revenue 

SELECT SUM(td.Quantity * p.UnitPrice) AS BadDebt_Impact
FROM Transaction_Details td
JOIN Products p ON td.StockCode = p.StockCode
WHERE td.StockCode = 'B';

-- finding a deeper solution before contaminating the data
SELECT DISTINCT StockCode, Description
FROM Staging_OnlineRetail
WHERE StockCode IN ('B', 'D', 'DOT', 'M', 'POST', 'BANK CHARGES', 'AMAZONFEE', 'CRUK')
ORDER BY StockCode;

-- New stock codes found 

SELECT StockCode, DATALENGTH(StockCode) AS ByteLength, Description
FROM Products
WHERE StockCode IN ('DOT', 'POST');

---Purpose: Confirm whether DOT and POST genuinely appear twice in Products (which shouldn't be possible under a PRIMARY KEY) or if the earlier screenshot was a fluke.

SELECT StockCode, COUNT(*) 
FROM Products 
WHERE StockCode IN ('DOT', 'POST')
GROUP BY StockCode;

--Purpose: Get the clean, final list of all non-product administrative StockCodes sitting in your Products table, so we know exactly what to exclude.

SELECT StockCode, Description, UnitPrice
FROM Products
WHERE StockCode NOT LIKE '[0-9]%'
ORDER BY StockCode;

--Purpose: Confirm how many real transaction rows would actually 
-- be affected if we exclude only the genuinely administrative codes (not the DCGS/gift voucher products).

SELECT StockCode, COUNT(*) AS Row_Count
FROM Transaction_Details
WHERE StockCode IN ('AMAZONFEE', 'B', 'BANK CHARGES', 'C2', 'CRUK', 'D', 'DOT', 'M', 'POST', 'S')
GROUP BY StockCode
ORDER BY Row_Count DESC;

--Purpose: Create a reusable View that represents only genuine product StockCodes, excluding the known administrative/non-product codes.

CREATE VIEW vw_RealProducts AS
SELECT * FROM Products
WHERE StockCode NOT IN ('AMAZONFEE', 'B', 'BANK CHARGES', 'C2', 'CRUK', 'D', 'DOT', 'M', 'POST', 'S');

select * from vw_RealProducts;


--Purpose: Recalculate Total Revenue using only real products, correcting the $33,186.18 contamination from bad debt and other admin codes.

CREATE OR ALTER VIEW vw_TotalRevenue AS
SELECT SUM(td.Quantity * p.UnitPrice) AS Total_Revenue
FROM Transaction_Details td
JOIN vw_RealProducts p
	ON td.StockCode = p.StockCode;

select * from vw_TotalRevenue;

--Purpose: Calculate exactly how much the 10 excluded admin codes were contributing to revenue in total, 
--to confirm the new number moved in the right direction and by a reasonable amount.

SELECT SUM(td.Quantity * p.UnitPrice) AS Excluded_Codes_Impact
FROM Transaction_Details td
JOIN Products p ON td.StockCode = p.StockCode
WHERE p.StockCode IN ('AMAZONFEE', 'B', 'BANK CHARGES', 'C2', 'CRUK', 'D', 'DOT', 'M', 'POST', 'S');

--Purpose: Count total completed (non-cancelled) transactions, now that Transactions itself needs the same malformed-row awareness.

SELECT COUNT(t.InvoiceNo) AS Total_Transactions
FROM Transactions t 
WHERE t.InvoiceNo NOT LIKE 'C%' AND t.InvoiceNo NOT LIKE ', most o%';

-- Same version different syntax

SELECT COUNT(t.InvoiceNo) AS Total_Transactions
FROM Transactions t 
WHERE t.InvoiceNo NOT LIKE 'C%' 
AND t.InvoiceNo <> ', most o';

--Purpose: Save the corrected Number of Transactions logic as a reusable View.
CREATE VIEW vw_NumberOfTransactions AS
SELECT COUNT(t.InvoiceNo) AS Total_Transactions
FROM Transactions t 
WHERE t.InvoiceNo NOT LIKE 'C%' 
AND t.InvoiceNo <> ', most o';

SELECT * FROM vw_NumberOfTransactions;

--Calculating First: Average Revenue per Invoice
--Purpose: Calculate the average dollar value of a completed transaction.

WITH Invoices AS(
	SELECT InvoiceNo,
		   SUM(td.quantity * rp.UnitPrice) AS Invoice_Revenue
	FROM Transaction_Details td
	JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY InvoiceNo),
Avg_Revenue AS( 
	SELECT AVG(Invoice_Revenue) AS Average_Invoice_Revenue
	FROM Invoices)
SELECT Average_Invoice_Revenue
FROM Avg_Revenue;

--Save it as a View
--Purpose: Save Average Basket Revenue as a reusable View.

CREATE VIEW vw_AverageBasketRevenue AS
	WITH Invoices AS(
	SELECT InvoiceNo,
		   SUM(td.quantity * rp.UnitPrice) AS Invoice_Revenue
	FROM Transaction_Details td
	JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY InvoiceNo),
Avg_Revenue AS( 
	SELECT AVG(Invoice_Revenue) AS Average_Invoice_Revenue
	FROM Invoices)
SELECT Average_Invoice_Revenue
FROM Avg_Revenue;

SELECT * FROM vw_AverageBasketRevenue;

--Purpose: Find the median (total quantity) purchased per completed invoice.

WITH Invoice_Count AS (
	SELECT td.InvoiceNo,
		   SUM(td.quantity) AS Total_Items
	FROM Transaction_Details td
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY td.InvoiceNo),
Median_Count AS (
	SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Total_Items) OVER () AS Median
	FROM Invoice_Count)
SELECT DISTINCT Median
FROM Median_Count;

-- concept: PERCENTILE_CONT

--This function finds a value at a specific percentile within a group — the median is just the 50th percentile (0.5). Basic shape:


--Purpose: Calculate the average number of items across all completed (non-cancelled, non-malformed) invoices,
--by first summing quantity per invoice (CTE), then averaging those per-invoice totals — collapsing to a single overall number.

WITH Invoice_Count AS (
	SELECT td.InvoiceNo,
		   SUM(td.quantity) AS Total_Items
	FROM Transaction_Details td
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY td.InvoiceNo)
SELECT AVG(Total_Items) AS Average_Items_Per_Invoice
FROM Invoice_Count;

--Purpose: Sanity-check the item count by looking at a few individual invoices directly.

SELECT TOP 5 InvoiceNo, SUM(Quantity) AS Total_Items
FROM Transaction_Details
GROUP BY InvoiceNo
ORDER BY Total_Items DESC;

--Purpose: Save Average Items per Invoice as a reusable View (mean — skewed by outliers, see note).

CREATE VIEW vw_AverageItemsPerInvoice AS
WITH Invoice_Count AS (
	SELECT td.InvoiceNo,
		   SUM(td.quantity) AS Total_Items
	FROM Transaction_Details td
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY td.InvoiceNo)
SELECT AVG(Total_Items) AS Average_Items_Per_Invoice
FROM Invoice_Count;

--Purpose: Save Median Items per Invoice as a reusable View (more representative of a "typical" basket, resistant to wholesale-order outliers).

CREATE VIEW vw_MedianItemsPerInvoice AS
	WITH Invoice_Count AS (
	SELECT td.InvoiceNo,
		   SUM(td.quantity) AS Total_Items
	FROM Transaction_Details td
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY td.InvoiceNo),
Median_Count AS (
	SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Total_Items) OVER () AS Median
	FROM Invoice_Count)
SELECT DISTINCT Median
FROM Median_Count;


-- Sanity Check if views were correctly stored

select * from vw_AverageItemsPerInvoice;

select * from vw_MedianItemsPerInvoice;

--Revenue by Country
--Purpose: Show total net revenue broken down by customer country — 
--ties back to your Day 11 profiling note that most returns come from the UK, so this is a chance to actually verify that with real numbers.

SELECT c.Country,
	   SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
FROM Customers c 
INNER JOIN Transactions t
	ON c.CustomerID = t.CustomerID
INNER JOIN Transaction_Details td
	ON t.InvoiceNo = td.InvoiceNo
INNER JOIN vw_RealProducts rp
	ON td.StockCode = rp.StockCode
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
GROUP BY c.Country
ORDER BY Total_Revenue DESC;

--Purpose: Save Revenue by Country as a reusable View, documenting the anonymous-transaction exclusion decision.
-- Excludes anonymous (NULL CustomerID) transactions since they have no Country.
-- Total across all countries here will be LESS than vw_TotalRevenue for this reason.
-- See vw_TotalRevenue for full company-wide revenue including anonymous transactions.

CREATE VIEW vw_RevenueByCountry AS
	SELECT c.Country,
	   SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
FROM Customers c 
INNER JOIN Transactions t
	ON c.CustomerID = t.CustomerID
INNER JOIN Transaction_Details td
	ON t.InvoiceNo = td.InvoiceNo
INNER JOIN vw_RealProducts rp
	ON td.StockCode = rp.StockCode
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
GROUP BY c.Country;

select * from vw_RevenueByCountry order by Total_Revenue DESC;

--Purpose: Identify the top 10 products by total revenue

SELECT TOP 10
	   rp.StockCode ,
	   rp.Description,
	   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
FROM vw_RealProducts rp
JOIN Transaction_Details td
	ON rp.StockCode = td.StockCode
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
GROUP BY rp.StockCode , rp.Description
ORDER BY Total_Revenue DESC;

--Purpose: Save Top Selling Products as a reusable View
CREATE VIEW vw_ProductRevenue AS
	SELECT rp.StockCode ,
		   rp.Description,
	       SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
FROM vw_RealProducts rp
JOIN Transaction_Details td
	ON rp.StockCode = td.StockCode
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
GROUP BY rp.StockCode , rp.Description;

select top 10 * from vw_ProductRevenue order by Total_Revenue DESC;

--Average Revenue per Customer
--Question: What is the average total revenue per known (non-anonymous) customer?

WITH Customer_Revenue AS (
	SELECT c.CustomerID,
		   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
	FROM Customers c
	INNER JOIN Transactions t
		ON c.CustomerID = t.CustomerID
	INNER JOIN Transaction_Details td 
		ON t.InvoiceNo = td.InvoiceNo
	INNER JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY c.CustomerID),
Avg_Revenue AS(
	SELECT AVG(Total_Revenue) AS Average_Customer_Revenue
	FROM Customer_Revenue)
SELECT Average_Customer_Revenue
FROM Avg_Revenue;

-- Purpose: Save Average Revenue per Customer, documenting the same anonymous-exclusion decision as Revenue by Country.
---- Excludes anonymous (NULL CustomerID) transactions, consistent with vw_RevenueByCountry.

CREATE VIEW vw_AverageRevenuePerCustomer AS
	WITH Customer_Revenue AS (
	SELECT c.CustomerID,
		   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
	FROM Customers c
	INNER JOIN Transactions t
		ON c.CustomerID = t.CustomerID
	INNER JOIN Transaction_Details td 
		ON t.InvoiceNo = td.InvoiceNo
	INNER JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY c.CustomerID),
Avg_Revenue AS(
	SELECT AVG(Total_Revenue) AS Average_Customer_Revenue
	FROM Customer_Revenue)
SELECT Average_Customer_Revenue
FROM Avg_Revenue;

select * from vw_AverageRevenuePerCustomer;

--Monthly Revenue Trend KPI
--Question: What is total revenue broken down by month?
--Question: What is total revenue for each year-month combination, across the whole dataset?

SELECT YEAR(t.InvoiceDate) AS Yr , 
	   MONTH(t.InvoiceDate) AS Mo,
	   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
FROM Transactions t
INNER JOIN Transaction_Details td
	ON t.InvoiceNo = td.InvoiceNo
INNER JOIN vw_RealProducts rp
	ON td.StockCode = rp.StockCode
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
GROUP BY YEAR(t.InvoiceDate) ,MONTH(t.InvoiceDate)
ORDER BY Yr,Mo;

--Monthly revenue trend , looks like the pick month was november and makes sense because of the christmas season
--Purpose: Save Monthly Revenue Trend as a reusable View for time-series analysis and future Power BI charting.

CREATE VIEW vw_MonthlyRevenue AS
	SELECT YEAR(t.InvoiceDate) AS Yr , 
	   MONTH(t.InvoiceDate) AS Mo,
	   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
FROM Transactions t
INNER JOIN Transaction_Details td
	ON t.InvoiceNo = td.InvoiceNo
INNER JOIN vw_RealProducts rp
	ON td.StockCode = rp.StockCode
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
GROUP BY YEAR(t.InvoiceDate) ,MONTH(t.InvoiceDate);

--Verify View was saved correctly
SELECT * from vw_MonthlyRevenue ORDER BY Yr,Mo;

--Next Kpi
--Repeat Customer Rate measures what percentage of your customer base didn't just buy once and disappear, but came back and purchased again.
--Repeat Customer Rate = (number of repeat customers) ÷ (total customers) × 100

--Purpose: For each known customer, count how many distinct completed invoices they placed — the base data needed before calculating repeat rate.

WITH Customer_Invoices AS(
	   SELECT CustomerID,
	   COUNT(InvoiceNo) AS Invoice_Count
	   FROM Transactions
       WHERE CustomerID IS NOT NULL AND InvoiceNo NOT LIKE 'C%' AND InvoiceNo <> ', most o'
	   GROUP BY CustomerID),
Repeat_Customer AS(
	SELECT COUNT(*) AS Total_Customers,
		   SUM(CASE WHEN Invoice_Count > 1 THEN 1 ELSE 0 END) Repeat_Customers
	FROM Customer_Invoices)
SELECT (Repeat_Customers * 1.0 / Total_Customers)*100 AS Repeat_Customer_Rate
FROM Repeat_Customer;

-- Result looks intrigating we are seeing a really high customer repeat rate that makes us question if there's any anomilities in our data
--Purpose: Sanity-check the repeat rate by looking at the actual distribution of invoice counts per customer 
--confirm this isn't being inflated by something unexpected.

SELECT Invoice_Count, COUNT(*) AS Num_Customers
FROM (
    SELECT CustomerID, COUNT(InvoiceNo) AS Invoice_Count
    FROM Transactions
    WHERE CustomerID IS NOT NULL AND InvoiceNo NOT LIKE 'C%' AND InvoiceNo <> ', most o'
    GROUP BY CustomerID
) AS Customer_Invoices
GROUP BY Invoice_Count
ORDER BY Invoice_Count;

--Purpose: Save Repeat Customer Rate as a reusable View.

CREATE VIEW vw_RepeatCustomerRate AS
	SELECT Invoice_Count, COUNT(*) AS Num_Customers
FROM (
    SELECT CustomerID, COUNT(InvoiceNo) AS Invoice_Count
    FROM Transactions
    WHERE CustomerID IS NOT NULL AND InvoiceNo NOT LIKE 'C%' AND InvoiceNo <> ', most o'
    GROUP BY CustomerID
) AS Customer_Invoices
GROUP BY Invoice_Count;

SELECT * FROM vw_RepeatCustomerRate order by Invoice_Count;

-- Customer Segmentation by Total Revenue Divided in high/medium/low tier
--Segment customers into High/Mid/Low value tiers based on their total revenue, 
--using percentile-based buckets rather than arbitrary dollar thresholds.

WITH Customer_Revenue AS(
	SELECT c.CustomerID,
		   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
	FROM Customers c
	INNER JOIN Transactions t
		ON c.CustomerID = t.CustomerID
	INNER JOIN Transaction_Details td
		ON t.InvoiceNo = td.InvoiceNo
	INNER JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY c.CustomerID),
Customer_Groups AS(
	SELECT *,
		   NTILE(3) OVER (ORDER BY Total_Revenue DESC) AS Segment_Number
	FROM Customer_Revenue),
Group_Classification AS(
	SELECT *,
		   CASE WHEN Segment_Number = 1 THEN 'High'
				WHEN Segment_Number = 2 THEN 'Medium'
				WHEN Segment_Number = 3 THEN 'Low'
				END AS Segment_Label
	FROM Customer_Groups)
SELECT *
FROM Group_Classification;

--Purpose: Save Customer Segmentation as a reusable View.
CREATE VIEW vw_CustomerSegmentation AS
	WITH Customer_Revenue AS(
	SELECT c.CustomerID,
		   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
	FROM Customers c
	INNER JOIN Transactions t
		ON c.CustomerID = t.CustomerID
	INNER JOIN Transaction_Details td
		ON t.InvoiceNo = td.InvoiceNo
	INNER JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	GROUP BY c.CustomerID),
Customer_Groups AS(
	SELECT *,
		   NTILE(3) OVER (ORDER BY Total_Revenue DESC) AS Segment_Number
	FROM Customer_Revenue),
Group_Classification AS(
	SELECT *,
		   CASE WHEN Segment_Number = 1 THEN 'High'
				WHEN Segment_Number = 2 THEN 'Medium'
				WHEN Segment_Number = 3 THEN 'Low'
				END AS Segment_Label
	FROM Customer_Groups)
SELECT *
FROM Group_Classification;

select * from vw_CustomerSegmentation;



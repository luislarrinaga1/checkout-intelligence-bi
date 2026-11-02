USE CheckoutIntelligence;

--Purpose: Confirm the anomaly pattern in SQL matches the 1,336 rows found in Python before building the fix.

SELECT COUNT(*) 
FROM Transaction_Details td
JOIN Transactions t 
	ON td.InvoiceNo = t.InvoiceNo
WHERE td.Quantity < 0 
AND t.InvoiceNo NOT LIKE 'C%'
AND t.CustomerID IS NULL;

--Purpose: Correct Total Revenue to exclude the inventory-adjustment rows, same approach as the Day 15 admin-code fix.

SELECT * FROM vw_TotalRevenue;

CREATE OR ALTER VIEW vw_TotalRevenue AS
SELECT SUM(td.Quantity * p.UnitPrice) AS Total_Revenue
FROM Transaction_Details td
JOIN vw_RealProducts p
	ON td.StockCode = p.StockCode
JOIN Transactions t
	ON td.InvoiceNo = t.InvoiceNo
WHERE NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL);

-- Shows you the work done in previous query or store procedure

SELECT OBJECT_DEFINITION(OBJECT_ID('vw_TotalRevenue'));

--Purpose: Confirm the new Total Revenue matches exactly what we'd expect mathematically (old total + the excluded anomaly's impact).

SELECT SUM(td.Quantity * p.UnitPrice) AS Anomaly_Impact
FROM Transaction_Details td
JOIN vw_RealProducts p ON td.StockCode = p.StockCode
JOIN Transactions t ON td.InvoiceNo = t.InvoiceNo
WHERE td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL;


--Purpose: Update Average Basket Revenue to exclude the 1,336-row inventory-adjustment anomaly.

SELECT OBJECT_DEFINITION(OBJECT_ID('vw_AverageBasketRevenue'));

CREATE OR ALTER VIEW vw_AverageBasketRevenue AS
WITH Invoices AS(
	SELECT td.InvoiceNo,
		   SUM(td.quantity * rp.UnitPrice) AS Invoice_Revenue
	FROM Transaction_Details td
	JOIN vw_RealProducts rp
		ON td.StockCode = rp.StockCode
	JOIN Transactions t
		ON td.InvoiceNo = t.InvoiceNo
	WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
	AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
	GROUP BY td.InvoiceNo),
Avg_Revenue AS( 
	SELECT AVG(Invoice_Revenue) AS Average_Invoice_Revenue
	FROM Invoices)
SELECT Average_Invoice_Revenue
FROM Avg_Revenue;

--Purpose: Update Revenue by Country to exclude the same anomaly.

SELECT OBJECT_DEFINITION(OBJECT_ID('vw_RevenueByCountry'));

CREATE OR ALTER VIEW vw_RevenueByCountry AS
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
AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
GROUP BY c.Country;

--Purpose: Update Product Revenue (top sellers ranking) to exclude the same anomaly.

SELECT OBJECT_DEFINITION(OBJECT_ID('vw_ProductRevenue'));

CREATE OR ALTER VIEW vw_ProductRevenue AS
SELECT rp.StockCode,
	   rp.Description,
	   SUM(td.quantity * rp.UnitPrice) AS Total_Revenue
FROM vw_RealProducts rp
JOIN Transaction_Details td
	ON rp.StockCode = td.StockCode
JOIN Transactions t
	ON td.InvoiceNo = t.InvoiceNo
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
GROUP BY rp.StockCode, rp.Description;

--Purpose: Update Average Revenue per Customer to exclude the same anomaly.

SELECT OBJECT_DEFINITION(OBJECT_ID('vw_AverageRevenuePerCustomer'));

CREATE OR ALTER VIEW vw_AverageRevenuePerCustomer AS
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
	AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
	GROUP BY c.CustomerID),
Avg_Revenue AS(
	SELECT AVG(Total_Revenue) AS Average_Customer_Revenue
	FROM Customer_Revenue)
SELECT Average_Customer_Revenue
FROM Avg_Revenue;

--Purpose: Update Monthly Revenue trend to exclude the same anomaly.

SELECT OBJECT_DEFINITION(OBJECT_ID('vw_MonthlyRevenue'));

CREATE OR ALTER VIEW vw_MonthlyRevenue AS
SELECT YEAR(t.InvoiceDate) AS Yr,
	   MONTH(t.InvoiceDate) AS Mo,
	   SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
FROM Transaction_Details td
JOIN vw_RealProducts rp
	ON td.StockCode = rp.StockCode
JOIN Transactions t
	ON td.InvoiceNo = t.InvoiceNo
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o'
AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
GROUP BY YEAR(t.InvoiceDate), MONTH(t.InvoiceDate);

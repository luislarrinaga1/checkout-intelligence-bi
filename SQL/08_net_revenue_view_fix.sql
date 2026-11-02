/*
08_net_revenue_view_fix.sql
Purpose: put the revenue views on a NET basis (cancelled invoices count as negative revenue)
so every dashboard chart reconciles to vw_TotalRevenue.

Why: the views below filtered out cancelled invoices with "td.InvoiceNo NOT LIKE 'C%'",
so they reported GROSS revenue. Example: invoice 581483 sold 80,995 units of
PAPER CRAFT, LITTLE BIRDIE and C581484 cancelled all 80,995, but the product view
still ranked it as a top product.

Kept in every view: the malformed-invoice exclusion (', most o') and the
inventory-adjustment exclusion (negative quantity, not cancelled, no customer).
Run each block on its own batch (GO), because ALTER VIEW must be first in its batch.

Checks after running:
  SUM(vw_ProductRevenue)       = 9,954,868.46
  SUM(vw_MonthlyRevenue)       = 9,954,868.46
  SUM(vw_RevenueByCountry)     = 8,990,402.85  (identified customers only)
  SUM(vw_CustomerSegmentation) = 8,990,402.85
Known difference: vw_TotalRevenue is $33.20 higher (9,954,901.66) because it still
includes the malformed invoice ', most o' (a CSV parsing artifact).
vw_AverageBasketRevenue and vw_NumberOfTransactions are unchanged on purpose:
they count orders, so excluding cancelled invoices is correct for them.
*/

USE CheckoutIntelligence;
GO

ALTER VIEW vw_ProductRevenue AS
SELECT rp.StockCode,
       rp.Description,
       SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
FROM vw_RealProducts rp
JOIN Transaction_Details td
    ON rp.StockCode = td.StockCode
JOIN Transactions t
    ON td.InvoiceNo = t.InvoiceNo
WHERE td.InvoiceNo <> ', most o'
  AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
GROUP BY rp.StockCode, rp.Description;
GO

ALTER VIEW vw_MonthlyRevenue AS
SELECT YEAR(t.InvoiceDate) AS Yr,
       MONTH(t.InvoiceDate) AS Mo,
       SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
FROM Transaction_Details td
JOIN vw_RealProducts rp ON td.StockCode = rp.StockCode
JOIN Transactions t ON td.InvoiceNo = t.InvoiceNo
WHERE td.InvoiceNo <> ', most o'
  AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
GROUP BY YEAR(t.InvoiceDate), MONTH(t.InvoiceDate);
GO

ALTER VIEW vw_RevenueByCountry AS
SELECT c.Country,
       SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
FROM Customers c
INNER JOIN Transactions t ON c.CustomerID = t.CustomerID
INNER JOIN Transaction_Details td ON t.InvoiceNo = td.InvoiceNo
INNER JOIN vw_RealProducts rp ON td.StockCode = rp.StockCode
WHERE td.InvoiceNo <> ', most o'
  AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
GROUP BY c.Country;
GO

ALTER VIEW vw_AverageRevenuePerCustomer AS
WITH Customer_Revenue AS (
    SELECT c.CustomerID,
           SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
    FROM Customers c
    INNER JOIN Transactions t ON c.CustomerID = t.CustomerID
    INNER JOIN Transaction_Details td ON t.InvoiceNo = td.InvoiceNo
    INNER JOIN vw_RealProducts rp ON td.StockCode = rp.StockCode
    WHERE td.InvoiceNo <> ', most o'
      AND NOT (td.Quantity < 0 AND t.InvoiceNo NOT LIKE 'C%' AND t.CustomerID IS NULL)
    GROUP BY c.CustomerID),
Avg_Revenue AS (
    SELECT AVG(Total_Revenue) AS Average_Customer_Revenue
    FROM Customer_Revenue)
SELECT Average_Customer_Revenue
FROM Avg_Revenue;
GO

ALTER VIEW vw_CustomerSegmentation AS
WITH Customer_Revenue AS (
    SELECT c.CustomerID,
           SUM(td.Quantity * rp.UnitPrice) AS Total_Revenue
    FROM Customers c
    INNER JOIN Transactions t ON c.CustomerID = t.CustomerID
    INNER JOIN Transaction_Details td ON t.InvoiceNo = td.InvoiceNo
    INNER JOIN vw_RealProducts rp ON td.StockCode = rp.StockCode
    WHERE td.InvoiceNo <> ', most o'
    GROUP BY c.CustomerID),
Customer_Groups AS (
    SELECT *,
           NTILE(3) OVER (ORDER BY Total_Revenue DESC) AS Segment_Number
    FROM Customer_Revenue),
Group_Classification AS (
    SELECT *,
           CASE WHEN Segment_Number = 1 THEN 'High'
                WHEN Segment_Number = 2 THEN 'Medium'
                WHEN Segment_Number = 3 THEN 'Low'
           END AS Segment_Label
    FROM Customer_Groups)
SELECT *
FROM Group_Classification;
GO

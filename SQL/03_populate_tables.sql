-- ============================================================
-- Checkout Intelligence — Populate Real Tables from Staging
-- Splits the flat staging data into the four normalized tables.
-- Each table's fix strategy was chosen based on diagnosing the
-- actual data first — not assumed in advance.
-- ============================================================

USE CheckoutIntelligence;
GO

-- ============================================================
-- 1. CUSTOMERS
-- Question: For each customer, find the single Country where
-- they have the most transactions, and insert exactly one
-- (CustomerID, Country) row per customer.
-- ============================================================

-- Diagnostic: found 8 CustomerIDs with conflicting Country values
SELECT CustomerID, COUNT(DISTINCT Country) AS CountryCount
FROM Staging_OnlineRetail
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
HAVING COUNT(DISTINCT Country) > 1;

-- Investigated the 8 conflicting customers — in every case one
-- Country clearly dominated by transaction count (no near-ties)

WITH Customer_Country_Rank AS (
     SELECT CustomerID,
            Country,
            ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY COUNT(*) DESC) AS Row_Num
     FROM Staging_OnlineRetail
     WHERE CustomerID IS NOT NULL
     GROUP BY CustomerID, Country
)
INSERT INTO Customers (CustomerID, Country)
SELECT CustomerID, Country
FROM Customer_Country_Rank
WHERE Row_Num = 1;

-- Verification: expect ~4,300 rows, zero duplicate CustomerIDs
SELECT COUNT(*) FROM Customers;

SELECT CustomerID, COUNT(*) 
FROM Customers 
GROUP BY CustomerID 
HAVING COUNT(*) > 1;   -- expect 0 rows


-- ============================================================
-- 2. PRODUCTS
-- Question: For each StockCode, find its most frequent
-- (Description, UnitPrice) combination, and insert exactly
-- one row per StockCode.
-- ============================================================

-- Diagnostic: many StockCodes have multiple UnitPrices (real
-- price changes over the 2010-2011 period)
SELECT StockCode, COUNT(DISTINCT UnitPrice) AS PriceVariations
FROM Staging_OnlineRetail
WHERE StockCode IS NOT NULL
GROUP BY StockCode
HAVING COUNT(DISTINCT UnitPrice) > 1;

WITH Most_Frequent_Values AS(
    SELECT StockCode, 
           Description,
           UnitPrice,
           ROW_NUMBER() OVER(PARTITION BY StockCode ORDER BY COUNT(*) DESC) AS Row_Num
    FROM Staging_OnlineRetail
    WHERE StockCode IS NOT NULL
    GROUP BY StockCode, Description, UnitPrice
)
INSERT INTO Products(StockCode, Description, UnitPrice)
SELECT StockCode, Description, UnitPrice
FROM Most_Frequent_Values
WHERE Row_Num = 1;

-- Verification: zero duplicate StockCodes expected
SELECT COUNT(*) FROM Products;

SELECT StockCode, COUNT(*)
FROM Products
GROUP BY StockCode
HAVING COUNT(*) > 1;   -- expect 0 rows


-- ============================================================
-- 3. TRANSACTIONS
-- Question: For each unique InvoiceNo, get its CustomerID and
-- the earliest InvoiceDate recorded. Anonymous (NULL CustomerID)
-- invoices are kept intentionally — they still represent real
-- revenue and were a deliberate Day 11 decision, not an oversight.
-- ============================================================

-- Diagnostic: confirmed no invoice has genuinely conflicting
-- CustomerIDs; the InvoiceDate "conflicts" were just line items
-- logged a minute or two apart within the same real checkout event
SELECT InvoiceNo, MIN(InvoiceDate) AS EarliestTime, MAX(InvoiceDate) AS LatestTime, 
       COUNT(DISTINCT InvoiceDate) AS DateVariations
FROM Staging_OnlineRetail
GROUP BY InvoiceNo
HAVING COUNT(DISTINCT InvoiceDate) > 1;

INSERT INTO Transactions(InvoiceNo, CustomerID, InvoiceDate)
SELECT InvoiceNo, CustomerID, MIN(InvoiceDate)
FROM Staging_OnlineRetail
GROUP BY InvoiceNo, CustomerID;

-- Verification: expect ~25,901 rows, zero duplicate InvoiceNos
SELECT COUNT(*) FROM Transactions;

SELECT InvoiceNo, COUNT(*) 
FROM Transactions 
GROUP BY InvoiceNo 
HAVING COUNT(*) > 1;   -- expect 0 rows


-- ============================================================
-- 4. TRANSACTION_DETAILS
-- Question: Insert every line item from staging as-is — no
-- deduplication, no grouping. A customer can legitimately buy
-- the same product twice on one invoice; each is a real, separate
-- event that should be preserved, not collapsed.
-- ============================================================

-- Referential integrity check: does every non-null StockCode in
-- staging actually exist in Products? (must be 0 before inserting,
-- since StockCode is a FOREIGN KEY)
SELECT COUNT(*) 
FROM Staging_OnlineRetail s
WHERE s.StockCode IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM Products p WHERE p.StockCode = s.StockCode
);

INSERT INTO Transaction_Details(InvoiceNo, StockCode, Quantity)
SELECT InvoiceNo, StockCode, Quantity
FROM Staging_OnlineRetail;

-- Verification: expect ~541,909 rows (no dedup applied)
SELECT COUNT(*) FROM Transaction_Details;


-- ============================================================
-- FINAL PROOF — full four-table join
-- Confirms the entire data model works together end-to-end.
-- LEFT JOIN on Customers is intentional: preserves anonymous
-- transactions instead of silently dropping them.
-- ============================================================

SELECT TOP 10
    c.CustomerID,
    c.Country,
    t.InvoiceNo,
    t.InvoiceDate,
    p.Description,
    p.UnitPrice,
    td.Quantity
FROM Transaction_Details td
JOIN Transactions t ON td.InvoiceNo = t.InvoiceNo
JOIN Products p ON td.StockCode = p.StockCode
LEFT JOIN Customers c ON t.CustomerID = c.CustomerID
ORDER BY t.InvoiceDate;

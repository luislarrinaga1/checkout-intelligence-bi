-- ============================================================
-- Checkout Intelligence — Staging Table & Raw Data Import
-- Creates a flat staging table matching the raw CSV exactly,
-- then imports all 541,910 rows via BULK INSERT.
-- Column order MUST match the CSV header order exactly —
-- BULK INSERT matches columns by position, not by name.
-- ============================================================

USE CheckoutIntelligence;
GO

CREATE TABLE Staging_OnlineRetail(
	InvoiceNo VARCHAR(20),
	StockCode VARCHAR(50),
	Description VARCHAR(300),
	Quantity INT,
	InvoiceDate DATETIME,
	UnitPrice DECIMAL(10,2),
	CustomerID INT,
	Country VARCHAR(50)
);

BULK INSERT dbo.Staging_OnlineRetail
FROM 'C:\Users\luisl\Documents\Project 1 - Self Checkout Performance Analysis-20260728T171631Z-1-001\Project 1 - Self Checkout Performance Analysis\Data\Raw Data\Online Retail Copy CSV.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,              -- skip header row
    FIELDQUOTE = '"',          -- handles commas embedded inside quoted description text
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',        -- matches UTF-8 encoding
    TABLOCK
);

-- ============================================================
-- Initial data quality checks — confirming Day 7 profiling
-- hypotheses against the real imported data
-- ============================================================

SELECT COUNT(*) AS Row_Count FROM Staging_OnlineRetail;
-- Expect ~541,909 (541,910 minus header row)

-- How many rows have NULL CustomerID?
SELECT COUNT(*) AS Null_Customer_ID FROM Staging_OnlineRetail WHERE CustomerID IS NULL;
-- Result: 135,080 — confirms ~25% of transactions are anonymous

-- How many rows have negative Quantity (likely returns)?
SELECT COUNT(*) AS Negative_Quantity FROM Staging_OnlineRetail WHERE Quantity < 0;
-- Result: 10,624

-- Peek at a few negative-quantity rows to confirm the "returns" theory
SELECT TOP 10 * FROM Staging_OnlineRetail WHERE Quantity < 0;
-- Confirmed: negative quantities include both genuine returns AND
-- non-product adjustment rows (e.g. Description = "Discount").
-- All are on "C"-prefixed (Cancelled) invoices.

-- Confirm staging table landed in the correct database
SELECT TABLE_CATALOG, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME = 'Staging_OnlineRetail';

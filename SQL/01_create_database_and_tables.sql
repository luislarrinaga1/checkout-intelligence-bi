-- ============================================================
-- Checkout Intelligence — Database & Table Creation
-- Creates the CheckoutIntelligence database and the four core
-- tables from the ERD: Customers, Transactions, Products, Transaction_Details
-- Order matters: tables with foreign keys must be created AFTER
-- the table they reference.
-- ============================================================

CREATE DATABASE CheckoutIntelligence;
GO

USE CheckoutIntelligence;
GO

CREATE TABLE Customers(
	CustomerID INT PRIMARY KEY NOT NULL,
	Country VARCHAR(50)
);

CREATE TABLE Transactions(
	InvoiceNo VARCHAR(20) PRIMARY KEY NOT NULL,
	CustomerID INT,
	FOREIGN KEY(CustomerID) REFERENCES Customers(CustomerID),
	InvoiceDate DATETIME
);
-- Note: InvoiceNo is VARCHAR, not INT, because cancelled/returned
-- invoices are prefixed with "C" (e.g. C536379).

CREATE TABLE Products(
	StockCode VARCHAR(50) PRIMARY KEY NOT NULL,
	Description VARCHAR(255),
	UnitPrice DECIMAL(10,2)
);

CREATE TABLE Transaction_Details(
	Transaction_Detail_ID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
	InvoiceNo VARCHAR(20),
	FOREIGN KEY(InvoiceNo) REFERENCES Transactions(InvoiceNo),
	StockCode VARCHAR(50),
	FOREIGN KEY(StockCode) REFERENCES Products(StockCode),
	Quantity INT NOT NULL
);

-- ============================================================
-- Verification — confirm all four tables exist in the correct
-- database (not accidentally created under master)
-- ============================================================

SELECT TABLE_CATALOG, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('Customers', 'Transactions', 'Products', 'Transaction_Details');

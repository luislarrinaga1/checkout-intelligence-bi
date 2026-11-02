-- ============================================================
-- Checkout Intelligence — Schema Fix: InvoiceNo Type Correction
-- ============================================================
-- HISTORICAL RECORD — NOT meant to be re-run against a fresh build.
-- 01_create_database_and_tables.sql already has the corrected
-- VARCHAR(20) type baked in. This file documents the real bug
-- and fix as it happened, for the project journal / interview story.
--
-- THE BUG: Transactions.InvoiceNo and Transaction_Details.InvoiceNo
-- were originally created as INT (before the "C"-prefix cancelled
-- invoice issue was caught during staging setup). This caused:
--
--   Msg 245: Conversion failed when converting the varchar value
--   'C554011' to data type int.
--
-- THE COMPLICATION: InvoiceNo is a PRIMARY KEY (on Transactions)
-- with a FOREIGN KEY depending on it (on Transaction_Details).
-- SQL Server refuses to ALTER a column's type while constraints
-- depend on it — the constraints have to be dropped first, then
-- rebuilt after the type change.
-- ============================================================

-- Step 1: Identify the exact constraint names (from the error
-- message, or via INFORMATION_SCHEMA.COLUMNS)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Transactions';

-- Step 2: Drop the foreign key first (it depends on the PK)
ALTER TABLE Transaction_Details
DROP CONSTRAINT FK__Transacti__Invoi__74AE54BC;

-- Step 3: Drop the primary key
ALTER TABLE Transactions
DROP CONSTRAINT PK__Transact__D796B22603487187;

-- Step 4: Now the column can be altered
ALTER TABLE Transactions
ALTER COLUMN InvoiceNo VARCHAR(20) NOT NULL;

-- Step 5: Fix the matching column on the dependent table too
ALTER TABLE Transaction_Details
ALTER COLUMN InvoiceNo VARCHAR(20);

-- Step 6: Rebuild the primary key
ALTER TABLE Transactions
ADD CONSTRAINT PK_Transactions_InvoiceNo PRIMARY KEY (InvoiceNo);

-- Step 7: Rebuild the foreign key
ALTER TABLE Transaction_Details
ADD CONSTRAINT FK_TransactionDetails_InvoiceNo FOREIGN KEY (InvoiceNo) REFERENCES Transactions(InvoiceNo);

-- Verification: confirm both columns are now VARCHAR(20)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('Transactions', 'Transaction_Details')
AND COLUMN_NAME = 'InvoiceNo';

-- ============================================================
-- LESSON: when a column with dependent constraints needs its
-- type changed, the order is always:
-- drop FK → drop PK → alter column(s) → rebuild PK → rebuild FK
-- ============================================================

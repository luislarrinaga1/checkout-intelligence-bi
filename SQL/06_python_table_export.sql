USE CheckoutIntelligence;

--Purpose: Export a clean, joined dataset from SQL Server as a CSV, ready for pandas to load and explore.


SELECT 
    c.CustomerID,
    c.Country,
    t.InvoiceNo,
    t.InvoiceDate,
    rp.StockCode,
    rp.Description,
    rp.UnitPrice,
    td.Quantity,
    (td.Quantity * rp.UnitPrice) AS LineRevenue
FROM Transaction_Details td
JOIN Transactions t ON td.InvoiceNo = t.InvoiceNo
JOIN vw_RealProducts rp ON td.StockCode = rp.StockCode
LEFT JOIN Customers c ON t.CustomerID = c.CustomerID
WHERE td.InvoiceNo NOT LIKE 'C%' AND td.InvoiceNo <> ', most o';
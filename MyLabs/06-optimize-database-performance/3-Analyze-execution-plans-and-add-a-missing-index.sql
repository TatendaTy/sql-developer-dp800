USE [AdventureWorks2025];
GO

-- Execution plans show you the exact operators, data access methods, and cost estimates the optimizer chose for a query.
-- In this section, you run a query that performs poorly, read the plan to understand why, and fix it with a covering index.

SET STATISTICS XML ON;

SELECT
    oh.OrderID,
    oh.OrderDate,
    p.Name AS ProductName,
    oh.Quantity,
    oh.UnitPrice,
    oh.TotalAmount,
    oh.Status
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
    ON oh.ProductID = p.ProductID
WHERE oh.CustomerID = 29485
  AND oh.OrderDate >= DATEADD(MONTH, -3, GETDATE())
ORDER BY oh.OrderDate DESC;

SET STATISTICS XML OFF;
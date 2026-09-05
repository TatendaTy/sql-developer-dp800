USE [AdventureWorks2025];
GO

/*
Parameter sniffing is a common cause of plan regressions. 
The optimizer compiles a plan based on the first parameter value it sees and caches that plan. 
All future calls reuse the cached plan, even when a different plan would perform better. 
In this section, you cause a parameter sniffing regression using a stored procedure, detect it with the Query Store GUI, and force the better plan.
*/

-- 1. Set up the regression scenario
-- Clear Query Store and reconfigure it so every stored procedure call is recorded:
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;
GO

ALTER DATABASE CURRENT SET QUERY_STORE (
    QUERY_CAPTURE_MODE = ALL
);
GO

/*
QUERY_CAPTURE_MODE = ALL ensures every execution is recorded, including short stored procedure calls that the default AUTO mode might skip.
In production, you would typically keep the default AUTO capture mode to focus on more expensive queries.
*/

-- 2. Replace the covering index with a noncovering one. 
-- Without INCLUDE columns, the optimizer must decide between an index seek with key lookups (fast for few rows) and a full table scan (cheaper when there are many key lookups). 
-- This decision is what makes parameter sniffing possible:
DROP INDEX IF EXISTS IX_OrderHistory_CustomerDate ON dbo.OrderHistory;

GO
CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC);

-- 3. Add skewed data so one customer has far more orders than others.
-- This skewed data creates the conditions for parameter sniffing by giving the optimizer a reason to choose different plans for different customers:
INSERT INTO dbo.OrderHistory (CustomerID, ProductID, OrderDate, Quantity, UnitPrice, Status)
SELECT TOP 50000
    1,
    p.ProductID,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 10 + 1,
    p.ListPrice,
    N'Pending'
FROM SalesLT.Product AS p
CROSS JOIN SalesLT.Product AS p2
ORDER BY NEWID();

/*
 CustomerID 1 now has over 50,000 rows, while most other customers have fewer than 100. 
 This extreme skew is what makes the optimizer choose different access methods for different parameter values.
*/

-- 4. Update statistics so the optimizer knows about the new data distribution:
UPDATE STATISTICS dbo.OrderHistory;

-- 5. Create a stored procedure that wraps the customer order query. Stored procedures cache their execution plans, which is what makes parameter sniffing happen:
-- Use a distinct name because dbo.GetCustomerOrders is already used by an inline TVF from an earlier lab.
GO
CREATE OR ALTER PROCEDURE dbo.GetCustomerOrdersProc
    @CustomerID INT
AS
BEGIN
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
    WHERE oh.CustomerID = @CustomerID
    ORDER BY oh.OrderDate DESC;
END;
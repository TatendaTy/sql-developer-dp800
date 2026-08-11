USE [AdventureWorks2025];
GO

-- Build a TVF to return orders for a given customer. TVFs are handy in SELECT and JOIN clauses.

CREATE OR ALTER FUNCTION dbo.GetCustomerOrders (@CustomerID INT)
RETURNS TABLE
AS
RETURN
(
SELECT 
    h.SalesOrderID,
    h.OrderDate
FROM SalesLT.SalesOrderHeader h
WHERE h.CustomerID = @CustomerID
);
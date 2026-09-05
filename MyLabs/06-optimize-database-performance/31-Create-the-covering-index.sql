USE [AdventureWorks2025];
GO

-- Rather than using the exact suggestion from the plan, add a DESC sort on OrderDate so the engine reads the most recent orders first without an extra sort:
CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC)
INCLUDE (ProductID, Quantity, UnitPrice, Status);

/*
This index uses a compound key on CustomerID and OrderDate DESC. 
The engine can seek directly to the customer's rows, and the DESC order means it reads the most recent orders first without an extra sort.
The included columns prevent Key Lookups back to the clustered index, making this a covering index.
*/
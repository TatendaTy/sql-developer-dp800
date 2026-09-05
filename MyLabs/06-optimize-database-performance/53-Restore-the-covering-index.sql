DROP PROCEDURE IF EXISTS dbo.GetCustomerOrdersProc;

DROP INDEX IX_OrderHistory_CustomerDate ON dbo.OrderHistory;

CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC)
INCLUDE (ProductID, Quantity, UnitPrice, Status);
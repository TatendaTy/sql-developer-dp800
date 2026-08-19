USE [AdventureWorks2025];
GO

-- 1. Consider adding indexes to improve performance of JOIN operations and filter predicates.
-- 2. Extend the stored procedure to handle multiple line items per order.
-- 3. Add permissions to expose the view safely to end users.


-- Suggested indexes (add these to the table, not the trigger)
-- Indexes on SalesOrderID and the computed columns make these operations much faster.
CREATE INDEX IX_SalesLT_SalesOrderID ON SalesLT.SalesOrderDetail(SalesOrderID);
CREATE INDEX IX_SalesLT_SalesOrderDetail_OrderQty_UnitPrice 
    ON SalesLT.SalesOrderDetail(OrderQty, UnitPrice);

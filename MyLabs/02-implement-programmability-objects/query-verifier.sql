USE [AdventureWorks2025];
GO

-- 01 Return the first 5 rows from the vCustomerOrders view
-- SELECT TOP (5) * 
-- FROM SalesLT.vCustomerOrders 
-- ORDER BY OrderDate DESC;

-- 02 Test the stored procedure to add a line item to an existing order
-- Add a line item to an existing order (choose a valid SalesOrderID)
-- DECLARE @SalesOrderID INT = (SELECT TOP 1 SalesOrderID 
--                             FROM SalesLT.SalesOrderHeader 
--                             ORDER BY SalesOrderID DESC);
-- EXEC dbo.AddOrderLineItem @SalesOrderID = @SalesOrderID,         
--                             @ProductID = 680, 
--                             @Quantity = 1; -- adjust ProductID as needed

-- SELECT TOP (5) * 
-- FROM SalesLT.SalesOrderDetail 
-- WHERE SalesOrderID = @SalesOrderID 
-- ORDER BY SalesOrderDetailID DESC;

-- SELECT SalesOrderID, SubTotal, TaxAmt, Freight, TotalDue 
-- FROM SalesLT.SalesOrderHeader 
-- WHERE SalesOrderID = @SalesOrderID;

-- 03 Test the scalar function to calculate the total value of an order
-- SELECT d.SalesOrderID, dbo.fnOrderTotal(d.SalesOrderID) AS OrderTotal
-- FROM SalesLT.SalesOrderDetail d
-- GROUP BY d.SalesOrderID
-- ORDER BY d.SalesOrderID DESC;

-- 04 Test the inline table-valued function to get orders for a specific customer
-- Query the function for a specific customer (choose a valid CustomerID)
-- SELECT * 
-- FROM dbo.GetCustomerOrders(29929)
-- ORDER BY OrderDate DESC;

-- Join the function to customers
-- SELECT CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName, o.SalesOrderID, o.OrderDate
-- FROM SalesLT.Customer c
--     CROSS APPLY dbo.GetCustomerOrders(c.CustomerID) o
-- WHERE c.CustomerID = 29929;

-- 05 Test the trigger that updates an order detail to change the total
-- Update an order detail to change the total
-- UPDATE d
-- SET OrderQty = OrderQty + 1
-- FROM SalesLT.SalesOrderDetail d
-- WHERE d.SalesOrderID = (SELECT TOP 1 SalesOrderID FROM SalesLT.SalesOrderHeader ORDER BY SalesOrderID DESC);

-- SELECT TOP (5) * 
-- FROM dbo.OrderAudit 
-- ORDER BY AuditID DESC;


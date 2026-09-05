USE [AdventureWorks2025];
GO

-- part 1: Verify that the OrderHistory table exists and has data
-- SELECT COUNT(*) AS TotalOrders FROM dbo.OrderHistory;
-- GO

-- part 2: Verify that the Query Store is enabled and capturing data
-- SELECT actual_state_desc, desired_state_desc,
--     current_storage_size_mb, max_storage_size_mb
-- FROM sys.database_query_store_options;

-- SELECT name, type, type_desc
-- FROM sys.objects
-- WHERE name = 'GetCustomerOrders';

-- Part 5-2
-- Test the Query Store forced plan status
EXEC dbo.GetCustomerOrdersProc @CustomerID = 29485;
GO

EXEC dbo.GetCustomerOrdersProc @CustomerID = 1;
GO
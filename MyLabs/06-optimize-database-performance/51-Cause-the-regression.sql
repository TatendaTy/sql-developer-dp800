USE [AdventureWorks2025];
GO

-- 1. Clear the procedure cache and compile the fast plan by running the procedure with CustomerID 29485 (fewer than 100 rows). 
-- The optimizer compiles a plan with an Index Seek:
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.GetCustomerOrdersProc @CustomerID = 29485;
GO 10

-- 2. Clear the cache and compile the slow plan by calling with CustomerID 1 (50000+ rows).
-- The optimizer compiles a Clustered Index Scan because scanning the whole table is cheaper than performing 50,000 key lookups:
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.GetCustomerOrdersProc @CustomerID = 1;

-- 3. Run the procedure again with CustomerID 29485. The optimizer reuses the cached plan
EXEC dbo.GetCustomerOrdersProc @CustomerID = 29485;

-- 4. Flush Query Store data to disk so the GUI can display the results immediately:
EXEC sp_query_store_flush_db;


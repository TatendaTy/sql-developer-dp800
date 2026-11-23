USE [AdventureWorks2025];
GO

/* Execution plans examine one query at a time. 
 DMVs give you a broader view across all queries in the database, which helps you find the most expensive ones before diving into individual plans.
*/

-- 1. find the top 5 most expensive queries by average CPU time
-- SELECT TOP 5
--     qs.total_worker_time / qs.execution_count AS avg_cpu_time_us,
--     qs.execution_count,
--     qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
--     SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
--         ((CASE qs.statement_end_offset
--             WHEN -1 THEN DATALENGTH(st.text)
--             ELSE qs.statement_end_offset
--         END - qs.statement_start_offset) / 2) + 1) AS query_text
-- FROM sys.dm_exec_query_stats AS qs
-- CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
-- ORDER BY avg_cpu_time_us DESC;

-- 2. The existing IX_OrderHistory_CustomerDate index covers queries that filter by CustomerID, but the warehouse team also runs a report that filters by Status and joins to the Product table. 
-- Run this query a few times so the optimizer registers the missing index:
-- SELECT
--     p.Name AS ProductName,
--     p.ProductNumber,
--     oh.OrderDate,
--     oh.Quantity,
--     oh.TotalAmount
-- FROM dbo.OrderHistory AS oh
-- INNER JOIN SalesLT.Product AS p
--     ON oh.ProductID = p.ProductID
-- WHERE oh.Status = N'Pending'
--     AND oh.OrderDate >= DATEADD(MONTH, -1, GETDATE())
-- ORDER BY oh.TotalAmount DESC;
-- GO 5

/* 
The above query needs an index on Status and OrderDate, which is different from the existing index on CustomerID and OrderDate. 
Running it multiple times ensures the optimizer accumulates enough statistics for the missing index DMVs.
*/

-- 3. query the missing index DMVs to see what the optimizer recommends across the entire workload:
SELECT TOP 10
    mid.statement AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact *
        (migs.user_seeks + migs.user_scans), 2) AS improvement_measure
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;

/*
You should see a recommendation with Status as an equality column and OrderDate as an inequality column. 
The improvement_measure combines the average query cost, the estimated improvement percentage, and how often the query runs. Higher values mean greater benefit. 
These are recommendations, not directives. 
Always test a new index on both read and write performance before adding it to production.
*/


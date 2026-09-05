USE [AdventureWorks2025];
GO

-- inspect Query Store and force the faster plan using SQL instead of the SSMS GUI.
-- EXEC sp_query_store_flush_db;
-- GO

-- SELECT
--     q.query_id,
--     q.object_id,
--     OBJECT_SCHEMA_NAME(q.object_id) AS schema_name,
--     OBJECT_NAME(q.object_id) AS object_name,
--     qt.query_sql_text,
--     p.plan_id,
--     p.is_forced_plan,
--     rs.count_executions,
--     rs.avg_duration,
--     rs.avg_cpu_time,
--     rs.avg_logical_io_reads
-- FROM sys.query_store_query AS q
-- JOIN sys.query_store_query_text AS qt
--     ON qt.query_text_id = q.query_text_id
-- JOIN sys.query_store_plan AS p
--     ON p.query_id = q.query_id
-- LEFT JOIN sys.query_store_runtime_stats AS rs
--     ON rs.plan_id = p.plan_id
-- WHERE q.object_id IS NOT NULL
--   AND OBJECT_NAME(q.object_id) = 'GetCustomerOrdersProc'
-- ORDER BY q.query_id, p.plan_id;

-- Force the faster plan for the specified query using the Query Store.
-- EXEC sp_query_store_force_plan
--     @query_id = 147,
--     @plan_id = 153;
-- GO

-- Verify it worked by checking the forced plan status in the Query Store.
SELECT
    q.query_id,
    p.plan_id,
    p.is_forced_plan,
    p.force_failure_count,
    qt.query_sql_text
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE q.query_id = 147;


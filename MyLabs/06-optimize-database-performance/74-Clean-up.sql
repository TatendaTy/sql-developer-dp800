USE [AdventureWorks2025];
GO

DROP PROCEDURE IF EXISTS dbo.GetCustomerOrdersProc;
DROP TABLE IF EXISTS dbo.OrderHistory;

-- Unforce any forced plans and clear Query Store hints to leave the database in a clean state:
-- Unforce all plans
DECLARE @qid INT, @pid INT;

SELECT TOP 1 @qid = q.query_id, @pid = p.plan_id
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q ON p.query_id = q.query_id
WHERE p.is_forced_plan = 1;

WHILE @@ROWCOUNT > 0
BEGIN
    EXEC sp_query_store_unforce_plan @query_id = @qid, @plan_id = @pid;

    SELECT TOP 1 @qid = q.query_id, @pid = p.plan_id
    FROM sys.query_store_plan AS p
    INNER JOIN sys.query_store_query AS q ON p.query_id = q.query_id
    WHERE p.is_forced_plan = 1;
END


USE [AdventureWorks2025];
GO

-- Step 3: Create a view for safe exposure of audit data
-- This view exposes only the columns needed by end users,
-- excluding sensitive OldTotal data if appropriate
CREATE VIEW saleslt.OrderAuditSafeView
AS
SELECT AuditID, OrderID, NewTotal, ChangedAt
FROM dbo.OrderAudit;
GO

-- Grant permissions on the view (not the base table)
-- This allows controlled access to audit information
GRANT SELECT ON saleslt.OrderAuditSafeView TO public;
GO

-- Test the view
SELECT * FROM saleslt.OrderAuditSafeView;
GO

-- Verify permissions worked
SELECT principal_name, permission_name, state_desc
FROM sys.database_permissions
WHERE object_id = OBJECT_ID('saleslt.OrderAuditSafeView');
GO
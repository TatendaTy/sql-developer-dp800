USE master;
GO

ALTER DATABASE ProductCatalog SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE IF EXISTS ProductCatalog;
GO

-- Set the database back to multi-user mode in case it still exists
ALTER DATABASE ProductCatalog SET MULTI_USER;
GO

-- Check if the database still exists
-- SELECT name FROM sys.databases WHERE name = N'ProductCatalog';
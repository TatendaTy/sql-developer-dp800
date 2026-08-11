USE [master];
GO

-- Disconnect any stuck query sessions
ALTER DATABASE [AdventureWorks2025] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

-- Overwrite with the verified internal logical names
RESTORE DATABASE [AdventureWorks2025]
FROM DISK = N'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\AdventureWorksLT2025.bak'
WITH FILE = 1,
MOVE 'AdventureWorksLT2022_Data' TO 'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks2025.mdf',
MOVE 'AdventureWorksLT2022_Log' TO 'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks2025_log.ldf',
REPLACE,
NOUNLOAD, 
STATS = 5;
GO

-- Re-open for normal use
ALTER DATABASE [AdventureWorks2025] SET MULTI_USER;
GO

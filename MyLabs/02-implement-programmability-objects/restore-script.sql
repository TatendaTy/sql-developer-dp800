USE [master];
GO

RESTORE DATABASE [AdventureWorks2025]
FROM DISK = N'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\AdventureWorksLT2025.bak'
WITH FILE = 1,
MOVE 'AdventureWorksLT2022_Data' TO 'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks2025.mdf',
MOVE 'AdventureWorksLT2022_Log' TO 'D:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks2025_log.ldf',
NOUNLOAD, 
STATS = 5;
GO

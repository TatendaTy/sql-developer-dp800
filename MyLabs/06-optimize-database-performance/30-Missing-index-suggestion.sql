/*
Missing Index Details from 
The Query Processor estimates that implementing the following index could improve the query cost by 94.3688%.
*/

/*
USE [AdventureWorks2025]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[OrderHistory] ([CustomerID],[OrderDate])
INCLUDE ([ProductID],[Quantity],[UnitPrice],[TotalAmount],[Status])
GO
*/

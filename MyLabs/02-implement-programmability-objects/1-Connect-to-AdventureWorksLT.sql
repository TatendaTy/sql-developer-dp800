USE [AdventureWorks2025];
GO

-- Verify key tables in AdventureWorksLT
SELECT TOP (5) CustomerID, FirstName, LastName
FROM SalesLT.Customer;
GO

SELECT TOP (5) SalesOrderID, OrderDate, CustomerID
FROM SalesLT.SalesOrderHeader;
GO

SELECT TOP (5) ProductID, Name, ListPrice
FROM SalesLT.Product;
GO

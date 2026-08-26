-- Exercise: Use Copilot for query optimization suggestions

USE [AdventureWorks2025];
GO

SELECT
    h.SalesOrderID,
    h.OrderDate,
    h.CustomerID,
    d.SalesOrderDetailID,
    d.ProductID,
    p.Name AS ProductName,
    d.OrderQty,
    d.UnitPrice,
    d.LineTotal
FROM SalesLT.SalesOrderHeader AS h
INNER JOIN SalesLT.SalesOrderDetail AS d
    ON h.SalesOrderID = d.SalesOrderID
INNER JOIN SalesLT.Product AS p
    ON d.ProductID = p.ProductID
WHERE h.OrderDate > '2008-01-01';
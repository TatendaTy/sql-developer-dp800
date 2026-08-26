-- Exercise Part B: Use Copilot to generate a view

USE [AdventureWorks2025];
GO

-- =============================================
-- Author:              Tatenda Kabanda
-- Create date:         08-26-2025
-- Description:         Product sales analysis: name, category, quantity sold, revenue, average price, order count
-- =============================================
CREATE VIEW dbo.vw_ProductSalesAnalysis
AS
SELECT
    p.ProductID,
    p.Name AS ProductName,
    ISNULL(c.Name, 'No Category') AS CategoryName,
    SUM(sod.OrderQty) AS TotalQuantitySold,
    SUM(sod.LineTotal) AS TotalRevenue,
    CASE WHEN SUM(sod.OrderQty) = 0 THEN 0
         ELSE SUM(sod.LineTotal) / SUM(sod.OrderQty)
    END AS AverageSalePrice,
    COUNT(DISTINCT sod.SalesOrderID) AS NumberOfOrders
FROM SalesLT.Product AS p
LEFT JOIN SalesLT.ProductCategory AS pcat
    ON p.ProductCategoryID = pcat.ProductCategoryID
LEFT JOIN SalesLT.ProductCategory AS c
    ON pcat.ParentProductCategoryID = c.ProductCategoryID
LEFT JOIN SalesLT.SalesOrderDetail AS sod
    ON p.ProductID = sod.ProductID
LEFT JOIN SalesLT.SalesOrderHeader AS soh
    ON sod.SalesOrderID = soh.SalesOrderID
GROUP BY
    p.ProductID,
    p.Name,
    ISNULL(c.Name, 'No Category');
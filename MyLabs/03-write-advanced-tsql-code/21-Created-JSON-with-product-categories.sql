USE [AdventureWorks2025];
GO

-- add category infor mation as a nested object
SELECT
    p.ProductID,
    p.Name AS ProductName,
    p.ListPrice,
    JSON_OBJECT(
        'CategoryID': pc.ProductCategoryID,
        'CategoryName': pc.Name
    ) AS Category
FROM SalesLT.Product AS p
INNER JOIN SalesLT.ProductCategory AS pc
    ON p.ProductCategoryID = pc.ProductCategoryID
ORDER BY p.ListPrice DESC
FOR JSON PATH;

-- This query uses JSON_OBJECT to build a nested structure.
-- The Category property contains its own JSON object with CategoryID and CategoryName. 
-- This approach keeps related data grouped together in the output.
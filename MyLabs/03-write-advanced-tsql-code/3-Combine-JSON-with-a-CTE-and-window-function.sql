USE [AdventureWorks2025];
GO

-- Write a CTE with window function ranking
WITH RankedProducts AS (
    SELECT
        p.ProductID,
        p.Name AS ProductName,
        pc.Name AS CategoryName,
        p.ListPrice,
        ROW_NUMBER() OVER (
            PARTITION BY pc.ProductCategoryID
            ORDER BY p.ListPrice DESC
        ) AS PriceRank
    FROM SalesLT.Product AS p
    INNER JOIN SalesLT.ProductCategory AS pc
        ON p.ProductCategoryID = pc.ProductCategoryID
    WHERE p.ListPrice > 0
)
SELECT
    ProductID,
    ProductName,
    CategoryName,
    ListPrice,
    PriceRank
FROM RankedProducts
WHERE PriceRank <= 3
ORDER BY CategoryName, PriceRank;

-- The CTE calculates a price rank for each product within its category. 
-- The PARTITION BY clause restarts the numbering for each category, and ORDER BY ListPrice DESC assigns rank 1 to the most expensive product. 
-- The outer query filters to show only the top 3 products per category.

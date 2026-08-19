USE [AdventureWorks2025];
GO

-- Create a JSON object for each product
-- This query selects products with a color value and formats the results as JSON array
-- The FOR JSON PATH clause handles the conversion automatically
SELECT
    ProductID,
    Name,
    Color,
    ListPrice
FROM SalesLT.Product
WHERE Color IS NOT NULL
ORDER BY ListPrice DESC
FOR JSON PATH;

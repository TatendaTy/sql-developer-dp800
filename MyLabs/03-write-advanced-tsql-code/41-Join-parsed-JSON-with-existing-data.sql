USE [AdventureWorks2025];
GO

-- Join parsed JSON with existing data
DECLARE @ProductUpdates NVARCHAR(MAX) = N'[
    {"ProductID": 680, "NewPrice": 1250.00 },
    {"ProductID": 706, "NewPrice": 1450.00 },
    {"ProductID": 707, "NewPrice": 38.99}
]';

SELECT
    p.ProductID,
    p.Name,
    p.ListPrice AS CurrentPrice,
    updates.NewPrice,
    updates.NewPrice - p.ListPrice AS PriceDifference
FROM SalesLT.Product AS p
INNER JOIN OPENJSON(@ProductUpdates)
WITH (
    ProductID INT '$.ProductID',
    NewPrice DECIMAL(10, 2) '$.NewPrice'
) AS updates
    ON p.ProductID = updates.ProductID;

-- This query joins the parsed JSON directly with the Product table.
-- The OPENJSON function with a WITH clause acts like a table, so you can join it just like any other data source.
-- The result shows each product's current price alongside the proposed new price.
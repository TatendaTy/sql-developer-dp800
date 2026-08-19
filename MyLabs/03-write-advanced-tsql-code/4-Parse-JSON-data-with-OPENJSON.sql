USE [AdventureWorks2025];
GO

-- Parse a JSON array into rows
DECLARE @ProductUpdates NVARCHAR(MAX) = N'[
    {"ProductID": 680, "NewPrice": 1250.00 },
    {"ProductID": 706, "NewPrice": 1450.00 },
    {"ProductID": 707, "NewPrice": 38.99}
]';

SELECT
    ProductID,
    NewPrice
FROM OPENJSON(@ProductUpdates)
WITH (
    ProductID INT '$.ProductID',
    NewPrice DECIMAL(10, 2) '$.NewPrice'
);

-- The WITH clause defines the schema for the output. Each JSON property maps to a column with a specified data type. 
-- The $.PropertyName syntax tells SQL Server which JSON path to read for each column.
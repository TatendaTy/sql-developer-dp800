USE AdventureWorks2025;
GO

/*
    ---------------------------------------------
    4. Search with vector similarity
    ---------------------------------------------

    Vector similarity search allows you to find rows that are semantically similar to a given query vector. 
    This is useful for scenarios like finding similar product reviews or recommendations based on content.
*/

-- 1. Use VECTOR_DISTANCE for exact nearest neighbor search. 
-- This option calculates the cosine distance between the query embedding and every review:
-- Exact vector search using VECTOR_DISTANCE
DECLARE @searchText NVARCHAR(1000) = 'comfortable seat for long distance touring';
DECLARE @searchVector VECTOR(1024);

SELECT @searchVector = AI_GENERATE_EMBEDDINGS(@searchText USE MODEL qwen3_embedding_0_6B);

SELECT TOP 5
    p.Name AS ProductName,
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    VECTOR_DISTANCE('cosine', @searchVector, r.ReviewVector) AS Distance
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
ORDER BY Distance;
GO

/*
Explanation:
VECTOR_DISTANCE calculates the cosine distance between two vectors: the query vector and the review vectors.
Lower values mean higher similarity. This function scans every row in the table, which works well for smaller datasets. 
Notice that the results include reviews about touring bikes and saddle comfort even if they do not contain the exact words "comfortable seat."
*/

-- 2. Use VECTOR_SEARCH with the DiskANN index for approximate nearest neighbor (ANN) search. 
-- This index is optimized for large datasets and provides faster results:
-- Approximate vector search using VECTOR_SEARCH with DiskANN index
DECLARE @searchText NVARCHAR(1000) = 'something to keep me visible when riding at night';
DECLARE @searchVector VECTOR(1024);

SELECT @searchVector = AI_GENERATE_EMBEDDINGS(@searchText USE MODEL qwen3_embedding_0_6B);

SELECT
    p.Name AS ProductName,
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    pc.Name AS Category,
    vs.distance AS Distance
FROM VECTOR_SEARCH(
    TABLE = dbo.ProductReview AS r,
    COLUMN = ReviewVector,
    SIMILAR_TO = @searchVector,
    METRIC = 'cosine',
    TOP_N = 5
) AS vs
INNER JOIN SalesLT.Product p 
    ON r.ProductID = p.ProductID
INNER JOIN SalesLT.ProductCategory pc 
    ON p.ProductCategoryID = pc.ProductCategoryID
ORDER BY vs.distance;
GO

/*
Explanation:
VECTOR_SEARCH uses the DiskANN index to find approximate nearest neighbors without scanning every row.
The query describes a concept ("visible when riding at night") rather than specific keywords. 
Vector search finds reviews about lights, reflective gear, and visibility even when those words do not appear in the search text.
*/

-- 3. Check vector metadata using VECTORPROPERTY:
-- Inspect vector metadata
SELECT TOP 1
    VECTORPROPERTY(ReviewVector, 'Dimensions') AS VectorDimensions,
    VECTORPROPERTY(ReviewVector, 'BaseType') AS VectorBaseType
FROM dbo.ProductReview
WHERE ReviewVector IS NOT NULL;
GO

/*
Explanation:
VECTORPROPERTY retrieves metadata about the vector column. 
This is useful for validating that your vectors have the expected number of dimensions and confirming the data type.
*/





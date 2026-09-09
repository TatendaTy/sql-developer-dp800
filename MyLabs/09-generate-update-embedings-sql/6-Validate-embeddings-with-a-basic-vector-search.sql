USE AdventureWorks2025;
GO

/* To confirm that the embeddings capture semantic meaning, run a basic vector similarity search using VECTOR_DISTANCE. 
This function calculates the cosine distance between two vectors, where smaller values indicate greater similarity.
*/

/* -------------------------------------------------
    1. Search for reviews similar to a natural language question:
   ------------------------------------------------- */
-- Find reviews semantically similar to a question
DECLARE @searchText NVARCHAR(1000) = 'Which tires last the longest and resist punctures?';
DECLARE @searchVector VECTOR(1024);

-- Generate an embedding for the search text
SELECT @searchVector = AI_GENERATE_EMBEDDINGS(@searchText USE MODEL qwen3_embedding_0_6B);

-- Find the 5 closest reviews by cosine distance
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

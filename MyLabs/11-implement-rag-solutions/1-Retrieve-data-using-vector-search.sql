USE AdventureWorks2025;
GO

/* 
    ------------------------------------------------
    Retrieve data using vector search and format it as JSON context
    ------------------------------------------------

    In this section, you practice the retrieval step of RAG. 
    Instead of using a hardcoded WHERE clause, you convert the user's question into an embedding and use VECTOR_SEARCH to find the most relevant reviews.
    Then you format the results as JSON.
*/

-- 1. Run the following query to use the VECTOR_SEARCH function for approximate nearest neighbor search. 
-- This function uses the DiskANN vector index for fast retrieval:

-- Convert a question to an embedding and find the closest matching reviews
DECLARE @userQuestion NVARCHAR(1000) = 'What mountain bike can handle really technical rocky trails?';
DECLARE @questionVector VECTOR(1024);

-- Generate embedding for the question
SELECT @questionVector = AI_GENERATE_EMBEDDINGS(@userQuestion USE MODEL qwen3_embedding_0_6B);

-- Find the top 5 most relevant reviews using ANN vector search
SELECT
    p.Name AS ProductName,
    p.ListPrice,
    pc.Name AS Category,
    r.Rating,
    r.ReviewTitle,
    r.ReviewText,
    vs.distance AS Distance
FROM VECTOR_SEARCH(
    TABLE = dbo.ProductReview AS r,
    COLUMN = ReviewVector,
    SIMILAR_TO = @questionVector,
    METRIC = 'cosine',
    TOP_N = 5
) AS vs
INNER JOIN SalesLT.Product p 
    ON r.ProductID = p.ProductID
INNER JOIN SalesLT.ProductCategory pc 
    ON p.ProductCategoryID = pc.ProductCategoryID
FOR JSON PATH;
GO

/*
    Explanation:
    ------------
    VECTOR_SEARCH performs an approximate nearest neighbor (ANN) search using the DiskANN vector index. 
    Unlike VECTOR_DISTANCE with ORDER BY (which scans every row), VECTOR_SEARCH navigates the graph index to find the closest matches efficiently.
    The distance column is automatically included in the results. 
    Lower distance values mean higher relevance. Notice how each review is unique.
    Unlike product descriptions where multiple sizes of the same bike share the same text, each review describes a distinct customer experience.
*/

USE AdventureWorks2025;
GO

/*
    To understand the strengths of each approach, run the same question through all three search methods and compare the results.
*/

-- 1. Run a full-text search for a comfortable family bike:
-- Full-text search only
SELECT TOP 5
    p.Name AS ProductName,
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    ft.[RANK] AS FullTextRank
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
INNER JOIN FREETEXTTABLE(dbo.ProductReview, (ReviewTitle, ReviewText), 
    'comfortable bike for long weekend rides with the family') AS ft
    ON r.ReviewID = ft.[KEY]
ORDER BY ft.[RANK] DESC;
GO

-- 2. Run a vector search for a comfortable family bike:
-- Vector search only
DECLARE @searchText NVARCHAR(1000) = 'comfortable bike for long weekend rides with the family';
DECLARE @searchVector VECTOR(1024);

SELECT @searchVector = AI_GENERATE_EMBEDDINGS(@searchText USE MODEL qwen3_embedding_0_6B);

SELECT
    p.Name AS ProductName,
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
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
ORDER BY vs.distance;
GO


-- 3. Run a hybrid search for a comfortable family bike:
-- Hybrid search with RRF
DECLARE @searchText NVARCHAR(1000) = 'comfortable bike for long weekend rides with the family';
DECLARE @searchVector VECTOR(1024);
DECLARE @topN INT = 50;
DECLARE @rrfK INT = 60;

SELECT @searchVector = AI_GENERATE_EMBEDDINGS(@searchText USE MODEL qwen3_embedding_0_6B);

WITH keyword_search AS (
    SELECT TOP(@topN)
        r.ReviewID,
        RANK() OVER (ORDER BY ft.[RANK] DESC) AS keyword_rank
    FROM dbo.ProductReview r
    INNER JOIN FREETEXTTABLE(dbo.ProductReview, (ReviewTitle, ReviewText), @searchText) AS ft
        ON r.ReviewID = ft.[KEY]
),
vector_search AS (
    SELECT TOP(@topN)
        ReviewID,
        RANK() OVER (ORDER BY distance) AS vector_rank
    FROM (
        SELECT 
            r.ReviewID,
            vs.distance
        FROM VECTOR_SEARCH(
            TABLE = dbo.ProductReview AS r,
            COLUMN = ReviewVector,
            SIMILAR_TO = @searchVector,
            METRIC = 'cosine',
            TOP_N = 50
        ) AS vs
    ) AS similar_reviews
),
combined AS (
    SELECT
        COALESCE(ks.ReviewID, vs.ReviewID) AS ReviewID,
        ks.keyword_rank,
        vs.vector_rank,
        COALESCE(1.0 / (@rrfK + ks.keyword_rank), 0.0) +
        COALESCE(1.0 / (@rrfK + vs.vector_rank), 0.0) AS rrf_score
    FROM keyword_search ks
    FULL OUTER JOIN vector_search vs ON ks.ReviewID = vs.ReviewID
)
SELECT TOP 5
    p.Name AS ProductName,
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    c.keyword_rank,
    c.vector_rank,
    c.rrf_score
FROM combined c
INNER JOIN dbo.ProductReview r ON c.ReviewID = r.ReviewID
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
ORDER BY c.rrf_score DESC;
GO

/*
 Compare the three result sets side by side. Full-text search returns reviews containing words like "comfortable," "weekend," and "family."
 Vector search returns reviews about recreational bikes, relaxed geometry, and leisure riding that might use different wording.
 Hybrid search combines both, giving higher scores to reviews that appear in both result sets.
 This comparison illustrates when each approach works best: full-text for exact keyword matches, vector for semantic similarity, and hybrid when you want the best of both.
*/

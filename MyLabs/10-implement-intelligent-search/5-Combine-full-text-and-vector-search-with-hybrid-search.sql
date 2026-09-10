USE AdventureWorks2025;
GO

/*
    ---------------------------------------------
    5. Combine full-text and vector search with hybrid search
    ---------------------------------------------

    Full-text search excels at finding exact keywords but misses documents that express the same idea differently.
    Vector search captures semantic meaning but might miss important terms the user specified.
    Hybrid search runs both approaches and merges the results using Reciprocal Rank Fusion (RRF).

    RRF combines ranked results from different sources by using rank positions instead of raw scores.
    The formula 1/(k + rank) converts ranks into scores, where k is a smoothing constant (typically 60). 
    Items appearing in both result sets get higher combined scores, pushing the most broadly relevant results to the top.
*/

-- 1. Run the following hybrid search query that combines full-text and vector search using RRF:
DECLARE @searchText NVARCHAR(1000) = 'durable tires that resist punctures on rough terrain';
DECLARE @searchVector VECTOR(1024);
DECLARE @topN INT = 50;
DECLARE @rrfK INT = 60;

-- Generate embedding for the search phrase
SELECT @searchVector = AI_GENERATE_EMBEDDINGS(@searchText USE MODEL qwen3_embedding_0_6B);

-- Run hybrid search with RRF
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
SELECT TOP 10
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
This query runs full-text and vector search in parallel using CTEs. 
The keyword_search CTE uses FREETEXTTABLE to rank reviews by BM25 relevance. 
The vector_search CTE uses VECTOR_SEARCH to rank reviews by embedding similarity. 
The combined CTE joins both result sets with a FULL OUTER JOIN and calculates the RRF score. 
Reviews that appear in both lists get higher combined scores. 
The final SELECT returns the top 10 results ordered by RRF score, showing which reviews performed well across both search methods.
*/

-- 2. Examine the output columns. Rows where both keyword_rank and vector_rank have values were found by both search methods and tend to have the highest RRF scores. 
-- Rows with a NULL in one rank column were found by only one method.
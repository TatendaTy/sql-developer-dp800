USE AdventureWorks2025;
GO

/* -------------------------------------------------
    1. Verify that every row now has a vector
   ------------------------------------------------- */
SELECT 
    COUNT(*) AS TotalReviews,
    COUNT(ReviewVector) AS ReviewsWithEmbedding,
    COUNT(*) - COUNT(ReviewVector) AS ReviewsMissingEmbedding
FROM dbo.ProductReview;
GO
-- Expected: ReviewsWithEmbedding = TotalReviews (should be 140)

/* -------------------------------------------------
    2. Inspect the vector dimensions and data type using VECTORPROPERTY
   ------------------------------------------------- */
-- Check vector metadata
SELECT TOP 1
    r.ReviewID,
    r.ReviewTitle,
    VECTORPROPERTY(r.ReviewVector, 'Dimensions') AS VectorDimensions,
    VECTORPROPERTY(r.ReviewVector, 'BaseType') AS VectorBaseType,
    DATALENGTH(r.ReviewVector) AS VectorSizeBytes
FROM dbo.ProductReview r
WHERE r.ReviewVector IS NOT NULL;
GO


/* -------------------------------------------------
    3. View a sample of actual vector values for a review:
   ------------------------------------------------- */
-- View a sample embedding
SELECT TOP 1
    r.ReviewID,
    r.ReviewTitle,
    LEFT(CAST(r.ReviewVector AS NVARCHAR(MAX)), 200) AS EmbeddingPreview
FROM dbo.ProductReview r
WHERE r.ReviewVector IS NOT NULL;
GO

    
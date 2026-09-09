USE [AdventureWorks2025];
GO

-- this step was already done in a previous script
-- Add a vector column to store review text embeddings
-- ALTER TABLE dbo.ProductReview
-- ADD ReviewVector VECTOR(1536);
-- GO


-- Test embedding generation for the review text
SELECT TOP 1
    r.ReviewID,
    r.ReviewTitle,
    AI_GENERATE_EMBEDDINGS(
        r.ReviewTitle + ': ' + r.ReviewText
        USE MODEL qwen3_embedding_0_6B
    ) AS TestEmbedding
FROM dbo.ProductReview r;
GO
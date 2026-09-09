USE AdventureWorks2025;
GO

/*
Embeddings are a snapshot of the source text at the time they were generated.
When the source text changes, the embedding becomes stale and no longer reflects the current content.
*/

-- 1. Pick a review and note its current embedding distance from a known query:
-- Check distance of a specific review before update
-- DECLARE @searchVector VECTOR(1024);
-- SELECT @searchVector = AI_GENERATE_EMBEDDINGS('warm winter cycling gloves' USE MODEL qwen3_embedding_0_6B);

-- SELECT
--     r.ReviewID,
--     r.ReviewTitle,
--     r.ReviewText,
--     VECTOR_DISTANCE('cosine', @searchVector, r.ReviewVector) AS DistanceBefore
-- FROM dbo.ProductReview r
-- WHERE r.ReviewID = 124;
-- GO

-- 2. Update the review text to something different. The embedding is now stale since it still reflects the original text:
-- Change the review text without updating the embedding
-- UPDATE dbo.ProductReview
-- SET ReviewText = 'These tires are the most puncture-resistant tires I have ever used. Over 3000 miles with zero flats on rough gravel roads.',
--     ReviewTitle = N'Indestructible tires'
-- WHERE ReviewID = 124;
-- GO

-- 3. Check the distance again. The embedding still reflects the old glove review, but the text is now about tires:
-- Check distance after text change (embedding is stale)
-- DECLARE @searchVector VECTOR(1024);
-- SELECT @searchVector = AI_GENERATE_EMBEDDINGS('warm winter cycling gloves' USE MODEL qwen3_embedding_0_6B);

-- SELECT
--     r.ReviewID,
--     r.ReviewTitle,
--     r.ReviewText,
--     VECTOR_DISTANCE('cosine', @searchVector, r.ReviewVector) AS DistanceAfterTextChange
-- FROM dbo.ProductReview r
-- WHERE r.ReviewID = 124;
-- GO


-- 4. Regenerate the embedding to match the updated text
-- UPDATE r
-- SET r.ReviewVector = AI_GENERATE_EMBEDDINGS(
--     p.Name + ' - ' + r.ReviewTitle + ': ' + r.ReviewText
--     USE MODEL qwen3_embedding_0_6B)
-- FROM dbo.ProductReview r
-- INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
-- WHERE r.ReviewID = 124;
-- GO

-- 5. Verify the distance now reflects the updated content
--Check distance after embedding regeneration
-- DECLARE @searchVector VECTOR(1024);
-- SELECT @searchVector = AI_GENERATE_EMBEDDINGS('warm winter cycling gloves' USE MODEL qwen3_embedding_0_6B);

-- SELECT
--     r.ReviewID,
--     r.ReviewTitle,
--     r.ReviewText,
--     VECTOR_DISTANCE('cosine', @searchVector, r.ReviewVector) AS DistanceAfterRegeneration
-- FROM dbo.ProductReview r
-- WHERE r.ReviewID = 124;
-- GO

-- 6. Restore the original review text and regenerate the embedding
UPDATE dbo.ProductReview
SET ReviewTitle = N'Warm hands well below freezing',
    ReviewText = N'Rode through an entire winter with the Full-Finger Gloves and never had cold fingers even at minus 5 degrees with wind chill. The fleece lining is cozy without being bulky and I can still operate my brake levers precisely. Essential cold weather gear.'
WHERE ReviewID = 124;
GO

-- Regenerate the embedding for the restored text
UPDATE r
SET r.ReviewVector = AI_GENERATE_EMBEDDINGS(
    p.Name + ' - ' + r.ReviewTitle + ': ' + r.ReviewText
    USE MODEL qwen3_embedding_0_6B)
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
WHERE r.ReviewID = 124;
GO





USE AdventureWorks2025;
GO

/* -------------------------------------------------
   1️⃣  Add the vector column if it isn’t already there
   ------------------------------------------------- */
IF COL_LENGTH('dbo.ProductReview','ReviewVector') IS NOT NULL
BEGIN
    -- Drop the old column first
    ALTER TABLE dbo.ProductReview DROP COLUMN ReviewVector;
    PRINT 'Dropped existing ReviewVector column.';
END
GO


ALTER TABLE dbo.ProductReview
ADD ReviewVector VECTOR(1024) NULL;   -- 1024‑dim float vector (matches qwen3‑embedding:0.6b)
GO

-- Generate embeddings for all rows in the ProductReview table
DECLARE @batchSize INT = 30;
DECLARE @rowsUpdated INT = 1;
DECLARE @retryCount INT;
DECLARE @maxRetries INT = 3;

WHILE @rowsUpdated > 0
BEGIN
    SET @retryCount = 0;

    RETRY:
    BEGIN TRY
        UPDATE TOP (@batchSize) r
        SET r.ReviewVector = AI_GENERATE_EMBEDDINGS(
            p.Name + ' - ' + r.ReviewTitle + ': ' + r.ReviewText
            USE MODEL qwen3_embedding_0_6B)
        FROM dbo.ProductReview r
        INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
        WHERE r.ReviewVector IS NULL;

        SET @rowsUpdated = @@ROWCOUNT;

        -- Brief pause between batches to respect API rate limits
        IF @rowsUpdated > 0
            WAITFOR DELAY '00:00:02';
    END TRY
    BEGIN CATCH
        SET @retryCount += 1;
        IF @retryCount <= @maxRetries
        BEGIN
            PRINT 'Rate limited. Retrying in 5 seconds... (Attempt ' 
                + CAST(@retryCount AS NVARCHAR(10)) + ' of ' 
                + CAST(@maxRetries AS NVARCHAR(10)) + ')';
            WAITFOR DELAY '00:00:05';
            GOTO RETRY;
        END
        ELSE
            THROW;
    END CATCH
END
GO

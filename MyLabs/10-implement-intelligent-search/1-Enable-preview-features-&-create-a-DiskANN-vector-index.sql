USE AdventureWorks2025;
GO

-- Enable preview features required for vector indexes
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

-- leave commented out, this feature doesnt exist on local sql server 2025
-- Allow the table to remain writable after vector index creation
-- ALTER DATABASE SCOPED CONFIGURATION SET ALLOW_STALE_VECTOR_INDEX = ON;
-- GO

-- Create a DiskANN vector index for fast approximate nearest neighbor search
CREATE VECTOR INDEX IX_Review_ReviewVector
ON dbo.ProductReview(ReviewVector)
WITH (METRIC = 'cosine', TYPE = 'DISKANN');
GO

-- Verify the index exists
SELECT *
FROM sys.vector_indexes
WHERE object_id = OBJECT_ID('dbo.ProductReview');
GO
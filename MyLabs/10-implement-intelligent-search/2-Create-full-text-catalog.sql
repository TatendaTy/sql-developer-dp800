USE AdventureWorks2025;
GO

/*
    ---------------------------------------------
    1. Create a full-text catalog for the ProductReview table
    ---------------------------------------------
*/

-- Create a full-text catalog
CREATE FULLTEXT CATALOG ProductReviewCatalog AS DEFAULT;
GO

-- Create a full-text index on ReviewTitle and ReviewText
CREATE FULLTEXT INDEX ON dbo.ProductReview
(
    ReviewTitle LANGUAGE 1033,
    ReviewText LANGUAGE 1033
)
KEY INDEX PK_ProductReview
ON ProductReviewCatalog
WITH (CHANGE_TRACKING AUTO);
GO

/*
    ---------------------------------------------
    2. Verify the full-text index creation
    ---------------------------------------------
*/
-- Check full-text index status
SELECT 
    OBJECTPROPERTY(OBJECT_ID('dbo.ProductReview'), 'TableFullTextPopulateStatus') AS PopulateStatus,
    OBJECTPROPERTY(OBJECT_ID('dbo.ProductReview'), 'TableHasActiveFulltextIndex') AS HasActiveIndex;
GO

-- NB* A PopulateStatus of 0 means the full-text index is fully populated and ready for queries. 
-- A value of 1 means population is still in progress. 
-- HasActiveIndex should be 1.
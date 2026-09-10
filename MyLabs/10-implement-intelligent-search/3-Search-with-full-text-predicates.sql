USE AdventureWorks2025;
GO

/*
    ---------------------------------------------
    3. Search with full-text predicates
    ---------------------------------------------

    Full-text search uses predicates like CONTAINS and FREETEXT to query the full-text index. 
    CONTAINS looks for exact words or phrases. 
    FREETEXT matches word forms and inflections automatically.
*/

-- 1. Use CONTAINS to search for reviews mentioning a specific word:
-- Find reviews that contain the word "puncture"
SELECT 
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    p.Name AS ProductName
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
WHERE CONTAINS(r.ReviewText, 'puncture');
GO

-- 2. Use FREETEXT to search for a phrase. 
-- FREETEXT automatically expands search terms to include inflectional forms:
-- Find reviews about gloves and warmth
SELECT TOP 10
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    p.Name AS ProductName
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
WHERE FREETEXT(r.ReviewText, 'warm gloves for cold winter commuting');
GO

/*
FREETEXT handles inflections, so "warm" can match "warmth" or "warming," and "commuting" can match "commute" or "commuter." 
It also drops stopwords like "for" and "the." Compare this to CONTAINS, which would require you to specify each word form explicitly. 
Use TOP with FREETEXT since broad phrases can match many rows.
*/

-- 3. Use CONTAINSTABLE to get ranked results with relevance scores:
-- Search with ranking scores
SELECT TOP 10
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    p.Name AS ProductName,
    ft.[RANK] AS FullTextRank
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
INNER JOIN CONTAINSTABLE(dbo.ProductReview, (ReviewTitle, ReviewText), 
    'FORMSOF(INFLECTIONAL, mountain) AND FORMSOF(INFLECTIONAL, trail)') AS ft
    ON r.ReviewID = ft.[KEY]
ORDER BY ft.[RANK] DESC;
GO

/*
CONTAINSTABLE returns a table with a KEY column (matching the primary key) and a RANK column indicating how well each row matches. 
FORMSOF(INFLECTIONAL, mountain) matches "mountain," "mountains," and other inflected forms. The AND operator requires both terms to appear.
*/

-- 4. Use a prefix search to find reviews where words start with specific characters:
-- Find reviews with words starting with "comfort"
SELECT 
    r.ReviewTitle,
    r.ReviewText,
    r.Rating,
    p.Name AS ProductName
FROM dbo.ProductReview r
INNER JOIN SalesLT.Product p ON r.ProductID = p.ProductID
WHERE CONTAINS(r.ReviewText, '"comfort*"');
GO

/*
Prefix searches are useful when you want to find words that start with a specific sequence of characters. 
In this example, '"comfort*"' will match "comfortable," "comfortably," and any other words starting with "comfort."
*/








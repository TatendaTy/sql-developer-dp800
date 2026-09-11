USE AdventureWorks2025;
GO

/*
    Combine retrieved data with a system message and user question to build the augmented prompt.
    This prompt is the "A" in RAG.
*/

-- 1.  build a complete RAG prompt in T-SQL. 
-- This script uses vector search to retrieve relevant reviews, then builds the augmented prompt:
DECLARE @userQuestion NVARCHAR(1000) = 'What is the best bike for commuting to work in rainy weather?';
DECLARE @questionVector VECTOR(1024);
DECLARE @context NVARCHAR(MAX);
DECLARE @payload NVARCHAR(MAX);

-- Step 1: Convert the question to an embedding
SELECT @questionVector = AI_GENERATE_EMBEDDINGS(@userQuestion USE MODEL qwen3_embedding_0_6B);

-- Step 2: Retrieve relevant reviews using ANN vector search
SET @context = (
    SELECT
        p.Name AS ProductName,
        p.ListPrice,
        pc.Name AS Category,
        r.Rating,
        r.ReviewTitle,
        r.ReviewText
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
    FOR JSON PATH
);

-- Step 3: Build augmented prompt using JSON_OBJECT and JSON_ARRAY
SET @payload = JSON_OBJECT(
    'messages': JSON_ARRAY(
        JSON_OBJECT(
            'role': 'system', 
            'content': 'You are an Adventure Works product assistant. Answer questions using only the provided product reviews and data. Mention specific customer experiences from the reviews when relevant. Be concise and helpful. If the data does not contain enough information, say so.'
        ),
        JSON_OBJECT(
            'role': 'user', 
            'content': 'Product reviews: ' + ISNULL(@context, '[]') + CHAR(10) + CHAR(10) + 'Customer question: ' + @userQuestion
        )
    ),
    'max_tokens': CAST(500 AS INT),
    'temperature': 0.5
);

-- Display the constructed payload
SELECT @payload AS AugmentedPrompt;
GO

/*
    This script demonstrates how to implement a Retrieval-Augmented Generation (RAG) solution in T-SQL.
    Steps:
    1. Convert the user's question into an embedding vector.
    2. Perform a vector search to retrieve relevant product reviews.
    3. Construct an augmented prompt combining the retrieved reviews and the user's question.
    4. The resulting payload can be used with an AI model to generate a response.
*/


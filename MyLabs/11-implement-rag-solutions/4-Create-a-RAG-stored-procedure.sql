USE AdventureWorks2025;
GO

/* -------------------------------------------------
   4. Create a RAG (Retrieval-Augmented Generation) stored procedure
   ------------------------------------------------- 
    
   Put it all together in a reusable stored procedure that your application can call.
*/

-- 1.  create the stored procedure
CREATE OR ALTER PROCEDURE dbo.AskProductQuestion
    @Question NVARCHAR(1000),
    @Answer NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @questionVector VECTOR(1024);
    DECLARE @context NVARCHAR(MAX);
    DECLARE @payload NVARCHAR(MAX);
    DECLARE @response NVARCHAR(MAX);
    DECLARE @returnValue INT;

    -- Step 1: Convert the question to an embedding
    SELECT @questionVector = AI_GENERATE_EMBEDDINGS(@Question USE MODEL qwen3_embedding_0_6B);

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

    -- Check if context was retrieved
    IF @context IS NULL
    BEGIN
        SET @Answer = 'No reviews found matching your query. Please try a different question.';
        RETURN;
    END

    -- Step 3: Build the augmented prompt
    SET @payload = JSON_OBJECT(
        'model': 'qwen2.5-coder:1.5b',                -- must match the model you pulled with Ollama
        'messages': JSON_ARRAY(
            JSON_OBJECT(
                'role': 'system', 
                'content': 'You are an Adventure Works product assistant. Follow these rules:
                    1. Answer only using the provided product reviews and data
                    2. Reference specific customer experiences from the reviews when relevant
                    3. Include star ratings to help the customer assess product quality
                    4. Keep responses under 150 words
                    5. Suggest related products when relevant'
            ),
            JSON_OBJECT(
                'role': 'user', 
                'content': 'Product reviews: ' + @context + CHAR(10) + CHAR(10) + 'Customer question: ' + @Question
            )
        ),
        'stream': CAST(0 AS bit),                 -- JSON bool, not an escaped string
        'options': JSON_OBJECT(
            'temperature': 0.5,
            'num_predict': 500                     -- max tokens Ollama should generate
        )
    );

    -- Step 4: Call the model

    /* -------------------------------------------------
    Step 4: Call the local Ollama chat model via ngrok
    ------------------------------------------------- */
    DECLARE @CredentialName sysname = N'${NGROK_URL}';

    EXECUTE @returnValue = sp_invoke_external_rest_endpoint
        @url = N'${OLLAMA_CHAT_URL}',
        @method = 'POST',
        @payload = @payload,
        @credential = @CredentialName,
        @response = @response OUTPUT;

    -- Step 5: Extract the answer or handle errors
    IF @returnValue = 0
        SET @Answer = JSON_VALUE(@response, '$.result.choices[0].message.content');
    ELSE IF @returnValue = 429
        SET @Answer = 'The service is currently busy. Please try again in a moment.';
    ELSE IF @returnValue IN (401, 403)
        SET @Answer = 'Authentication failed. Please check the credential configuration.';
    ELSE
        SET @Answer = 'Unable to process your question at this time. HTTP status: ' + CAST(@returnValue AS NVARCHAR(10));
END;
GO

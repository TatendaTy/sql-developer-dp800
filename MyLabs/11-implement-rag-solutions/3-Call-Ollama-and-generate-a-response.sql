USE AdventureWorks2025;
GO

/*
    This script demonstrates how to call the Ollama API and generate a response using the augmented prompt constructed in the previous step.
*/

-- 1. Complete the full RAG pipeline
DECLARE @userQuestion NVARCHAR(1000) = 'Which tires last the longest and resist punctures?';
DECLARE @questionVector VECTOR(1024);
DECLARE @context NVARCHAR(MAX);
DECLARE @payload NVARCHAR(MAX);
DECLARE @response NVARCHAR(MAX);
DECLARE @returnValue INT;

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

/* -------------------------------------------------
   Step 3: Build the augmented prompt for Ollama chat
   ------------------------------------------------- */
SET @payload = JSON_OBJECT(
    'model': 'qwen2.5-coder:1.5b',                -- must match the model you pulled with Ollama
    'messages': JSON_ARRAY(
        JSON_OBJECT(
            'role': 'system',
            'content': 
                'You are an Adventure Works product assistant. ' +
                'Answer only using the provided product reviews and data. ' +
                'Reference specific customer experiences from the reviews when relevant. ' +
                'Be concise and helpful. If the data does not contain enough information, say so.'
        ),
        JSON_OBJECT(
            'role': 'user',
            'content': 
                'Product reviews: ' + ISNULL(@context, '[]') + CHAR(10) + CHAR(10) +
                'Customer question: ' + @userQuestion
        )
    ),
    'stream': CAST(0 AS bit),                 -- JSON bool, not an escaped string
    'options': JSON_OBJECT(
        'temperature': 0.5,
        'num_predict': 500                     -- max tokens Ollama should generate
    )
);

/* -------------------------------------------------
   Step 4: Call the local Ollama chat model via ngrok
   ------------------------------------------------- */
DECLARE @CredentialName sysname = N'https://exporter-valley-giddily.ngrok-free.dev';

-- You must grant REFERENCES permission on the credential to the user that runs this code.
-- If you want to be explicit, replace [public] with your SQL user or role.
GRANT REFERENCES ON DATABASE SCOPED CREDENTIAL::[https://exporter-valley-giddily.ngrok-free.dev] TO [public];

EXECUTE @returnValue = sp_invoke_external_rest_endpoint
    @url = N'https://exporter-valley-giddily.ngrok-free.dev/api/chat',         -- Ollama chat endpoint (ngrok HTTPS)
    @method = 'POST',
    @payload = @payload,
    @credential = @CredentialName,
    @response = @response OUTPUT;

/* -------------------------------------------------
   Step 5: Extract the answer or surface an error
   ------------------------------------------------- */
IF @returnValue = 0
BEGIN
    DECLARE @answer NVARCHAR(MAX);
    -- sp_invoke_external_rest_endpoint wraps the HTTP result in a top-level "result" object.
    -- Some Ollama responses may also come back without the wrapper; use both paths.
    SET @answer = COALESCE(
        JSON_VALUE(@response, '$.message.content'),
        JSON_VALUE(@response, '$.result.message.content')
    );
END
ELSE
BEGIN
    SET @answer = 
        'Error calling local Ollama model. HTTP status: ' + CAST(@returnValue AS NVARCHAR(10)) + 
        '. Response: ' + ISNULL(@response, '(no response)');
END

USE AdventureWorks2025;
GO

-- Test the AskProductQuestion stored procedure
DECLARE @response NVARCHAR(MAX);

EXEC dbo.AskProductQuestion
    @Question = 'I ride before sunrise and after dark. What lights actually work well?',
    @Answer = @response OUTPUT;

SELECT @response AS AssistantResponse;
GO


-- Try a question about bike maintenance:
DECLARE @response NVARCHAR(MAX);

EXEC dbo.AskProductQuestion
    @Question = 'How do I keep my bike maintained between shop visits?',
    @Answer = @response OUTPUT;

SELECT @response AS AssistantResponse;
GO

-- Test with a question about common complaints:
DECLARE @response NVARCHAR(MAX);

EXEC dbo.AskProductQuestion
    @Question = 'What are the most common problems or complaints people have with their bikes?',
    @Answer = @response OUTPUT;

SELECT @response AS AssistantResponse;
GO

/*
Each call follows the same RAG pattern: 
    - convert the question to an embedding, 
    - use VECTOR_SEARCH with the DiskANN index to retrieve the most relevant reviews from the database, 
    - augment the prompt with that data, and generate a grounded response. 
The model's answers should reference specific customer experiences from the reviews. 
Notice how vector search finds relevant reviews based on semantic meaning. 
For example, a question about "problems" retrieves low-rated reviews mentioning specific issues.
*/


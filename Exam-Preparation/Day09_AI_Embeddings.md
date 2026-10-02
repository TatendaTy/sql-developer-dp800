# Day 9: AI - Models, Embeddings & Intelligent Search

**Date:** September 30, 2026 | **Exam Weight:** 25-30% (Implement AI Capabilities)

---

## Learning Objectives

- [ ] External models: multimodal, multilanguage, sizes, structured output
- [ ] Create/manage external models (sp_create_external_model)
- [ ] Embedding maintenance: triggers, Change Tracking, Azure Functions, CDC, Foundry
- [ ] Chunking strategies for embeddings
- [ ] Vector data type, indexes (IVF, HNSW), VECTOR_NORMALIZE, VECTOR_DISTANCE
- [ ] Full-text, semantic vector, hybrid search
- [ ] ANN vs KNN, RRF (Reciprocal Rank Fusion)
- [ ] VECTOR_SEARCH, VECTORPROPERTY functions

---

## Core Concepts

### 1. External Models

```sql
-- Create external model (Azure OpenAI, etc.)
EXEC sp_create_external_model
    @model = 'text-embedding-3-small',
    @provider = 'AzureOpenAI',
    @connection_string = '{"endpoint": "https://myopenai.openai.azure.com/", "api_key": "..."}',
    @parameters = '{"model": "text-embedding-3-small", "dimensions": 1536}';

-- Create external model for chat completion
EXEC sp_create_external_model
    @model = 'gpt-4o',
    @provider = 'AzureOpenAI',
    @connection_string = '{"endpoint": "https://myopenai.openai.azure.com/", "api_key": "..."}',
    @parameters = '{"model": "gpt-4o", "max_tokens": 4096, "temperature": 0.7}';

-- List external models
SELECT * FROM sys.external_models;

-- Drop external model
EXEC sp_drop_external_model @model = 'text-embedding-3-small';
```

**Model Providers:**
| Provider | Models | Use Case |
|----------|--------|----------|
| `AzureOpenAI` | GPT-4o, GPT-4, embeddings | Enterprise, compliance |
| `OpenAI` | GPT-4o, embeddings | General purpose |
| `HuggingFace` | Open-source models | Custom, on-prem |
| `Ollama` | Local models | Privacy, offline |

---

### 2. Vector Data Type & Storage

```sql
-- Create table with vector column (SQL Server 2025 / Azure SQL)
CREATE TABLE Documents (
    DocID INT IDENTITY PRIMARY KEY,
    Title NVARCHAR(200),
    Content NVARCHAR(MAX),
    Embedding VECTOR(1536),  -- 1536 dimensions for text-embedding-3-small
    ChunkIndex INT,
    SourceDocID INT,
    CreatedDate DATETIME2 DEFAULT SYSUTCDATETIME()
);

-- Vector index: HNSW (approximate nearest neighbor - ANN)
CREATE INDEX IX_Documents_Embedding_HNSW
ON Documents (Embedding)
USING HNSW
WITH (M = 16, efConstruction = 64, efSearch = 40);

-- Vector index: IVF (inverted file - also ANN)
CREATE INDEX IX_Documents_Embedding_IVF
ON Documents (Embedding)
USING IVF
WITH (nlist = 100, nprobe = 10);

-- KNN (exact nearest neighbor) - no index needed, uses brute force
-- SELECT TOP 10 * FROM Documents ORDER BY VECTOR_DISTANCE(Embedding, @query) ASC;
```

**HNSW vs IVF:**
| Aspect | HNSW | IVF |
|--------|------|-----|
| Search Speed | Faster | Slower |
| Recall | Higher | Lower (tunable via nprobe) |
| Build Time | Longer | Faster |
| Memory | Higher | Lower |
| Best For | Low latency, high recall | Large datasets, memory constrained |

---

### 3. Vector Functions

```sql
-- VECTOR_DISTANCE - cosine similarity (default) or Euclidean
DECLARE @queryVector VECTOR(1536) = CAST(@embedding AS VECTOR(1536));

-- Cosine distance (0 = identical, 2 = opposite)
SELECT TOP 10 DocID, Title, VECTOR_DISTANCE(Embedding, @queryVector) AS Distance
FROM Documents
ORDER BY Distance ASC;

-- Euclidean distance
SELECT TOP 10 DocID, VECTOR_DISTANCE(Embedding, @queryVector, 'euclidean') AS Dist
FROM Documents ORDER BY Dist ASC;

-- VECTOR_NORMALIZE - normalize to unit length
UPDATE Documents SET Embedding = VECTOR_NORMALIZE(Embedding);
-- Or in query
SELECT VECTOR_DISTANCE(VECTOR_NORMALIZE(Embedding), VECTOR_NORMALIZE(@queryVector)) ...

-- VECTORPROPERTY - metadata about vector
SELECT VECTORPROPERTY(Embedding, 'Dimension') AS Dim,  -- 1536
       VECTORPROPERTY(Embedding, 'Norm') AS Norm;      -- Should be 1.0 if normalized

-- VECTOR_SEARCH (SQL Server 2025) - optimized ANN search
SELECT * FROM VECTOR_SEARCH(
    TABLE Documents,
    COLUMN Embedding,
    QUERY @queryVector,
    TOP 10,
    OPTIONS '{"metric": "cosine", "efSearch": 40}'
);
```

---

### 4. Embedding Generation & Maintenance

```sql
-- Generate embeddings via external model
DECLARE @embedding VECTOR(1536);
EXEC sp_invoke_external_model
    @model = 'text-embedding-3-small',
    @input = 'Your text to embed',
    @output = @embedding OUTPUT;

-- Batch embedding generation (application side)
-- 1. Read text chunks from DB
-- 2. Call embedding API in batches
-- 3. Update Embedding column

-- Maintenance Strategies:

-- A) Trigger-based (real-time)
CREATE TRIGGER trg_Documents_Embedding
ON Documents
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Content) OR UPDATE(Title)
    BEGIN
        DECLARE @text NVARCHAR(MAX);
        SELECT @text = COALESCE(Title, '') + ' ' + Content FROM inserted;

        DECLARE @embedding VECTOR(1536);
        EXEC sp_invoke_external_model
            @model = 'text-embedding-3-small',
            @input = @text,
            @output = @embedding OUTPUT;

        UPDATE Documents
        SET Embedding = @embedding
        WHERE DocID = (SELECT DocID FROM inserted);
    END
END;

-- B) Change Tracking (batch job)
-- Enable CT on table
ALTER TABLE Documents ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

-- Batch job (Azure Function / SQL Agent)
DECLARE @last_version BIGINT = (SELECT last_version FROM EmbeddingSyncState);
SELECT DocID, Content FROM Documents
WHERE CHANGE_TRACKING_IS_COLUMN_IN_MASK(
    COLUMNPROPERTY(OBJECT_ID('Documents'), 'Content', 'ColumnId'),
    (SELECT SYS_CHANGE_COLUMNS FROM CHANGETABLE(CHANGES Documents, @last_version) WHERE DocID = Documents.DocID)
) = 1;

-- Update embeddings, then update sync state
UPDATE EmbeddingSyncState SET last_version = CHANGE_TRACKING_CURRENT_VERSION();

-- C) Azure Functions with SQL Trigger (real-time, serverless)
-- function.json with sqlTrigger on Documents table
-- Function calls embedding API, updates Embedding column

-- D) CDC (full history, for audit)
EXEC sys.sp_cdc_enable_table @source_schema='dbo', @source_name='Documents', @supports_net_changes=1;
-- Read from cdc.fn_cdc_get_net_changes_dbo_Documents

-- E) Microsoft Foundry (MLOps pipeline)
-- Use Azure ML / Foundry for model training, deployment, monitoring
-- Not T-SQL based; external pipeline
```

---

### 5. Chunking Strategies

```sql
-- Chunking large documents for embedding
-- Strategy 1: Fixed size with overlap
-- Application side: split text into 512-token chunks with 50-token overlap

-- Strategy 2: Semantic chunking (by heading/paragraph)
-- Use document structure: split on \n\n, headings, sections

-- Strategy 3: Recursive character splitting
-- Split by separators: ["\n\n", "\n", ". ", " ", ""]

-- Store chunks
CREATE TABLE DocumentChunks (
    ChunkID INT IDENTITY PRIMARY KEY,
    DocID INT NOT NULL REFERENCES Documents(DocID),
    ChunkIndex INT NOT NULL,
    Content NVARCHAR(MAX) NOT NULL,
    TokenCount INT,
    Embedding VECTOR(1536),
    CreatedDate DATETIME2 DEFAULT SYSUTCDATETIME()
);

-- Query: Find relevant chunks, then aggregate by document
SELECT TOP 5 DocID,
       STRING_AGG(Content, ' ... ') WITHIN GROUP (ORDER BY ChunkIndex) AS Context
FROM DocumentChunks
WHERE VECTOR_DISTANCE(Embedding, @queryVector) < 0.3
GROUP BY DocID;
```

**Chunking Best Practices:**
| Strategy | Chunk Size | Overlap | Use Case |
|----------|------------|---------|----------|
| Fixed | 512 tokens | 50 tokens | General purpose |
| Semantic | Variable | 0 | Structured docs (markdown, HTML) |
| Recursive | 1000 chars | 200 chars | Unstructured text |
| Sentence | 3-5 sentences | 1 sentence | Narrative text |

---

### 6. Full-Text Search

```sql
-- Enable full-text
CREATE FULLTEXT CATALOG ftCatalog AS DEFAULT;

CREATE FULLTEXT INDEX ON Documents (Title, Content)
KEY INDEX PK_Documents
ON ftCatalog
WITH CHANGE_TRACKING AUTO;

-- Full-text queries
SELECT * FROM Documents
WHERE CONTAINS(Content, '"machine learning"');  -- Exact phrase

SELECT * FROM Documents
WHERE CONTAINS(Content, 'machine NEAR learning');  -- Proximity

SELECT * FROM Documents
WHERE FREETEXT(Content, 'AI artificial intelligence');  -- Inflectional

-- Full-text with ranking
SELECT DocID, Title, RANK
FROM Documents
JOIN FREETEXTTABLE(Documents, Content, 'machine learning') AS FT
ON Documents.DocID = FT.[KEY]
ORDER BY RANK DESC;
```

---

### 7. Hybrid Search (Vector + Full-Text + RRF)

```sql
-- Reciprocal Rank Fusion (RRF)
-- Combines multiple ranked lists into single ranking
-- Score = sum(1 / (rank + k)) where k=60 (default)

WITH VectorResults AS (
    SELECT DocID, VECTOR_DISTANCE(Embedding, @queryVector) AS Distance,
           ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE(Embedding, @queryVector)) AS Rank
    FROM Documents
),
FullTextResults AS (
    SELECT DocID, RANK AS FTRank,
           ROW_NUMBER() OVER (ORDER BY RANK DESC) AS Rank
    FROM FREETEXTTABLE(Documents, (Title, Content), @queryText)
),
RRF AS (
    SELECT DocID,
           SUM(1.0 / (Rank + 60)) AS RRFScore
    FROM (
        SELECT DocID, Rank FROM VectorResults
        UNION ALL
        SELECT DocID, Rank FROM FullTextResults
    ) Combined
    GROUP BY DocID
)
SELECT TOP 10 D.DocID, D.Title, D.Content, R.RRFScore
FROM RRF R
JOIN Documents D ON R.DocID = D.DocID
ORDER BY R.RRFScore DESC;

-- Alternative: Weighted combination
SELECT TOP 10 DocID, Title,
       0.7 * (1 - VECTOR_DISTANCE(Embedding, @queryVector)) + 0.3 * FT_RANK AS HybridScore
FROM Documents D
JOIN FREETEXTTABLE(Documents, Content, @queryText) FT ON D.DocID = FT.[KEY]
ORDER BY HybridScore DESC;
```

---

### 8. Search Evaluation

```sql
-- Evaluate search quality
-- Metrics: Recall@K, Precision@K, MRR, NDCG

-- Recall@10: % of relevant docs in top 10
-- Precision@10: % of top 10 that are relevant
-- MRR: Mean Reciprocal Rank (1/rank of first relevant)
-- NDCG: Normalized Discounted Cumulative Gain

-- Test queries with known relevant docs
CREATE TABLE SearchTestQueries (
    QueryID INT IDENTITY PRIMARY KEY,
    QueryText NVARCHAR(500),
    RelevantDocIDs NVARCHAR(MAX)  -- JSON array of relevant DocIDs
);

-- Evaluation procedure
CREATE PROCEDURE usp_EvaluateSearch @QueryID INT
AS
BEGIN
    DECLARE @queryText NVARCHAR(500), @relevant NVARCHAR(MAX);
    SELECT @queryText = QueryText, @relevant = RelevantDocIDs FROM SearchTestQueries WHERE QueryID = @QueryID;

    -- Run vector search
    DECLARE @queryVector VECTOR(1536);
    EXEC sp_invoke_external_model @model='text-embedding-3-small', @input=@queryText, @output=@queryVector OUTPUT;

    -- Get top 10
    SELECT TOP 10 DocID INTO #Results FROM Documents
    ORDER BY VECTOR_DISTANCE(Embedding, @queryVector);

    -- Calculate metrics (simplified)
    -- Compare #Results with @relevant
END;
```

---

## Hands-On Labs

Run these from `MyLabs/09-generate-update-embedings-sql/` and `MyLabs/10-implement-intelligent-search/`:

```bash
# Review all files in these folders
```

**Practice Exercises:**

1. Create table with VECTOR(1536) column
2. Create HNSW index on vector column
3. Generate embeddings using sp_invoke_external_model
4. Implement vector search with VECTOR_DISTANCE
5. Implement hybrid search with RRF
6. Compare ANN (HNSW) vs KNN performance

---

## Practice Questions

### Question 1

HNSW index parameters: `M = 16, efConstruction = 64`. What does M control?

A) Number of connections per node (graph degree)
B) Search depth
C) Number of clusters
D) Memory limit

**Answer: A** - M = max connections per node in HNSW graph (typically 16-48).

### Question 2

`VECTOR_DISTANCE` with default metric returns cosine distance. Range?

A) -1 to 1
B) 0 to 1
C) 0 to 2
D) -1 to 0

**Answer: C** - Cosine distance = 1 - cosine_similarity; range [0, 2]. 0 = identical.

### Question 3

RRF formula: `sum(1 / (rank + k))`. Default k?

A) 10
B) 60
C) 100
D) 1

**Answer: B** - k=60 is standard RRF default (from original paper).

### Question 4

Which embedding maintenance method provides REAL-TIME updates with serverless scaling?

A) Trigger
B) Change Tracking + SQL Agent
C) Azure Functions SQL Trigger
D) CDC

**Answer: C** - Azure Functions with SQL trigger binding scales automatically, near real-time.

### Question 5

Full-text search: `CONTAINS(Content, 'machine NEAR learning')` finds?

A) Documents with both words anywhere
B) Documents where words are within ~50 terms
C) Exact phrase "machine learning"
D) Words with same root (stemming)

**Answer: B** - NEAR finds terms in proximity (configurable distance, default ~50).

---

## Exam Tricks & Gotchas

| Topic                        | Trick/Gotcha                                                                                   |
| ---------------------------- | ---------------------------------------------------------------------------------------------- |
| **Vector Type**              | `VECTOR(n)` where n = dimensions; must match embedding model (1536 for text-embedding-3-small) |
| **HNSW**                     | `efSearch` at query time (default 40); higher = better recall, slower                          |
| **IVF**                      | `nprobe` at query time; more probes = better recall                                            |
| **Normalization**            | Always normalize embeddings for cosine distance; `VECTOR_NORMALIZE()`                          |
| **Chunking**                 | Overlap prevents context loss at boundaries; 10-15% overlap typical                            |
| **RRF**                      | k=60; works with any number of rankers; no score normalization needed                          |
| **sp_invoke_external_model** | Async; use OUTPUT parameter; handle errors                                                     |
| **External Model**           | Connection string in JSON; store secrets in Key Vault, reference via @env()                    |
| **VECTOR_SEARCH**            | New in SQL 2025; optimized ANN; replaces manual ORDER BY VECTOR_DISTANCE                       |
| **Evaluation**               | Need ground truth (labeled relevant docs) for Recall/Precision/NDCG                            |

---

## Condensed Cheat Sheet

```sql
-- EXTERNAL MODEL
EXEC sp_create_external_model @model='text-embedding-3-small', @provider='AzureOpenAI',
  @connection_string='{"endpoint":"...","api_key":"..."}',
  @parameters='{"model":"text-embedding-3-small","dimensions":1536}';

-- VECTOR TABLE & INDEX
CREATE TABLE Docs (ID INT PK, Text NVARCHAR(MAX), Emb VECTOR(1536));
CREATE INDEX IX_Docs_Emb ON Docs(Emb) USING HNSW WITH (M=16, efConstruction=64, efSearch=40);

-- EMBEDDING GENERATION
DECLARE @emb VECTOR(1536);
EXEC sp_invoke_external_model @model='text-embedding-3-small', @input='text', @output=@emb OUTPUT;

-- VECTOR SEARCH
SELECT TOP 10 ID, VECTOR_DISTANCE(Emb, @queryVec) AS Dist FROM Docs ORDER BY Dist;
SELECT * FROM VECTOR_SEARCH(TABLE Docs, COLUMN Emb, QUERY @queryVec, TOP 10, OPTIONS '{"metric":"cosine"}');

-- HYBRID SEARCH (RRF)
WITH VR AS (SELECT ID, ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE(Emb, @qv)) R FROM Docs),
     FTR AS (SELECT ID, ROW_NUMBER() OVER (ORDER BY RANK DESC) R FROM FREETEXTTABLE(Docs, Text, @qt))
SELECT ID, SUM(1.0/(R+60)) Score FROM (SELECT * FROM VR UNION ALL SELECT * FROM FTR) X GROUP BY ID ORDER BY Score DESC;

-- CHUNKING TABLE
CREATE TABLE Chunks (ChunkID INT PK, DocID INT, ChunkIndex INT, Content NVARCHAR(MAX), Emb VECTOR(1536));
```

---

## Day 9 Completion Checklist

- [ ] Read all lab files in `MyLabs/09-generate-update-embedings-sql/` and `MyLabs/10-implement-intelligent-search/`
- [ ] Create vector table, HNSW index, generate embeddings
- [ ] Implement vector search, full-text search, hybrid RRF
- [ ] Compare HNSW vs IVF vs KNN
- [ ] Complete practice questions (target: 4/5 correct)
- [ ] Note weak areas for Day 10 review

---

_Next: Day 10 - AI: RAG & Final Review_

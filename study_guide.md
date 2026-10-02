# DP-800 Exam Revision Plan: 10-Day Intensive Study Schedule

**Exam Date:** October 3, 2026 | **Start Date:** September 22, 2026  
**Study Guide:** [Microsoft Learn DP-800 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800)

---

## Exam Overview

| Domain                                              | Weight | Focus                                                                |
| --------------------------------------------------- | ------ | -------------------------------------------------------------------- |
| **Design and develop database solutions**           | 35–40% | Database objects, programmability, advanced T-SQL, AI-assisted tools |
| **Secure, optimize, and deploy database solutions** | 35–40% | Security, performance, CI/CD, Azure integration                      |
| **Implement AI capabilities in database solutions** | 25–30% | Models/embeddings, intelligent search, RAG                           |

**Passing Score:** 700/1000  
**Format:** Multiple choice, case studies, drag-and-drop, hot area questions

---

## Day 1 (Sep 22): Database Objects & Constraints ⭐

### Learning Objectives (35-40% Domain)

- [ ] Tables: data types, sizing, columns, indexes, columnstore
- [ ] Specialized tables: in-memory, temporal, external, ledger, graph
- [ ] JSON columns and indexes
- [ ] Constraints: PK, FK, UNIQUE, CHECK, DEFAULT
- [ ] SEQUENCES
- [ ] Partitioning for tables and indexes

### Hands-On Labs (from repo)

```bash
# MyLabs/01-create-database-objects/
Create-core-tables-w-constraints.sql
Create-temporal-table-for-price-history.sql
Create-a-partitioned-order-table.sql
Add-JSON-Cols-for-metadata.sql
Create-order-det-w-SEQUENCE.sql
Insert-sample-data-into-tables.sql
Query-the-JSON-data.sql
Query-price-history.sql
```

### Key T-SQL Patterns to Master

```sql
-- Temporal table
CREATE TABLE ProductPriceHistory (
    ProductID INT NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START,
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductPriceHistoryHistory));

-- JSON with index
ALTER TABLE Product ADD Metadata NVARCHAR(MAX) CONSTRAINT chk_json CHECK (ISJSON(Metadata) = 1);
CREATE INDEX idx_json_color ON Product (JSON_VALUE(Metadata, '$.color'));

-- Partitioning
CREATE PARTITION FUNCTION pf_OrderDate (DATE) AS RANGE RIGHT FOR VALUES ('2023-01-01','2024-01-01');
CREATE PARTITION SCHEME ps_OrderDate AS PARTITION pf_OrderDate ALL TO ([PRIMARY]);
```

### Resources

- [Design tables](https://learn.microsoft.com/en-us/sql/relational-databases/tables/tables)
- [Temporal tables](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables)
- [JSON in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)
- [Partitioning](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)

---

## Day 2 (Sep 23): Programmability Objects ⭐

### Learning Objectives (35-40% Domain)

- [ ] Views (including indexed views)
- [ ] Scalar functions
- [ ] Table-valued functions (inline & multi-statement)
- [ ] Stored procedures with error handling
- [ ] Triggers (DML, DDL, LOGON)

### Hands-On Labs (from repo)

```bash
# MyLabs/02-implement-programmability-objects/
2-Create-a-view-to-simplify-queries.sql
3-Create-a-stored-procedure-to-process-an-order.sql
4-Create-a-scalar-function-for-reusable-calculations.sql
5-Create-an-inline-table-valued-function-(TVF).sql
6-Create-a-trigger-to-log-changes.sql
7.1-test_view_permissions.sql
7.2-test_trigger.sql
```

### Key Patterns

```sql
-- Inline TVF (preferred for performance)
CREATE FUNCTION dbo.fn_GetOrdersByCustomer (@CustomerID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN
SELECT SalesOrderID, OrderDate, TotalDue
FROM Sales.SalesOrderHeader
WHERE CustomerID = @CustomerID;

-- Stored procedure with TRY/CATCH
CREATE PROCEDURE dbo.ProcessOrder @OrderID INT
AS BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        -- logic here
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
```

---

## Day 3 (Sep 24): Advanced T-SQL ⭐

### Learning Objectives (35-40% Domain)

- [ ] Common Table Expressions (CTEs) - recursive & non-recursive
- [ ] Window functions: ROW_NUMBER, RANK, DENSE_RANK, NTILE, LEAD, LAG, FIRST_VALUE, LAST_VALUE
- [ ] JSON functions: JSON_OBJECT, JSON_ARRAY, JSON_ARRAYAGG, JSON_CONTAINS, OPENJSON, JSON_VALUE, JSON_MODIFY
- [ ] Regular expressions: REGEXP_LIKE, REGEXP_REPLACE, REGEXP_SUBSTR, REGEXP_INSTR, REGEXP_COUNT, REGEXP_MATCHES, REGEXP_SPLIT_TO_TABLE
- [ ] Fuzzy string matching: EDIT_DISTANCE, EDIT_DISTANCE_SIMILARITY, JARO_WINKLER_DISTANCE
- [ ] Graph queries with MATCH operator
- [ ] Correlated subqueries
- [ ] Error handling: TRY/CATCH, THROW, ERROR\_\* functions

### Hands-On Labs (from repo)

```bash
# MyLabs/03-write-advanced-tsql-code/
2-Parse-JSON-data-with-OPENJSON.sql
3-Combine-JSON-with-a-CTE-and-window-function.sql
21-Created-JSON-with-product-categories.sql
31-Output-the-ranked-products-as-JSON.sql
```

### Practice Queries

```sql
-- Window functions with CTE
WITH RankedProducts AS (
    SELECT
        p.ProductID, p.Name, p.ListPrice,
        ROW_NUMBER() OVER (PARTITION BY c.Name ORDER BY p.ListPrice DESC) AS rn,
        AVG(p.ListPrice) OVER (PARTITION BY c.Name) AS avg_category_price
    FROM SalesLT.Product p
    JOIN SalesLT.ProductCategory c ON p.ProductCategoryID = c.ProductCategoryID
)
SELECT * FROM RankedProducts WHERE rn <= 3;

-- Graph query
CREATE TABLE Employee (ID INT, Name NVARCHAR(50));
CREATE TABLE ReportsTo (FromID INT, ToID INT) AS EDGE;
SELECT e2.Name FROM Employee e1, ReportsTo r, Employee e2
WHERE MATCH(e1-(r)->e2) AND e1.Name = 'John';

-- Fuzzy matching
SELECT EDIT_DISTANCE('Microsoft', 'Microsft') AS dist; -- 1
SELECT JARO_WINKLER_DISTANCE('Microsoft', 'Microsft') AS sim; -- ~0.93
```

---

## Day 4 (Sep 25): AI-Assisted Development ⭐

### Learning Objectives (35-40% Domain)

- [ ] Security impact of AI-assisted tools
- [ ] GitHub Copilot: enable, configure, instruction files
- [ ] Copilot in Fabric
- [ ] Model Context Protocol (MCP) tools
- [ ] Connect to MCP servers (SQL Server, Fabric lakehouse)

### Hands-On Labs (from repo)

```bash
# MyLabs/04-design-implement-sql-solutions-ai-assisted-tools/
1-usp_GetCustomerOrderSummary.sql
... (review all files in this folder)
```

### Key Topics

- `.github/copilot-instructions.md` patterns
- MCP server configuration for SQL
- Prompt engineering for T-SQL generation
- Code review with AI assistance

---

## Day 5 (Sep 26): Security & Compliance ⭐

### Learning Objectives (35-40% Domain)

- [ ] Encryption: Always Encrypted (deterministic/randomized), column-level, TDE
- [ ] Dynamic Data Masking
- [ ] Row-Level Security (RLS) - predicate functions, security policies
- [ ] Object-level permissions (GRANT/DENY/REVOKE)
- [ ] Passwordless authentication (Microsoft Entra ID, Managed Identity)
- [ ] Auditing (server/database level, Log Analytics)
- [ ] Secure model endpoints (Managed Identity)
- [ ] Secure GraphQL, REST, MCP endpoints

### Hands-On Labs (from repo)

```bash
# MyLabs/05-implement-security-compliance/
# Review all files in this folder
```

### Key Scripts

```sql
-- RLS Example
CREATE FUNCTION Security.fn_TenantFilter(@TenantID INT)
RETURNS TABLE WITH SCHEMABINDING AS
RETURN SELECT 1 AS result WHERE @TenantID = SESSION_CONTEXT(N'TenantID');

CREATE SECURITY POLICY TenantPolicy
ADD FILTER PREDICATE Security.fn_TenantFilter(TenantID) ON dbo.Orders,
ADD BLOCK PREDICATE Security.fn_TenantFilter(TenantID) ON dbo.Orders;

-- Dynamic Data Masking
ALTER TABLE Customer ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
ALTER TABLE Customer ALTER COLUMN Phone ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",2)');
```

---

## Day 6 (Sep 27): Performance Optimization ⭐

### Learning Objectives (35-40% Domain)

- [ ] Database configurations (MAXDOP, memory, tempdb)
- [ ] Transaction isolation levels: READ COMMITTED, SNAPSHOT, SERIALIZABLE
- [ ] Concurrency: blocking, deadlocks, lock escalation
- [ ] Query execution plans (estimated vs actual)
- [ ] DMVs: sys.dm_exec_query_stats, sys.dm_db_index_usage_stats, sys.dm_os_wait_stats
- [ ] Query Store configuration and analysis
- [ ] Query Performance Insight (Azure SQL)

### Hands-On Labs (from repo)

```bash
# MyLabs/06-optimize-database-performance/
# Review all files in this folder
```

### Key Queries

```sql
-- Top resource-consuming queries
SELECT TOP 10
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_ms,
    qs.execution_count,
    SUBSTRING(qt.text, qs.statement_start_offset/2 + 1,
        (CASE WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
              ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_elapsed_ms DESC;

-- Missing indexes
SELECT * FROM sys.dm_db_missing_index_group_stats gs
JOIN sys.dm_db_missing_index_groups g ON gs.group_handle = g.index_group_handle
JOIN sys.dm_db_missing_index_details d ON g.index_handle = d.index_handle;
```

---

## Day 7 (Sep 28): CI/CD with SQL Database Projects ⭐

### Learning Objectives (35-40% Domain)

- [ ] SQL Database Projects (SDK-style .sqlproj)
- [ ] Unit tests (tSQLt framework) & integration tests
- [ ] Reference/static data in source control
- [ ] Build, validate, deploy pipelines
- [ ] Branching strategies, PR policies, conflict resolution
- [ ] Secrets management (Azure Key Vault, GitHub secrets)
- [ ] Schema drift detection
- [ ] Deployment pipeline controls: branch policies, approvals, code owners

### Hands-On Labs (from repo)

```bash
# MyLabs/07-implement-cicd-sql-database-projects/
# Review all files in this folder
```

### Pipeline Essentials

```yaml
# .github/workflows/sql-deploy.yml
- uses: azure/sql-action@v2
  with:
    connection-string: ${{ secrets.AZURE_SQL_CONNECTION }}
    path: "./DatabaseProject"
    action: "publish"
```

---

## Day 8 (Sep 29): Azure Integration ⭐

### Learning Objectives (35-40% Domain)

- [ ] Data API Builder (DAB): config, entities, REST/GraphQL, caching, pagination
- [ ] Expose SPs, views, GraphQL relationships
- [ ] DAB deployment (Container Apps, Functions, Kubernetes)
- [ ] Azure Monitor: Application Insights, Log Analytics
- [ ] Change event streaming: CDC, Change Tracking, CES, SQL trigger bindings, Logic Apps

### Hands-On Labs (from repo)

```bash
# MyLabs/08-integrate-sql-solutions-with-azure-services/
# Review all files in this folder
```

### DAB Config Example

```json
// dab-config.json
{
  "source": {
    "connection-string": "@env('SQL_CONNECTION')",
    "object": "dbo.Products"
  },
  "entities": {
    "products": {
      "source": "dbo.Products",
      "rest": "products",
      "graphql": "products"
    }
  },
  "runtime": { "rest": { "enabled": true }, "graphql": { "enabled": true } }
}
```

---

## Day 9 (Sep 30): AI - Models, Embeddings & Intelligent Search ⭐

### Learning Objectives (25-30% Domain)

- [ ] External models: multimodal, multilanguage, structured output
- [ ] Create/manage external models (sp_create_external_model)
- [ ] Embedding maintenance: triggers, Change Tracking, Azure Functions, CDC, Foundry
- [ ] Chunking strategies for embeddings
- [ ] Vector data type, indexes (IVF, HNSW), VECTOR_NORMALIZE, VECTOR_DISTANCE
- [ ] Full-text, semantic vector, hybrid search
- [ ] ANN vs KNN, RRF (Reciprocal Rank Fusion)
- [ ] VECTOR_SEARCH, VECTORPROPERTY functions

### Hands-On Labs (from repo)

```bash
# MyLabs/09-generate-update-embedings-sql/
# MyLabs/10-implement-intelligent-search/
# Review all files in these folders
```

### Key T-SQL

```sql
-- Create vector column & index
ALTER TABLE Documents ADD Embedding VECTOR(1536);
CREATE INDEX idx_hnsw ON Documents (Embedding) USING HNSW WITH (M = 16, efConstruction = 64);

-- Vector search
SELECT TOP 10 *, VECTOR_DISTANCE(Embedding, @queryVector) AS distance
FROM Documents
ORDER BY distance;

-- Hybrid search with RRF
SELECT * FROM (
    SELECT *, 1.0 / (ROW_NUMBER() OVER (ORDER BY rank) + 60) AS rrf_score FROM FullTextResults
    UNION ALL
    SELECT *, 1.0 / (ROW_NUMBER() OVER (ORDER BY distance) + 60) FROM VectorResults
) combined
ORDER BY rrf_score DESC;
```

---

## Day 10 (Oct 1): AI - RAG & Final Review ⭐

### Learning Objectives (25-30% Domain)

- [ ] RAG use cases and architecture
- [ ] `sp_invoke_external_rest_endpoint` for LLM calls
- [ ] Structured data → JSON for LLM processing
- [ ] Prompt engineering, response extraction
- [ ] End-to-end RAG pipeline

### Hands-On Labs (from repo)

```bash
# MyLabs/11-implement-rag-solutions/
# Review all files in this folder
```

### RAG Pattern

```sql
-- 1. Retrieve relevant chunks via vector search
DECLARE @context NVARCHAR(MAX) = (
    SELECT STRING_AGG(Content, ' ')
    FROM Documents
    WHERE VECTOR_DISTANCE(Embedding, @queryVector) < 0.3
);

-- 2. Build prompt with context
DECLARE @prompt NVARCHAR(MAX) = CONCAT(
    'Answer based on: ', @context, ' Question: ', @userQuestion
);

-- 3. Call external LLM
EXEC sp_invoke_external_rest_endpoint
    @url = 'https://my-llm-endpoint.com/chat',
    @method = 'POST',
    @headers = '{"Authorization": "Bearer ' + @token + '", "Content-Type": "application/json"}',
    @payload = CONCAT('{"prompt": "', @prompt, '"}'),
    @response = @response OUTPUT;

-- 4. Extract answer from JSON response
SELECT JSON_VALUE(@response, '$.choices[0].message.content') AS Answer;
```

---

## Days 10-11 (Oct 2-3): Final Review & Practice

### Priority Review Areas

1. **Weak areas** identified during practice
2. **Performance tuning** - execution plans, DMVs, Query Store
3. **Security** - RLS, masking, encryption scenarios
4. **AI/Vector** - VECTOR_SEARCH, hybrid search, RAG flow
5. **CI/CD** - project structure, drift detection, pipeline config

### Practice Resources

- [Free Practice Assessment](https://learn.microsoft.com/en-us/credentials/certifications/azure-administrator/practice/assessment?assessment-type=practice&assessmentId=1704375541&practice-assessment-type=certification)
- [Exam Sandbox](https://aka.ms/examdemo)
- Review all lab files in `MyLabs/` folders

### Day-of-Exam Checklist

- [ ] Government-issued photo ID ready
- [ ] Quiet, well-lit testing space
- [ ] System check completed 30 min before
- [ ] Water, no distractions
- [ ] Relax and read questions carefully

---

## Study Tips

| Technique             | Application                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| **Active recall**     | After each lab, close the file and rewrite key T-SQL from memory       |
| **Spaced repetition** | Review Day 1-2 notes on Day 5, Day 3-4 on Day 7, etc.                  |
| **Explain out loud**  | Teach each concept to an imaginary student                             |
| **Error analysis**    | For every practice question missed, note _why_ and the correct concept |

---

## Quick Reference: Must-Know T-SQL Syntax

```sql
-- Always Encrypted
CREATE COLUMN MASTER KEY CMK_Auto1 WITH (KEY_STORE_PROVIDER_NAME = 'MSSQL_CERTIFICATE_STORE', KEY_PATH = 'CurrentUser/My/...');
CREATE COLUMN ENCRYPTION KEY CEK_Auto1 WITH VALUES (COLUMN_MASTER_KEY = CMK_Auto1, ALGORITHM = 'RSA_OAEP', ENCRYPTED_VALUE = 0x...);

-- Sequence
CREATE SEQUENCE dbo.OrderSeq AS INT START WITH 1 INCREMENT BY 1;

-- Error handling template
BEGIN TRY
    BEGIN TRAN;
    -- DML here
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@msg, 16, 1);
END CATCH;

-- JSON aggregation
SELECT JSON_ARRAYAGG(JSON_OBJECT('id': ProductID, 'name': ProductName)) FROM Product;
```

---

**Good luck! You've got this! 🎯**

_Last updated: September 22, 2026 | 11 days until exam_

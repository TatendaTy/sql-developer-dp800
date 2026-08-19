# DP800 Exam: Advanced T-SQL Concepts Summary

**Exam Focus:** Microsoft Certified: SQL AI Developer Associate (DP800)  
**Current Date:** 2026-08-19  
**Files Covered:** 10 lab exercises in `03-write-advanced-tsql-code`

---

## 1. OPENJSON Function

### Purpose

Parse JSON text into rows and columns for querying.

### Syntax Structure

```sql
SELECT *
FROM OPENJSON(@json_variable)
WITH (
    column_name datatype '$.json_path'
);
```

### Key Concepts

- **WITH clause** defines the schema for the output
- **$.PropertyName** syntax tells SQL Server which JSON path to read
- Maps JSON properties to columns with specified data types
- Can parse JSON arrays and objects

### Example from Lab

```sql
DECLARE @ProductUpdates NVARCHAR(MAX) = N'[
    {"ProductID": 680, "NewPrice": 1250.00 },
    {"ProductID": 706, "NewPrice": 1450.00 },
    {"ProductID": 707, "NewPrice": 38.99}
]';

SELECT ProductID, NewPrice
FROM OPENJSON(@ProductUpdates)
WITH (
    ProductID INT '$.ProductID',
    NewPrice DECIMAL(10, 2) '$.NewPrice'
);
```

### Exam Tips

- `OPENJSON` is the primary function for parsing JSON in T-SQL
- The `WITH` clause is **required** to define output columns and types
- Use `$.property_name` syntax to navigate JSON paths
- Can be used with `INNER JOIN` to combine with relational data

---

## 2. FOR JSON Clause

### Purpose

Convert relational query results into JSON format.

### Variants

| Variant             | Description                                          |
| ------------------- | ---------------------------------------------------- |
| `FOR JSON AUTO`     | Generates JSON automatically based on column names   |
| `FOR JSON PATH`     | Provides more control with explicit path expressions |
| `FOR JSON EXPLICIT` | Maximum control over the JSON structure              |

### Example from Lab

```sql
SELECT ProductID, Name, Color, ListPrice
FROM SalesLT.Product
WHERE Color IS NOT NULL
ORDER BY ListPrice DESC
FOR JSON PATH;
```

### Advanced Usage with ROOT

```sql
-- Wraps entire result in an object with a named property
SELECT ...
FROM ...
FOR JSON PATH, ROOT('TopProducts');
```

### Exam Tips

- `FOR JSON PATH` offers more control than `AUTO`
- `ROOT('name')` wraps results in `{ "TopProducts": [...] }`
- Can combine with `WITH` clauses from `OPENJSON` for end-to-end JSON processing
- Primary function for API responses requiring JSON format

---

## 3. CTEs with Window Functions

### Purpose

Organize complex queries and perform calculations across result set rows.

### Ranking Functions

```sql
WITH RankedProducts AS (
    SELECT
        p.ProductID,
        p.Name AS ProductName,
        pc.Name AS CategoryName,
        p.ListPrice,
        ROW_NUMBER() OVER (
            PARTITION BY pc.ProductCategoryID
            ORDER BY p.ListPrice DESC
        ) AS PriceRank
    FROM SalesLT.Product AS p
    INNER JOIN SalesLT.ProductCategory AS pc
        ON p.ProductCategoryID = pc.ProductCategoryID
    WHERE p.ListPrice > 0
)
SELECT *
FROM RankedProducts
WHERE PriceRank <= 3
ORDER BY CategoryName, PriceRank;
```

### Key Concepts

- **PARTITION BY**: Restarts the calculation for each group (like GROUP BY for window functions)
- **ORDER BY**: Determines the ranking within each partition
- **Window functions** operate on a "window" of rows, not collapsing the result set
- Can reference the CTE in the outer `SELECT`

### Example: Top 3 products per category

- `ROW_NUMBER()` assigns sequential numbers within each partition
- Outer `WHERE PriceRank <= 3` filters to top 3 per category
- Results show most expensive products in each category

### Exam Tips

- `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `NTILE()` are ranking window functions
- `PARTITION BY` divides the result set into partitions
- `ORDER BY` within OVER() determines the ranking sequence
- Window functions don't reduce the number of rows (unlike aggregate functions)
- Common pattern: CTE + window function + filtered outer query

---

## 4. JOIN with Parsed JSON

### Purpose

Combine JSON data with relational tables.

### Example from Lab

```sql
SELECT
    p.ProductID,
    p.Name,
    p.ListPrice AS CurrentPrice,
    updates.NewPrice,
    updates.NewPrice - p.ListPrice AS PriceDifference
FROM SalesLT.Product AS p
INNER JOIN OPENJSON(@ProductUpdates)
WITH (
    ProductID INT '$.ProductID',
    NewPrice DECIMAL(10, 2) '$.NewPrice'
) AS updates
    ON p.ProductID = updates.ProductID;
```

### Key Concepts

- `OPENJSON` acts like a table in a `JOIN`
- The `WITH` clause defines the virtual table schema
- Can `INNER JOIN`, `LEFT JOIN`, etc. with parsed JSON result set
- Useful for updating/merging JSON data with existing records

### Exam Tips

- `OPENJSON` + `WITH` creates a derived table for JOIN operations
- Map JSON paths to columns using `'.property_name'` syntax
- Can filter/join on parsed JSON columns just like regular tables
- Essential for API data integration scenarios

---

## 5. JSON_OBJECT Function

### Purpose

Build nested JSON objects within a query.

### Example from Lab

```sql
SELECT
    p.ProductID,
    p.Name AS ProductName,
    p.ListPrice,
    JSON_OBJECT(
        'CategoryID': pc.ProductCategoryID,
        'CategoryName': pc.Name
    ) AS Category
FROM SalesLT.Product AS p
INNER JOIN SalesLT.ProductCategory AS pc
    ON p.ProductCategoryID = pc.ProductCategoryID
ORDER BY p.ListPrice DESC
FOR JSON PATH;
```

### Key Concepts

- `JSON_OBJECT(key: value, ...)` creates a JSON object
- Can nest objects within queries
- Works alongside `FOR JSON PATH` for complex structures
- Useful for creating hierarchical/related data in output

### Exam Tips

- `JSON_OBJECT` builds individual JSON objects per row
- Can create nested structures (objects within objects)
- Combined with `FOR JSON PATH` for complete JSON output generation
- Alternative to manually constructing JSON strings

---

## 6. FOR JSON with ROOT

### Purpose

Wrap JSON array output in a named root element.

### Example from Lab

```sql
WITH RankedProducts AS (
    SELECT ... ROW_NUMBER() OVER (...) AS PriceRank
    FROM ...
    WHERE PriceRank <= 3
)
SELECT *
FROM RankedProducts
FOR JSON PATH, ROOT('TopProducts');
```

### Output Structure

```json
{
  "TopProducts": [
    { "ProductID": 1, ... },
    { "ProductID": 2, ... }
  ]
}
```

### Without ROOT

```json
[ { "ProductID": 1, ... }, { "ProductID": 2, ... } ]
```

### Exam Tips

- `ROOT('name')` adds a wrapping element to the JSON output
- Useful for API responses that expect a specific structure
- Combined with `PATH` mode for flexible JSON generation
- Distinguishes between array vs object root in JSON

---

## 7. DP800 Practice Questions

### Question 1: OPENJSON

**Q:** In `OPENJSON(@json) WITH (col1 INT '$.path1', col2 VARCHAR(50) '$.path2')`, what does the `WITH` clause accomplish?
**A:** Defines the output schema - column names, data types, and JSON paths to read

### Question 2: FOR JSON

**Q:** Which `FOR JSON` clause provides the most control over output structure?
**A:** `FOR JSON EXPLICIT` (though `PATH` is most commonly used in practice)

### Question 3: Window Functions

**Q:** What does `PARTITION BY` do in a window function?
**A:** Divides the result set into partitions to which the function is applied separately

### Question 4: JSON Parsing

**Q:** Which function would you use to parse JSON text into rows for joining with a table?
**A:** `OPENJSON`

### Question 5: FOR JSON ROOT

**Q:** What does adding `ROOT('TopProducts')` to `FOR JSON PATH` produce?
**A:** Wraps the JSON array in `{"TopProducts": [...] }` structure

---

## 8. Key Exam Concepts Quick Reference

| Topic                | Key Exam Point                                       |
| -------------------- | ---------------------------------------------------- |
| **OPENJSON**         | Parse JSON → rows/columns WITH clause defines schema |
| **FOR JSON**         | Relational → JSON AUTO/PATH/EXPLICIT modes           |
| **Window Functions** | OVER() with PARTITION BY + ORDER BY                  |
| **CTEs**             | WITH clause defines temp result sets                 |
| **JOIN + OPENJSON**  | Parse JSON then join like table                      |
| **JSON_OBJECT**      | Build nested JSON objects                            |
| **FOR JSON ROOT**    | Wrap output in named element                         |

### Common Patterns

1. Parse JSON → JOIN with relational data → UPDATE/INSERT
2. Calculate rankings → FILTER top N per group → FOR JSON OUTPUT
3. Build nested objects → JSON output for API responses
4. Handle multiple line items → GROUP BY aggregates in triggers

### Performance Considerations

- Indexes on JSON search paths improve `OPENJSON` performance
- `FOR JSON PATH` performance similar to `SELECT` query optimization
- Window functions can be resource-intensive on large partitions
- Consider `MAXRECURSION` for recursive CTEs (default 100)

---

## 9. Hands-On Practice Recommendations

### For OPENJSON

- Parse various JSON structures (arrays, objects, nested)
- Practice mapping different JSON paths to columns
- JOIN results with AdventureWorksLT tables

### For FOR JSON

- Test all three modes: AUTO, PATH, EXPLICIT
- Experiment with `ROOT()` parameter
- Combine with CTEs for complex queries

### For Window Functions

- Practice `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`
- Experiment with different `PARTITION BY` combinations
- Filter results based on rank positions

### For Combined Scenarios

- Parse JSON → join → apply window functions → output as JSON
- Build end-to-end scenarios similar to lab exercises
- Focus on logical flow rather than memorizing syntax

---

_Summary generated for DP800 Exam Preparation_  
_Based on lab exercises in MyLabs/03-write-advanced-tsql-code_  
_Current Date: 2026-08-19_

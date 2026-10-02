# Day 3: Advanced T-SQL

**Date:** September 24, 2026 | **Exam Weight:** 35-40% (Design & Develop Database Solutions)

---

## 🎯 Learning Objectives

- [ ] Common Table Expressions (CTEs) - recursive & non-recursive
- [ ] Window functions: ROW_NUMBER, RANK, DENSE_RANK, NTILE, LEAD, LAG, FIRST_VALUE, LAST_VALUE
- [ ] JSON functions: JSON_OBJECT, JSON_ARRAY, JSON_ARRAYAGG, JSON_CONTAINS, OPENJSON, JSON_VALUE, JSON_MODIFY
- [ ] Regular expressions: REGEXP_LIKE, REGEXP_REPLACE, REGEXP_SUBSTR, REGEXP_INSTR, REGEXP_COUNT, REGEXP_MATCHES, REGEXP_SPLIT_TO_TABLE
- [ ] Fuzzy string matching: EDIT_DISTANCE, EDIT_DISTANCE_SIMILARITY, JARO_WINKLER_DISTANCE
- [ ] Graph queries with MATCH operator
- [ ] Correlated subqueries
- [ ] Error handling: TRY/CATCH, THROW, ERROR\_\* functions

---

## 📚 Core Concepts

### 1. Common Table Expressions (CTEs)

```sql
-- Non-recursive CTE (readability, modularity)
WITH HighValueCustomers AS (
    SELECT CustomerID, SUM(TotalAmount) AS TotalSpent
    FROM Orders
    WHERE OrderDate >= DATEADD(YEAR, -1, GETDATE())
    GROUP BY CustomerID
    HAVING SUM(TotalAmount) > 10000
),
CustomerOrders AS (
    SELECT o.*, c.CustomerName
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
)
SELECT co.*, hvc.TotalSpent
FROM CustomerOrders co
JOIN HighValueCustomers hvc ON co.CustomerID = hvc.CustomerID;

-- Recursive CTE (hierarchical data)
WITH OrgChart AS (
    -- Anchor: top-level managers
    SELECT EmployeeID, ManagerID, EmployeeName, 0 AS Level,
           CAST(EmployeeName AS NVARCHAR(MAX)) AS Path
    FROM Employees
    WHERE ManagerID IS NULL

    UNION ALL

    -- Recursive: subordinates
    SELECT e.EmployeeID, e.ManagerID, e.EmployeeName, oc.Level + 1,
           CAST(oc.Path + ' > ' + e.EmployeeName AS NVARCHAR(MAX))
    FROM Employees e
    JOIN OrgChart oc ON e.ManagerID = oc.EmployeeID
    WHERE oc.Level < 10  -- Prevent infinite recursion
)
SELECT * FROM OrgChart ORDER BY Level, Path;

-- CTE with DELETE/UPDATE (SQL Server 2008+)
WITH DuplicateOrders AS (
    SELECT OrderID, ROW_NUMBER() OVER (PARTITION BY CustomerID, OrderDate ORDER BY OrderID) AS rn
    FROM Orders
)
DELETE FROM DuplicateOrders WHERE rn > 1;
```

**CTE vs Temp Table vs Table Variable:**
| Feature | CTE | Temp Table (#) | Table Variable (@) |
|---------|-----|----------------|-------------------|
| Scope | Single statement | Session | Batch |
| Statistics | No | Yes | No (1 row estimate) |
| Indexes | No | Yes | PK/Unique only |
| Reusability | No | Yes | No |
| Best For | Readability, recursion | Large intermediate results | Small row counts |

---

### 2. Window Functions

```sql
-- Sample data context
SELECT * FROM SalesLT.Product;  -- ProductID, Name, ListPrice, ProductCategoryID

-- ROW_NUMBER - unique sequential number
SELECT ProductID, Name, ListPrice,
       ROW_NUMBER() OVER (ORDER BY ListPrice DESC) AS PriceRank
FROM SalesLT.Product;

-- RANK / DENSE_RANK - handle ties
SELECT ProductID, Name, ListPrice,
       RANK() OVER (ORDER BY ListPrice DESC) AS RankWithGaps,
       DENSE_RANK() OVER (ORDER BY ListPrice DESC) AS RankNoGaps
FROM SalesLT.Product;

-- NTILE - distribute into buckets
SELECT ProductID, Name, ListPrice,
       NTILE(4) OVER (ORDER BY ListPrice) AS PriceQuartile
FROM SalesLT.Product;

-- PARTITION BY - reset per group
SELECT p.ProductID, p.Name, p.ListPrice, c.Name AS Category,
       ROW_NUMBER() OVER (PARTITION BY c.ProductCategoryID ORDER BY p.ListPrice DESC) AS RankInCategory,
       AVG(p.ListPrice) OVER (PARTITION BY c.ProductCategoryID) AS AvgCategoryPrice
FROM SalesLT.Product p
JOIN SalesLT.ProductCategory c ON p.ProductCategoryID = c.ProductCategoryID;

-- LEAD / LAG - access adjacent rows
SELECT OrderID, OrderDate, TotalAmount,
       LAG(TotalAmount) OVER (ORDER BY OrderDate) AS PrevOrderAmount,
       LEAD(TotalAmount) OVER (ORDER BY OrderDate) AS NextOrderAmount,
       TotalAmount - LAG(TotalAmount) OVER (ORDER BY OrderDate) AS DiffFromPrev
FROM SalesLT.SalesOrderHeader
WHERE CustomerID = 100;

-- FIRST_VALUE / LAST_VALUE - frame awareness needed!
SELECT ProductID, Name, ListPrice,
       FIRST_VALUE(Name) OVER (PARTITION BY ProductCategoryID ORDER BY ListPrice DESC) AS MostExpensive,
       LAST_VALUE(Name) OVER (
           PARTITION BY ProductCategoryID
           ORDER BY ListPrice DESC
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS LeastExpensive
FROM SalesLT.Product;

-- Aggregate window functions
SELECT CustomerID, OrderDate, TotalAmount,
       SUM(TotalAmount) OVER (PARTITION BY CustomerID ORDER BY OrderDate
                              ROWS UNBOUNDED PRECEDING) AS RunningTotal,
       AVG(TotalAmount) OVER (PARTITION BY CustomerID) AS AvgOrderValue
FROM SalesLT.SalesOrderHeader;
```

**Window Frame Clauses:**

```sql
-- Default: RANGE UNBOUNDED PRECEDING AND CURRENT ROW
-- Explicit frames:
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING  -- Full partition
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW                  -- 3-row sliding window
ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING          -- Current to end
```

---

### 3. JSON Functions (SQL Server 2016+ / 2022 Enhancements)

```sql
-- Sample JSON column: Attributes NVARCHAR(MAX)
-- {"color": "Red", "size": "L", "tags": ["sale", "new"], "specs": {"weight": 1.5, "dimensions": "10x5x2"}}

-- Extraction
SELECT JSON_VALUE(Attributes, '$.color') AS Color,           -- Scalar: "Red"
       JSON_QUERY(Attributes, '$.tags') AS Tags,             -- Array: ["sale","new"]
       JSON_QUERY(Attributes, '$.specs') AS Specs;           -- Object: {"weight":1.5,...}

-- Path modes: lax (default, null if missing) vs strict (error)
SELECT JSON_VALUE(Attributes, 'strict $.missing') AS StrictError,  -- Error
       JSON_VALUE(Attributes, 'lax $.missing') AS LaxNull;         -- NULL

-- JSON_MODIFY - update JSON (returns modified copy)
UPDATE Products
SET Attributes = JSON_MODIFY(Attributes, '$.color', 'Blue')
WHERE ProductID = 1;

-- JSON_MODIFY - append to array
UPDATE Products
SET Attributes = JSON_MODIFY(Attributes, 'append $.tags', 'featured')
WHERE ProductID = 1;

-- OPENJSON - parse to rows
SELECT * FROM OPENJSON(@jsonString);
-- Columns: key, value, type (0=null,1=string,2=number,3=bool,4=array,5=object)

-- OPENJSON with explicit schema
SELECT ProductID, Color, Size
FROM Products
CROSS APPLY OPENJSON(Attributes)
WITH (Color NVARCHAR(20) '$.color', Size NVARCHAR(10) '$.size');

-- SQL Server 2022: JSON_ARRAYAGG, JSON_OBJECTAGG
SELECT CustomerID,
       JSON_ARRAYAGG(JSON_OBJECT('order': OrderID, 'date': OrderDate, 'amount': TotalAmount)) AS Orders
FROM Orders
GROUP BY CustomerID;

-- SQL Server 2022: JSON_PATH_EXISTS (boolean)
SELECT * FROM Products
WHERE JSON_PATH_EXISTS(Attributes, '$.tags[*] ? (@ == "sale")');  -- Array contains "sale"
```

---

### 4. Regular Expressions (SQL Server 2022+)

```sql
-- REGEXP_LIKE - boolean match
SELECT * FROM Customers
WHERE REGEXP_LIKE(Email, '^[^@]+@[^@]+\.[^@]+$');  -- Basic email validation

SELECT * FROM Products
WHERE REGEXP_LIKE(ProductCode, '^PRD-\d{4}-[A-Z]{2}$');  -- PRD-1234-AB

-- REGEXP_REPLACE - replace pattern
SELECT REGEXP_REPLACE(Phone, '[^0-9]', '') AS CleanPhone FROM Customers;
SELECT REGEXP_REPLACE(Description, '(?i)\b(free|sale|discount)\b', '**MARKETING**') FROM Products;

-- REGEXP_SUBSTR - extract matching substring
SELECT REGEXP_SUBSTR(Description, '\$[0-9,]+\.[0-9]{2}') AS FirstPrice FROM Products;
SELECT REGEXP_SUBSTR(Description, '\$[0-9,]+\.[0-9]{2}', 1, 2) AS SecondPrice FROM Products;  -- 2nd occurrence

-- REGEXP_INSTR - position of match
SELECT REGEXP_INSTR(Email, '@') AS AtPosition FROM Customers;

-- REGEXP_COUNT - count occurrences
SELECT REGEXP_COUNT(Description, '(?i)\b(sale|discount)\b') AS PromoCount FROM Products;

-- REGEXP_MATCHES - returns all matches as table (2022+)
SELECT * FROM REGEXP_MATCHES('Order #123, #456, #789', '#(\d+)');
-- Returns: match="123", group1="123" | match="456", group1="456" | ...

-- REGEXP_SPLIT_TO_TABLE - split string by regex
SELECT * FROM REGEXP_SPLIT_TO_TABLE('apple,banana;orange|grape', '[,;|]');
-- Returns: "apple" | "banana" | "orange" | "grape"
```

**Regex Flags:** `(?i)` case-insensitive, `(?m)` multiline, `(?s)` single-line (dot matches newline)

---

### 5. Fuzzy String Matching (SQL Server 2022+)

```sql
-- EDIT_DISTANCE - Levenshtein distance (insert/delete/replace)
SELECT EDIT_DISTANCE('Microsoft', 'Microsft') AS Distance;  -- 1 (missing 'o')
SELECT EDIT_DISTANCE('Microsoft', 'Microsift') AS Distance; -- 2 (o->i, missing 'o')

-- EDIT_DISTANCE_SIMILARITY - 0.0 to 1.0 (1 = identical)
SELECT EDIT_DISTANCE_SIMILARITY('Microsoft', 'Microsft') AS Sim;  -- ~0.89
SELECT EDIT_DISTANCE_SIMILARITY('Microsoft', 'Google') AS Sim;    -- ~0.0

-- JARO_WINKLER_DISTANCE - favors prefix matches (0.0 to 1.0)
SELECT JARO_WINKLER_DISTANCE('Microsoft', 'Microsft') AS JW;  -- ~0.93 (high - common prefix)
SELECT JARO_WINKLER_DISTANCE('Microsoft', 'MicroSoft') AS JW; -- ~0.96 (case diff only)

-- Practical: Fuzzy search for customer name
DECLARE @SearchName NVARCHAR(100) = 'Jon Smith';
SELECT TOP 10 CustomerID, FirstName + ' ' + LastName AS FullName,
       JARO_WINKLER_DISTANCE(FirstName + ' ' + LastName, @SearchName) AS Score
FROM Customers
WHERE JARO_WINKLER_DISTANCE(FirstName + ' ' + LastName, @SearchName) > 0.85
ORDER BY Score DESC;

-- Combine with full-text for hybrid approach
SELECT * FROM Customers
WHERE CONTAINS(FullName, '"Jon*"')  -- Exact prefix
   OR JARO_WINKLER_DISTANCE(FullName, 'Jon Smith') > 0.9;
```

---

### 6. Graph Queries (SQL Server 2017+)

```sql
-- Node and Edge tables
CREATE TABLE Person (ID INT PRIMARY KEY, Name NVARCHAR(50)) AS NODE;
CREATE TABLE WorksFor (StartDate DATE) AS EDGE;
CREATE TABLE Company (ID INT PRIMARY KEY, Name NVARCHAR(50)) AS NODE;

-- Insert nodes
INSERT INTO Person VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Carol');
INSERT INTO Company VALUES (10, 'Microsoft'), (20, 'Google');

-- Insert edges (uses $node_id pseudo-columns)
INSERT INTO WorksFor ($from_id, $to_id, StartDate)
SELECT p.$node_id, c.$node_id, '2020-01-01'
FROM Person p, Company c
WHERE p.Name = 'Alice' AND c.Name = 'Microsoft';

-- MATCH pattern: (Node)-[Edge]->(Node)
-- Find who works for Microsoft
SELECT p.Name
FROM Person p, WorksFor w, Company c
WHERE MATCH(p-(w)->c) AND c.Name = 'Microsoft';

-- Multi-hop: Alice -> WorksFor -> Microsoft <- WorksFor <- Bob (colleagues)
SELECT p2.Name AS Colleague
FROM Person p1, WorksFor w1, Company c, WorksFor w2, Person p2
WHERE MATCH(p1-(w1)->c<-(w2)-p2)
  AND p1.Name = 'Alice' AND p2.Name <> 'Alice';

-- Shortest path (SQL Server 2019+)
SELECT * FROM GRAPH_PATH
FROM Person p1, WorksFor w, Company c, WorksFor w2, Person p2
WHERE MATCH(p1-(w)->c<-(w2)-p2)  -- Not directly supported, use recursive CTE
-- Use recursive CTE for path finding
```

**MATCH Patterns:**
| Pattern | Meaning |
|---------|---------|
| `a-(e)->b` | a connects to b via edge e (directed) |
| `a<-(e)-b` | b connects to a via edge e |
| `a-(e)-b` | Undirected (either direction) |
| `a-(e1)->b<-(e2)-c` | Multi-hop patterns |

---

### 7. Correlated Subqueries

```sql
-- Correlated: references outer query column
SELECT CustomerID, CustomerName,
       (SELECT MAX(OrderDate) FROM Orders o WHERE o.CustomerID = c.CustomerID) AS LastOrderDate
FROM Customers c;

-- Correlated with EXISTS (semi-join)
SELECT CustomerID, CustomerName
FROM Customers c
WHERE EXISTS (
    SELECT 1 FROM Orders o
    WHERE o.CustomerID = c.CustomerID
      AND o.OrderDate >= DATEADD(MONTH, -3, GETDATE())
);

-- Correlated UPDATE
UPDATE Products p
SET LastOrderDate = (
    SELECT MAX(OrderDate)
    FROM OrderDetails od
    JOIN Orders o ON od.OrderID = o.OrderID
    WHERE od.ProductID = p.ProductID
);

-- APPLY operator (often better than correlated subquery)
SELECT c.CustomerID, c.CustomerName, ca.OrderID, ca.OrderDate
FROM Customers c
CROSS APPLY (
    SELECT TOP 3 OrderID, OrderDate
    FROM Orders o
    WHERE o.CustomerID = c.CustomerID
    ORDER BY OrderDate DESC
) ca;

-- OUTER APPLY (like LEFT JOIN)
SELECT c.CustomerID, c.CustomerName, ca.OrderID
FROM Customers c
OUTER APPLY (
    SELECT TOP 1 OrderID FROM Orders o WHERE o.CustomerID = c.CustomerID ORDER BY OrderDate DESC
) ca;
```

---

### 8. Error Handling

```sql
-- TRY/CATCH block
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Orders (CustomerID, TotalAmount) VALUES (999, 100);  -- FK violation

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

    -- Error information functions
    SELECT
        ERROR_NUMBER() AS ErrorNum,      -- 547 (FK violation)
        ERROR_SEVERITY() AS Severity,    -- 16
        ERROR_STATE() AS State,          -- 0
        ERROR_PROCEDURE() AS ProcName,   -- NULL if ad-hoc
        ERROR_LINE() AS LineNum,         -- Line number
        ERROR_MESSAGE() AS Msg;          -- Full message

    -- Re-throw (preserves original error)
    THROW;

    -- Or custom error
    -- THROW 50001, 'Custom message: ' + ERROR_MESSAGE(), 1;
END CATCH;

-- THROW vs RAISERROR
THROW 50001, 'Business rule violation', 1;  -- Always severity 16, stops batch
RAISERROR('Custom message', 16, 1);          -- Can use severity 1-25, continues if < 20

-- XACT_STATE() in CATCH
BEGIN CATCH
    IF XACT_STATE() = -1  -- Uncommittable transaction
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1  -- Committable
        COMMIT TRANSACTION;
    THROW;
END CATCH;
```

---

## 🧪 Hands-On Labs

Run these from `MyLabs/03-write-advanced-tsql-code/`:

```bash
1. 1-Connect-to-AdventureWorksLT.sql
2. 2-Parse-JSON-data-with-OPENJSON.sql
3. 3-Combine-JSON-with-a-CTE-and-window-function.sql
4. 21-Created-JSON-with-product-categories.sql
5. 31-Output-the-ranked-products-as-JSON.sql
# ... review all files in this folder
```

---

## 📝 Practice Questions

### Question 1

A recursive CTE for organizational hierarchy runs infinitely. What's the most likely fix?

A) Add `OPTION (MAXRECURSION 100)` to the query
B) Add `WHERE Level < 10` in the recursive member
C) Use `UNION` instead of `UNION ALL`
D) Add `TOP 100` to the anchor member

**Answer: B** - Recursive CTEs need a termination condition in the recursive member. `MAXRECURSION` is a safety limit, not a fix.

### Question 2

`LAST_VALUE()` returns the same value for all rows in a partition. Why?

A) Missing `PARTITION BY`
B) Default frame is `RANGE UNBOUNDED PRECEDING AND CURRENT ROW`
C) Need `ORDER BY` in OVER clause
D) Function not supported in SQL Server

**Answer: B** - Default frame ends at current row. Need `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

### Question 3

Which JSON function returns a scalar value (not object/array)?

A) `JSON_QUERY`
B) `JSON_VALUE`
C) `OPENJSON`
D) `JSON_MODIFY`

**Answer: B** - `JSON_VALUE` returns scalar; `JSON_QUERY` returns object/array.

### Question 4

`REGEXP_REPLACE(Phone, '[^0-9]', '')` - what does this do?

A) Removes all non-digits
B) Keeps only non-digits
C) Replaces digits with empty string
D) Validates phone format

**Answer: A** - `[^0-9]` matches non-digits; replaces with empty string = removes them.

### Question 5

`EDIT_DISTANCE('cat', 'dog')` returns?

A) 1
B) 2
C) 3
D) 0

**Answer: C** - 3 substitutions needed (c→d, a→o, t→g).

### Question 6

Graph query: `MATCH(p1-(w)->c<-(w2)-p2)` finds what?

A) People who work for same company
B) Companies with no employees
C) People who manage other people
D) Self-referencing edges

**Answer: A** - p1 works for c, p2 also works for c (colleagues).

---

## 🎯 Exam Tricks & Gotchas

| Topic                | Trick/Gotcha                                                                          |
| -------------------- | ------------------------------------------------------------------------------------- |
| **Recursive CTE**    | Default `MAXRECURSION 100`; use `OPTION (MAXRECURSION 0)` for unlimited               |
| **Window Frames**    | `RANGE` vs `ROWS`: RANGE uses logical values (slow), ROWS uses physical rows (fast)   |
| **LAST_VALUE**       | Always specify full frame: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` |
| **JSON_PATH_EXISTS** | Returns 1/0 (bit); faster than `JSON_VALUE(...) IS NOT NULL`                          |
| **REGEXP**           | Case-sensitive by default; use `(?i)` for case-insensitive                            |
| **Fuzzy Match**      | `JARO_WINKLER` > 0.85 for names; `EDIT_DISTANCE_SIMILARITY` > 0.8 for general         |
| **Graph**            | `$node_id` and `$edge_id` are hidden columns; use in INSERT/SELECT                    |
| **APPLY**            | `CROSS APPLY` = INNER JOIN; `OUTER APPLY` = LEFT JOIN                                 |
| **THROW**            | In CATCH without params re-throws original error; outside CATCH needs error number    |

---

## 📋 Condensed Cheat Sheet

```sql
-- RECURSIVE CTE
WITH Tree AS (
  SELECT ID, ParentID, Name, 0 Lvl FROM Tbl WHERE ParentID IS NULL
  UNION ALL
  SELECT t.ID, t.ParentID, t.Name, tr.Lvl + 1
  FROM Tbl t JOIN Tree tr ON t.ParentID = tr.ID
  WHERE tr.Lvl < 10
) SELECT * FROM Tree;

-- WINDOW FUNCTIONS
ROW_NUMBER() OVER (PARTITION BY grp ORDER BY col)
RANK() / DENSE_RANK() OVER (ORDER BY col)
NTILE(4) OVER (ORDER BY col)
LEAD(col) / LAG(col) OVER (ORDER BY col)
FIRST_VALUE(col) OVER (PARTITION BY grp ORDER BY col
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)

-- JSON (2022+)
JSON_VALUE(col, '$.path')           -- scalar
JSON_QUERY(col, '$.path')           -- object/array
JSON_MODIFY(col, '$.path', 'val')   -- update
JSON_ARRAYAGG(expr) / JSON_OBJECTAGG(key:val)  -- aggregate
JSON_PATH_EXISTS(col, '$.path')     -- boolean

-- REGEX (2022+)
REGEXP_LIKE(col, 'pattern')
REGEXP_REPLACE(col, 'pattern', 'repl')
REGEXP_SUBSTR(col, 'pattern', 1, n)  -- nth occurrence
REGEXP_SPLIT_TO_TABLE(str, 'delim')

-- FUZZY (2022+)
EDIT_DISTANCE(s1, s2)                    -- int
EDIT_DISTANCE_SIMILARITY(s1, s2)         -- 0-1
JARO_WINKLER_DISTANCE(s1, s2)            -- 0-1 (prefix boost)

-- GRAPH
MATCH(a-(e)->b)  -- directed edge

-- ERROR HANDLING
BEGIN TRY BEGIN TRAN; -- DML; COMMIT; END TRY
BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
```

---

## ✅ Day 3 Completion Checklist

- [ ] Read all lab files in `MyLabs/03-write-advanced-tsql-code/`
- [ ] Execute each lab script and verify results
- [ ] Complete practice questions above (target: 5/6 correct)
- [ ] Memorize cheat sheet syntax patterns
- [ ] Practice window functions with different frame clauses
- [ ] Test JSON_PATH_EXISTS and REGEXP functions (need SQL 2022)
- [ ] Note weak areas for Day 10 review

---

_Next: Day 4 - AI-Assisted Development (GitHub Copilot, MCP, Instruction Files)_

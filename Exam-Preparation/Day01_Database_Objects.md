# Day 1: Database Objects & Constraints

**Date:** September 22, 2026 | **Exam Weight:** 35-40% (Design & Develop Database Solutions)

---

## 🎯 Learning Objectives

- [x] Design and implement tables: data types, sizing, columns, indexes, columnstore indexes
- [ ] Specialized tables: in-memory, temporal, external, ledger, graph
- [ ] JSON columns and indexes
- [ ] Database constraints: PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, DEFAULT
- [ ] SEQUENCES
- [ ] Partitioning for tables and indexes

---

## 📚 Core Concepts

### 1. Table Design Fundamentals

```sql
-- Optimal data type selection
CREATE TABLE Products (
    ProductID       INT             IDENTITY(1,1) PRIMARY KEY,  -- 4 bytes
    ProductName     NVARCHAR(100)   NOT NULL,                    -- Variable Unicode
    SKU             CHAR(12)        NOT NULL UNIQUE,             -- Fixed, exact length
    Price           DECIMAL(10,2)   NOT NULL CHECK (Price >= 0), -- Precise decimal
    Weight          DECIMAL(6,3)    NULL,                        -- 3 decimal places
    IsActive        BIT             DEFAULT 1,                   -- 1 byte
    CreatedDate     DATETIME2(0)    DEFAULT SYSUTCDATETIME(),    -- 6 bytes, no fractional sec
    RowVersion      ROWVERSION      NOT NULL                     -- Optimistic concurrency
);
```

**Data Type Quick Reference:**
| Category | Types | Use Case |
|----------|-------|----------|
| Exact Numeric | `BIT`, `TINYINT`, `SMALLINT`, `INT`, `BIGINT`, `DECIMAL(p,s)`, `MONEY` | Counts, IDs, money |
| Approximate Numeric | `FLOAT`, `REAL` | Scientific calculations |
| Date/Time | `DATE`, `TIME(n)`, `DATETIME2(n)`, `DATETIMEOFFSET(n)`, `SMALLDATETIME` | Temporal data |
| Character | `CHAR(n)`, `VARCHAR(n)`, `NCHAR(n)`, `NVARCHAR(n)` | Text (N = Unicode) |
| Binary | `BINARY(n)`, `VARBINARY(n)`, `VARBINARY(MAX)` | Files, hashes |
| Special | `UNIQUEIDENTIFIER`, `ROWVERSION`, `HIERARCHYID`, `GEOGRAPHY`, `GEOMETRY` | Specific purposes |

**Sizing Guidelines:**

- Use `VARCHAR` over `CHAR` for variable-length data > 2 chars different
- `NVARCHAR` = 2 bytes/char, `VARCHAR` = 1 byte/char (plus 2 bytes overhead)
- `DECIMAL(19,4)` for currency (max 15 digits precision)
- `DATETIME2(0)` for date-only precision (6 bytes vs 8 for DATETIME)

---

### 2. Specialized Table Types

#### Temporal Tables (System-Versioned)

```sql
-- Create temporal table with history
CREATE TABLE dbo.ProductPrice (
    ProductID     INT         NOT NULL PRIMARY KEY,
    Price         DECIMAL(10,2) NOT NULL,
    ValidFrom     DATETIME2   GENERATED ALWAYS AS ROW START HIDDEN,
    ValidTo       DATETIME2   GENERATED ALWAYS AS ROW END HIDDEN,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductPriceHistory));

-- Query history
SELECT * FROM dbo.ProductPrice
FOR SYSTEM_TIME BETWEEN '2024-01-01' AND '2024-12-31'
WHERE ProductID = 100;

-- Point-in-time
SELECT * FROM dbo.ProductPrice
FOR SYSTEM_TIME AS OF '2024-06-15 12:00:00';
```

#### In-Memory OLTP (Memory-Optimized)

```sql
CREATE TABLE dbo.SessionCache (
    SessionID     INT         NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1000000),
    UserID        INT         NOT NULL,
    Data          NVARCHAR(MAX) NOT NULL,
    ExpiresAt     DATETIME2   NOT NULL,
    INDEX IX_Expires NONCLUSTERED (ExpiresAt)
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
-- Note: No FOREIGN KEY, CHECK, DEFAULT constraints allowed
-- Use native compiled stored procedures for best performance
```

#### Ledger Tables (Tamper-Evident)

```sql
-- Append-only ledger table
CREATE TABLE dbo.FinancialTransactions (
    TransactionID BIGINT IDENTITY PRIMARY KEY,
    AccountID     INT         NOT NULL,
    Amount        DECIMAL(18,2) NOT NULL,
    Description   NVARCHAR(200),
    TransactionDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
)
WITH (LEDGER = ON (APPEND_ONLY = ON));
-- Creates: FinancialTransactions_Ledger (history) + ledger view

-- Updatable ledger (tracks all changes)
CREATE TABLE dbo.CustomerLedger (
    CustomerID    INT PRIMARY KEY,
    Name          NVARCHAR(100),
    Email         NVARCHAR(200),
    CreditLimit   DECIMAL(10,2)
)
WITH (LEDGER = ON);  -- Default: updatable
```

#### Graph Tables

```sql
-- Node table
CREATE TABLE dbo.Person (
    PersonID  INT IDENTITY PRIMARY KEY,
    Name      NVARCHAR(100)
) AS NODE;

-- Edge table (no columns required, but can add)
CREATE TABLE dbo.Knows (
    Since     DATE DEFAULT GETDATE()
) AS EDGE;

-- MATCH query (SQL Server 2019+)
SELECT Person2.Name
FROM Person Person1, Knows, Person Person2
WHERE MATCH(Person1-(Knows)->Person2)
  AND Person1.Name = 'Alice';
```

#### External Tables (PolyBase)

```sql
-- External data source
CREATE EXTERNAL DATA SOURCE AzureBlobStorage
WITH (TYPE = HADOOP, LOCATION = 'wasbs://container@account.blob.core.windows.net');

-- External file format
CREATE EXTERNAL FILE FORMAT ParquetFormat
WITH (FORMAT_TYPE = PARQUET);

-- External table
CREATE EXTERNAL TABLE dbo.SalesExternal (
    SaleID    BIGINT,
    SaleDate  DATE,
    Amount    DECIMAL(18,2)
)
WITH (
    DATA_SOURCE = AzureBlobStorage,
    FILE_FORMAT = ParquetFormat,
    LOCATION = '/sales/year=2024/'
);
```

---

### 3. JSON Columns & Indexes

```sql
-- Add JSON column with constraint
ALTER TABLE Products
ADD Attributes NVARCHAR(MAX)
CONSTRAINT CHK_Products_Attributes_JSON CHECK (ISJSON(Attributes) = 1);

-- JSON index on scalar value (computed column + index)
ALTER TABLE Products
ADD Color AS JSON_VALUE(Attributes, '$.color') PERSISTED;

CREATE INDEX IX_Products_Color ON Products (Color);

-- JSON index on array (using OPENJSON in indexed view)
CREATE VIEW dbo.vw_Product_Tags
WITH SCHEMABINDING
AS
SELECT ProductID, JSON_VALUE(value, '$.tag') AS Tag
FROM dbo.Products
CROSS APPLY OPENJSON(Attributes, '$.tags');

CREATE UNIQUE CLUSTERED INDEX IX_vw_Product_Tags ON dbo.vw_Product_Tags (ProductID, Tag);
CREATE NONCLUSTERED INDEX IX_vw_Product_Tags_Tag ON dbo.vw_Product_Tags (Tag);
```

**JSON Functions Reference:**
| Function | Purpose | Example |
|----------|---------|---------|
| `ISJSON()` | Validate JSON | `WHERE ISJSON(col) = 1` |
| `JSON_VALUE()` | Extract scalar | `JSON_VALUE(col, '$.price')` |
| `JSON_QUERY()` | Extract object/array | `JSON_QUERY(col, '$.items')` |
| `JSON_MODIFY()` | Update JSON | `JSON_MODIFY(col, '$.price', 9.99)` |
| `OPENJSON()` | Parse to rows | `CROSS APPLY OPENJSON(col)` |
| `JSON_OBJECT()` | Build object | `JSON_OBJECT('name': @name)` |
| `JSON_ARRAY()` | Build array | `JSON_ARRAY(1, 2, 3)` |
| `JSON_ARRAYAGG()` | Aggregate to array | `SELECT JSON_ARRAYAGG(name) FROM ...` |

---

### 4. Constraints

```sql
-- All constraint types
CREATE TABLE Orders (
    OrderID         INT IDENTITY(1,1),
    CustomerID      INT         NOT NULL,
    OrderDate       DATE        NOT NULL DEFAULT GETDATE(),
    Status          VARCHAR(20) NOT NULL DEFAULT 'Pending'
        CHECK (Status IN ('Pending','Shipped','Delivered','Cancelled')),
    TotalAmount     DECIMAL(12,2) NOT NULL CHECK (TotalAmount >= 0),
    DiscountCode    VARCHAR(10) NULL,

    -- Primary Key
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID),

    -- Foreign Key with cascade
    CONSTRAINT FK_Orders_Customer FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID)
        ON DELETE NO ACTION ON UPDATE CASCADE,

    -- Unique constraint
    CONSTRAINT UQ_Orders_DiscountCode UNIQUE (DiscountCode)
        WHERE DiscountCode IS NOT NULL,  -- Filtered unique

    -- Check constraint (table-level)
    CONSTRAINT CK_Orders_ValidTotal CHECK (TotalAmount <= 1000000)
);

-- Default constraint on existing table
ALTER TABLE Orders ADD CONSTRAINT DF_Orders_CreatedAt
DEFAULT SYSUTCDATETIME() FOR CreatedAt;
```

**Constraint Best Practices:**

- Name all constraints explicitly (easier to manage/drop)
- Use `CHECK` for business rules at DB level
- `FK` with `ON DELETE CASCADE` carefully - can cause cascade deletes
- Filtered indexes/constraints for sparse data (e.g., `WHERE DiscountCode IS NOT NULL`)

---

### 5. SEQUENCES

```sql
-- Create sequence
CREATE SEQUENCE dbo.OrderNumberSeq
    AS BIGINT
    START WITH 100000
    INCREMENT BY 1
    MINVALUE 100000
    MAXVALUE 999999
    CYCLE  -- Restart at MINVALUE after MAXVALUE
    CACHE 1000;  -- Performance: pre-allocate numbers (gap risk on crash)

-- Use sequence
INSERT INTO Orders (OrderNumber, CustomerID)
VALUES (NEXT VALUE FOR dbo.OrderNumberSeq, @CustomerID);

-- Get next without inserting
SELECT NEXT VALUE FOR dbo.OrderNumberSeq;

-- Reset sequence
ALTER SEQUENCE dbo.OrderNumberSeq RESTART WITH 100000;
```

**Sequence vs Identity:**
| Feature | IDENTITY | SEQUENCE |
|---------|----------|----------|
| Scope | Single table | Database-wide |
| Control | Limited | Full (cache, cycle, increment) |
| Gaps | On rollback | On cache + crash |
| Performance | Good | Better with CACHE |

---

### 6. Partitioning

```sql
-- 1. Partition Function (boundary values)
CREATE PARTITION FUNCTION pf_OrderDate (DATE)
AS RANGE RIGHT FOR VALUES (
    '2022-01-01', '2023-01-01', '2024-01-01', '2025-01-01'
);

-- 2. Partition Scheme (filegroups)
CREATE PARTITION SCHEME ps_OrderDate
AS PARTITION pf_OrderDate
TO (FG_2022, FG_2023, FG_2024, FG_2025, FG_Current);

-- 3. Partitioned Table
CREATE TABLE dbo.Orders (
    OrderID     BIGINT IDENTITY,
    OrderDate   DATE NOT NULL,
    CustomerID  INT NOT NULL,
    Amount      DECIMAL(12,2),
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID, OrderDate)  -- Must include partition key
)
ON ps_OrderDate(OrderDate);

-- Partitioned Index (aligned)
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders (CustomerID)
ON ps_OrderDate(OrderDate);

-- Partition Maintenance
-- Switch out old partition (metadata only, instant)
ALTER TABLE dbo.Orders SWITCH PARTITION 1 TO dbo.Orders_Archive PARTITION 1;

-- Merge/Split boundaries
ALTER PARTITION FUNCTION pf_OrderDate() SPLIT RANGE ('2026-01-01');
ALTER PARTITION FUNCTION pf_OrderDate() MERGE RANGE ('2022-01-01');
```

**Partitioning Rules:**

- Partition key must be part of PK and all unique indexes
- Aligned indexes = same partition scheme as table
- `SWITCH` requires identical schema, constraints, indexes
- Use `RANGE RIGHT` (default) for date partitions (boundary = start of next)

---

## 🧪 Hands-On Labs

Run these from `MyLabs/01-create-database-objects/`:

```bash
# Execute in order
1. Create-core-tables-w-constraints.sql
2. Create-temporal-table-for-price-history.sql
3. Create-a-partitioned-order-table.sql
4. Add-JSON-Cols-for-metadata.sql
5. Create-order-det-w-SEQUENCE.sql
6. Insert-sample-data-into-tables.sql
7. Query-the-JSON-data.sql
8. Query-price-history.sql
```

---

## 📝 Practice Questions

### Question 1

You need to store product metadata as JSON with an index on the `category` property. Which approach is most efficient?

A) `CREATE INDEX IX_Meta_Cat ON Products (JSON_VALUE(Metadata, '$.category'))`
B) Add computed column `Category AS JSON_VALUE(Metadata, '$.category') PERSISTED`, then index it
C) Use `OPENJSON` in a view with clustered index
D) Store category in a separate column

**Answer: B** - Computed column + index allows seeks; JSON_VALUE in index definition not directly supported.

### Question 2

A temporal table `ProductPrice` has history table `ProductPriceHistory`. You need to find the price of ProductID 50 as of '2024-06-15'. Which query is correct?

A) `SELECT Price FROM ProductPrice WHERE ProductID = 50 AND ValidFrom <= '2024-06-15' ORDER BY ValidFrom DESC`
B) `SELECT Price FROM ProductPrice FOR SYSTEM_TIME AS OF '2024-06-15' WHERE ProductID = 50`
C) `SELECT Price FROM ProductPriceHistory WHERE ProductID = 50 AND ValidTo > '2024-06-15'`
D) `SELECT Price FROM ProductPrice FOR SYSTEM_TIME BETWEEN '2024-01-01' AND '2024-12-31' WHERE ProductID = 50`

**Answer: B** - `FOR SYSTEM_TIME AS OF` returns row valid at that point in time.

### Question 3

You create a partitioned table on `OrderDate` with monthly boundaries. The PK must include `OrderDate`. Why?

A) To enable partition elimination
B) SQL Server requires partition key in PK for uniqueness enforcement per partition
C) To allow partition switching
D) All of the above

**Answer: D** - All are true. PK must include partition key; enables uniqueness per partition and switching.

### Question 4

Which statement about `SEQUENCE` vs `IDENTITY` is FALSE?

A) SEQUENCE can be shared across tables
B) SEQUENCE with CACHE has no gap risk
C) SEQUENCE supports CYCLE option
D) SEQUENCE allows manual NEXT VALUE FOR

**Answer: B** - CACHE creates gaps on server restart/crash. Identity also has gaps on rollback.

### Question 5

You need a table that prevents ANY modification to existing rows (audit trail). Which table type?

A) Temporal table
B) Ledger table with `APPEND_ONLY = ON`
C) In-memory table
D) Graph table

**Answer: B** - Append-only ledger tables prevent UPDATE/DELETE entirely.

---

## 🎯 Exam Tricks & Gotchas

| Topic              | Trick/Gotcha                                                               |
| ------------------ | -------------------------------------------------------------------------- |
| **Temporal**       | `HIDDEN` columns excluded from `SELECT *`; use `FOR SYSTEM_TIME` clauses   |
| **JSON Index**     | Must use computed column (PERSISTED) for index on JSON property            |
| **Partition PK**   | Partition key MUST be in PK and all unique indexes                         |
| **Sequence Cache** | `CACHE N` improves perf but loses up to N values on crash                  |
| **Ledger**         | `APPEND_ONLY = ON` = insert only; default = updatable with history         |
| **In-Memory**      | No FK/CHECK/DEFAULT; use native SPs; `BUCKET_COUNT` = 1.5-2x expected rows |
| **External Table** | No statistics auto-create; use `UPDATE STATISTICS` manually                |
| **Graph**          | `MATCH` only works in WHERE clause; no recursive CTE support yet           |
| **Filtered Index** | Great for sparse columns (e.g., `WHERE Status = 'Active'`)                 |

---

## 📋 Condensed Cheat Sheet

```sql
-- TEMPORAL TABLE
CREATE TABLE T (ID INT PK, Val INT,
  SysStart DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN,
  SysEnd   DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN,
  PERIOD FOR SYSTEM_TIME (SysStart, SysEnd))
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = T_Hist));

-- QUERY HISTORY
SELECT * FROM T FOR SYSTEM_TIME AS OF '2024-01-01';
SELECT * FROM T FOR SYSTEM_TIME BETWEEN '2024-01-01' AND '2024-12-31';

-- JSON INDEX
ALTER TABLE T ADD jcol NVARCHAR(MAX) CONSTRAINT chk CHECK (ISJSON(jcol)=1);
ALTER TABLE T ADD prop AS JSON_VALUE(jcol, '$.prop') PERSISTED;
CREATE INDEX IX_T_prop ON T(prop);

-- SEQUENCE
CREATE SEQUENCE Seq AS INT START WITH 1 INCREMENT BY 1 CACHE 100;
SELECT NEXT VALUE FOR Seq;

-- PARTITIONING
CREATE PARTITION FUNCTION pf (DATE) AS RANGE RIGHT FOR VALUES ('2024-01-01','2025-01-01');
CREATE PARTITION SCHEME ps AS PARTITION pf ALL TO ([PRIMARY]);
CREATE TABLE T (ID INT, Dt DATE, PRIMARY KEY (ID, Dt)) ON ps(Dt);
ALTER TABLE T SWITCH PARTITION 1 TO T_Archive PARTITION 1;

-- LEDGER (APPEND ONLY)
CREATE TABLE T (ID INT PK, Data NVARCHAR(100)) WITH (LEDGER = ON (APPEND_ONLY = ON));

-- IN-MEMORY
CREATE TABLE T (ID INT PK NONCLUSTERED HASH WITH (BUCKET_COUNT=100000))
WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA);
```

---

## ✅ Day 1 Completion Checklist

- [ ] Read all lab files in `MyLabs/01-create-database-objects/`
- [ ] Execute each lab script and verify results
- [ ] Complete practice questions above (target: 4/5 correct)
- [ ] Memorize cheat sheet syntax patterns
- [ ] Note any weak areas for Day 10 review

---

_Next: Day 2 - Programmability Objects (Views, SPs, Functions, Triggers)_

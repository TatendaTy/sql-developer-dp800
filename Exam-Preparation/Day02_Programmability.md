# Day 2: Programmability Objects

**Date:** September 23, 2026 | **Exam Weight:** 35-40% (Design & Develop Database Solutions)

---

## 🎯 Learning Objectives

- [ ] Create views (standard, indexed, partitioned)
- [ ] Create scalar functions
- [ ] Create table-valued functions (inline vs multi-statement)
- [ ] Create stored procedures with error handling
- [ ] Create triggers (DML, DDL, LOGON)

---

## 📚 Core Concepts

### 1. Views

```sql
-- Standard view
CREATE VIEW dbo.vw_CustomerOrders AS
SELECT c.CustomerID, c.CustomerName, o.OrderID, o.OrderDate, o.TotalAmount
FROM dbo.Customers c
JOIN dbo.Orders o ON c.CustomerID = o.CustomerID;

-- Indexed (materialized) view - requires SCHEMABINDING
CREATE VIEW dbo.vw_OrderSummary
WITH SCHEMABINDING
AS
SELECT CustomerID,
       COUNT_BIG(*) AS OrderCount,        -- Must use COUNT_BIG
       SUM(TotalAmount) AS TotalRevenue,
       MIN(OrderDate) AS FirstOrder,
       MAX(OrderDate) AS LastOrder
FROM dbo.Orders
GROUP BY CustomerID;

-- Unique clustered index required for indexed view
CREATE UNIQUE CLUSTERED INDEX IX_vw_OrderSummary ON dbo.vw_OrderSummary (CustomerID);

-- Partitioned view (across servers/shards)
CREATE VIEW dbo.vw_AllOrders AS
SELECT * FROM Server1.DB.dbo.Orders_2022
UNION ALL
SELECT * FROM Server2.DB.dbo.Orders_2023
UNION ALL
SELECT * FROM Server3.DB.dbo.Orders_2024;
```

**View Requirements for Indexing:**

- `WITH SCHEMABINDING`
- Deterministic expressions only
- No `OUTER JOIN`, `DISTINCT`, `TOP`, `ORDER BY` (without TOP)
- `COUNT_BIG(*)` not `COUNT(*)`
- Base tables must have same owner

---

### 2. Scalar Functions

```sql
-- Scalar function (single value return)
CREATE FUNCTION dbo.fn_CalculateTax (@Amount DECIMAL(18,2), @TaxRate DECIMAL(5,4))
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING, RETURNS NULL ON NULL INPUT
AS
BEGIN
    RETURN ROUND(@Amount * @TaxRate, 2);
END;

-- Usage
SELECT dbo.fn_CalculateTax(TotalAmount, 0.0825) AS Tax FROM Orders;

-- Inline scalar (SQL Server 2019+) - better performance
CREATE OR ALTER FUNCTION dbo.fn_GetCustomerTier (@CustomerID INT)
RETURNS VARCHAR(20)
WITH INLINE = ON
AS
BEGIN
    RETURN (
        SELECT CASE
            WHEN TotalOrders > 100 THEN 'Platinum'
            WHEN TotalOrders > 50 THEN 'Gold'
            WHEN TotalOrders > 10 THEN 'Silver'
            ELSE 'Bronze'
        END
        FROM dbo.CustomerStats WHERE CustomerID = @CustomerID
    );
END;
```

**Scalar Function Performance:**

- Avoid in WHERE/JOIN clauses (runs per row)
- Use `INLINE = ON` (2019+) for automatic inlining
- Prefer inline TVF or computed columns when possible

---

### 3. Table-Valued Functions (TVFs)

```sql
-- Inline TVF (BEST PERFORMANCE - optimized like view)
CREATE FUNCTION dbo.fn_OrdersByCustomer (@CustomerID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT OrderID, OrderDate, TotalAmount, Status
FROM dbo.Orders
WHERE CustomerID = @CustomerID;

-- Multi-statement TVF (use when logic too complex for inline)
CREATE FUNCTION dbo.fn_OrderDetailsWithCalc (@OrderID INT)
RETURNS @Result TABLE (
    OrderID INT,
    ProductName NVARCHAR(100),
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    LineTotal DECIMAL(12,2),
    TaxAmount DECIMAL(12,2)
)
AS
BEGIN
    INSERT @Result
    SELECT od.OrderID, p.ProductName, od.Quantity, od.UnitPrice,
           od.Quantity * od.UnitPrice AS LineTotal,
           ROUND(od.Quantity * od.UnitPrice * 0.0825, 2) AS TaxAmount
    FROM dbo.OrderDetails od
    JOIN dbo.Products p ON od.ProductID = p.ProductID
    WHERE od.OrderID = @OrderID;
    RETURN;
END;

-- Usage (both called same way)
SELECT * FROM dbo.fn_OrdersByCustomer(123);
SELECT * FROM dbo.fn_OrderDetailsWithCalc(456);
```

**Inline vs Multi-Statement TVF:**

| Aspect      | Inline TVF                        | Multi-Statement TVF                         |
| ----------- | --------------------------------- | ------------------------------------------- |
| Performance | Excellent (plan inlining)         | Poor (black box)                            |
| Syntax      | `RETURNS TABLE ... RETURN SELECT` | `RETURNS @Table TABLE ... BEGIN ... RETURN` |
| Statistics  | Uses base table stats             | No stats on table variable                  |
| Use Case    | Simple parameterized queries      | Complex logic, multiple steps               |

---

### 4. Stored Procedures

```sql
-- Best practice template
CREATE OR ALTER PROCEDURE dbo.usp_ProcessOrder
    @OrderID INT,
    @ProcessedBy NVARCHAR(100) = SYSTEM_USER,
    @TrackingNumber VARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;  -- Critical settings

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate
        IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderID = @OrderID)
            THROW 50001, 'Order not found', 1;

        -- Business logic
        UPDATE dbo.Orders
        SET Status = 'Processing',
            ProcessedDate = SYSUTCDATETIME(),
            ProcessedBy = @ProcessedBy
        WHERE OrderID = @OrderID;

        -- Generate tracking
        SET @TrackingNumber = 'TRK' + FORMAT(@OrderID, '00000000') +
                              FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmss');

        INSERT INTO dbo.OrderTracking (OrderID, TrackingNumber, Status, CreatedDate)
        VALUES (@OrderID, @TrackingNumber, 'Processing', SYSUTCDATETIME());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        -- Re-throw with context
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSev INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMsg, @ErrorSev, @ErrorState);
        RETURN -1;
    END CATCH

    RETURN 0;
END;

-- Execute with output parameter
DECLARE @Tracking VARCHAR(50);
EXEC dbo.usp_ProcessOrder @OrderID = 123, @TrackingNumber = @Tracking OUTPUT;
SELECT @Tracking;
```

**Key SP Settings:**

- `SET NOCOUNT ON` - suppresses row count messages (network perf)
- `SET XACT_ABORT ON` - ensures rollback on runtime errors
- `THROW` (SQL 2012+) preferred over `RAISERROR`
- Always check `@@TRANCOUNT` before rollback

---

### 5. Triggers

```sql
-- DML Trigger (AFTER)
CREATE TRIGGER trg_Orders_Audit
ON dbo.Orders
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.OrderAudit (OrderID, ActionType, ChangedBy, ChangedDate, OldData, NewData)
    SELECT
        COALESCE(i.OrderID, d.OrderID),
        CASE
            WHEN i.OrderID IS NULL THEN 'DELETE'
            WHEN d.OrderID IS NULL THEN 'INSERT'
            ELSE 'UPDATE'
        END,
        SYSTEM_USER,
        SYSUTCDATETIME(),
        (SELECT * FROM deleted FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER),
        (SELECT * FROM inserted FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.OrderID = d.OrderID;
END;

-- INSTEAD OF Trigger (for view updates)
CREATE TRIGGER trg_vw_CustomerOrders_InsteadOfInsert
ON dbo.vw_CustomerOrders
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Orders (CustomerID, OrderDate, TotalAmount, Status)
    SELECT CustomerID, OrderDate, TotalAmount, 'Pending'
    FROM inserted;
END;

-- DDL Trigger (database-level)
CREATE TRIGGER trg_PreventDropTable
ON DATABASE
FOR DROP_TABLE, ALTER_TABLE
AS
BEGIN
    IF ORIGINAL_LOGIN() NOT IN ('sa', 'dbo_admin')
    BEGIN
        PRINT 'Unauthorized DDL operation blocked.';
        ROLLBACK;
    END
END;

-- LOGON Trigger
CREATE TRIGGER trg_LimitConnections
ON ALL SERVER
FOR LOGON
AS
BEGIN
    IF ORIGINAL_LOGIN() = 'app_user'
       AND (SELECT COUNT(*) FROM sys.dm_exec_sessions
            WHERE original_login_name = 'app_user' AND is_user_process = 1) > 50
    BEGIN
        ROLLBACK;  -- Reject connection
    END
END;
```

**Trigger Types & Use Cases:**
| Type | Timing | Use Case |
|------|--------|----------|
| `AFTER` | After DML | Auditing, cascading updates |
| `INSTEAD OF` | Replaces DML | Updatable views, complex validation |
| `DDL` | After DDL | Schema change auditing, prevention |
| `LOGON` | On login | Connection limiting, auditing |

**Trigger Gotchas:**

- `inserted`/`deleted` tables - multi-row aware!
- No `RETURN` value; use `RAISERROR`/`THROW` to abort
- Nested triggers controlled by `sp_configure 'nested triggers'`
- Recursive triggers need `RECURSIVE_TRIGGERS` DB option

---

## 🧪 Hands-On Labs

Run these from `MyLabs/02-implement-programmability-objects/`:

```bash
1. 2-Create-a-view-to-simplify-queries.sql
2. 3-Create-a-stored-procedure-to-process-an-order.sql
3. 4-Create-a-scalar-function-for-reusable-calculations.sql
4. 5-Create-an-inline-table-valued-function-(TVF).sql
4. 6-Create-a-trigger-to-log-changes.sql
5. 7.1-test_view_permissions.sql
6. 7.2-test_trigger.sql
```

---

## 📝 Practice Questions

### Question 1

You need a function that returns the top 5 most expensive products for a given category. Which function type?

A) Scalar function with `TOP 5`
B) Inline TVF
C) Multi-statement TVF with cursor
D) Stored procedure with output parameter

**Answer: B** - Inline TVF supports `TOP` and parameterization; optimized like a view.

### Question 2

A stored procedure has `SET XACT_ABORT OFF` (default). A runtime error (e.g., conversion) occurs mid-transaction. What happens?

A) Transaction rolls back automatically
B) Transaction remains open; subsequent statements execute
C) Batch aborts but transaction stays open
D) Error is ignored, execution continues

**Answer: C** - Without `XACT_ABORT ON`, only the statement fails; transaction stays open. Always use `SET XACT_ABORT ON`.

### Question 3

An `AFTER UPDATE` trigger on `Orders` needs to detect if `Status` column changed. Correct approach?

A) `IF UPDATE(Status) ...`
B) `IF COLUMNS_UPDATED() & POWER(2, COLUMNPROPERTY(...)) ...`
C) `IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.OrderID = d.OrderID WHERE i.Status <> d.Status)`
D) Both A and C work; C is more precise

**Answer: D** - `UPDATE()` returns true if column _referenced_ in UPDATE statement (even if value unchanged). Join `inserted`/`deleted` to detect actual value change.

### Question 4

Which statement about indexed views is FALSE?

A) Must use `WITH SCHEMABINDING`
B) Can reference tables from different databases
C) First index must be unique clustered
D) `COUNT_BIG(*)` required instead of `COUNT(*)`

**Answer: B** - Indexed views cannot reference tables from other databases (must be same database).

### Question 5

An `INSTEAD OF INSERT` trigger on a view. The `inserted` table contains 100 rows. How many times does the trigger fire?

A) 100 times (once per row)
B) 1 time (set-based)
C) Depends on `RECURSIVE_TRIGGERS` setting
D) 1 time per batch

**Answer: B** - Triggers fire once per statement, not per row. `inserted` contains all 100 rows.

---

## 🎯 Exam Tricks & Gotchas

| Topic                  | Trick/Gotcha                                                      |
| ---------------------- | ----------------------------------------------------------------- |
| **Inline TVF**         | `WITH INLINE = ON` (2019+) forces inlining even for scalar UDFs   |
| **Indexed View**       | `NOEXPAND` hint forces indexed view usage in Standard Edition     |
| **Scalar UDF**         | In `WHERE` clause = row-by-row execution; avoid!                  |
| **Trigger**            | `inserted`/`deleted` are tables - handle MULTI-ROW operations     |
| **SP Params**          | Default values only for input params; OUTPUT params need variable |
| **THROW vs RAISERROR** | `THROW` preserves stack trace; `RAISERROR` allows custom severity |
| **SCHEMABINDING**      | Prevents base table schema changes that break function/view       |
| **OUTPUT param**       | Must declare variable, pass with `OUTPUT` keyword on EXEC         |

---

## 📋 Condensed Cheat Sheet

```sql
-- VIEW (INDEXED)
CREATE VIEW vw_Summary WITH SCHEMABINDING AS
SELECT CustomerID, COUNT_BIG(*) AS cnt, SUM(Amount) AS total
FROM Orders GROUP BY CustomerID;
CREATE UNIQUE CLUSTERED INDEX IX_vw ON vw_Summary(CustomerID);

-- INLINE TVF (FAST)
CREATE FUNCTION fn_GetOrders(@CustID INT) RETURNS TABLE
WITH SCHEMABINDING AS RETURN
SELECT * FROM Orders WHERE CustomerID = @CustID;

-- MULTI-STATEMENT TVF (SLOW)
CREATE FUNCTION fn_Complex(@ID INT) RETURNS @t TABLE (col INT) AS
BEGIN INSERT @t SELECT ... RETURN; END;

-- STORED PROC TEMPLATE
CREATE PROC usp_Name @Param INT, @OutParam INT OUTPUT AS
BEGIN SET NOCOUNT, XACT_ABORT ON;
  BEGIN TRY BEGIN TRAN; -- logic; COMMIT; END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH END;

-- AFTER TRIGGER (AUDIT)
CREATE TRIGGER trg_Tbl_Audit ON Tbl AFTER INSERT,UPDATE,DELETE AS
BEGIN SET NOCOUNT ON;
  INSERT Audit SELECT *, CASE WHEN i.ID IS NULL THEN 'DEL'
        WHEN d.ID IS NULL THEN 'INS' ELSE 'UPD' END, SYSUSER, SYSDT
  FROM inserted i FULL JOIN deleted d ON i.ID = d.ID; END;

-- INSTEAD OF TRIGGER (VIEW)
CREATE TRIGGER trg_vw_Ins ON vw INSTEAD OF INSERT AS
BEGIN SET NOCOUNT ON; INSERT Tbl SELECT * FROM inserted; END;
```

---

## ✅ Day 2 Completion Checklist

- [ ] Read all lab files in `MyLabs/02-implement-programmability-objects/`
- [ ] Execute each lab script and verify results
- [ ] Complete practice questions above (target: 4/5 correct)
- [ ] Memorize cheat sheet syntax patterns
- [ ] Practice writing SP with TRY/CATCH and output params
- [ ] Note weak areas for Day 10 review

---

_Next: Day 3 - Advanced T-SQL (CTEs, Window Functions, JSON, Regex, Graph, Fuzzy Matching)_

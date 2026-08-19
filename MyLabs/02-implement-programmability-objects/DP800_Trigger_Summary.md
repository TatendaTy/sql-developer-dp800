# Microsoft Certified: SQL AI Developer Associate (DP800) - Trigger Implementation Summary

## Exercise: Create a Trigger to Log Order Total Changes

**File:** `6-Create-a-trigger-to-log-changes.sql`  
**Lab:** `02-implement-programmability-objects`  
**Associated Files:** `7-Next-steps-exercise.sql`

---

## 1. Trigger Creation and Functionality ✅

### Original Trigger Code
```sql
CREATE OR ALTER TRIGGER SalesLT.trg_LogOrderTotalChange
ON SalesLT.SalesOrderDetail
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AffectedOrders AS (
        SELECT SalesOrderID FROM inserted
        UNION
        SELECT SalesOrderID FROM deleted
    ),
    NewTotals AS (
        SELECT d.SalesOrderID, SUM(d.OrderQty * d.UnitPrice) AS Total
        FROM SalesLT.SalesOrderDetail d
        INNER JOIN AffectedOrders a ON d.SalesOrderID = a.SalesOrderID
        GROUP BY d.SalesOrderID
    ),
    InsertedTotals AS (
        SELECT SalesOrderID, SUM(OrderQty * UnitPrice) AS Total
        FROM inserted
        GROUP BY SalesOrderID
    ),
    DeletedTotals AS (
        SELECT SalesOrderID, SUM(OrderQty * UnitPrice) AS Total
        FROM deleted
        GROUP BY SalesOrderID
    )
    INSERT INTO dbo.OrderAudit (OrderID, OldTotal, NewTotal)
    SELECT
        n.SalesOrderID,
        n.Total - ISNULL(i.Total, 0) + ISNULL(d.Total, 0) AS OldTotal,
        n.Total AS NewTotal
    FROM NewTotals n
    LEFT JOIN InsertedTotals i ON n.SalesOrderID = i.SalesOrderID
    LEFT JOIN DeletedTotals d ON n.SalesOrderID = d.SalesOrderID;
END;
```

### Key Components

| Component | Purpose | Exam Focus |
|-----------|---------|------------|
| `inserted` | Pseudo-table with new row versions | `INSERT` has data; `UPDATE` has new values |
| `deleted` | Pseudo-table with old row versions | `UPDATE` has old values; `INSERT` is empty |
| `AffectedOrders` | UNION of `inserted` + `deleted` | All orders impacted by the operation |
| `NewTotals` | Current totals from base table | Already reflects changes (`AFTER` trigger) |
| `InsertedTotals` | Sum of new rows only | Used to calculate `OldTotal` |
| `DeletedTotals` | Sum of old rows only | Used to calculate `OldTotal`; empty on `INSERT` |

### OldTotal Formula Explained
```sql
n.Total - ISNULL(i.Total, 0) + ISNULL(d.Total, 0)
```
- `n.Total` = current total from base table (already changed)
- `- ISNULL(i.Total, 0)` = subtract new row contributions
- `+ ISNULL(d.Total, 0)` = add previous row contributions (0 on INSERT)

### Testing Results ✅

**INSERT Test:**
```sql
INSERT INTO SalesLT.SalesOrderDetail (SalesOrderID, OrderQty, UnitPrice, ModifiedDate)
VALUES (71946, 5, 50.00, GETDATE());
```
- Successfully logged to `dbo.OrderAudit`
- Captured correct `OldTotal` and `NewTotal`

**UPDATE Test:**
```sql
UPDATE TOP (1) SalesLT.SalesOrderDetail 
SET UnitPrice = 60.00 
WHERE SalesOrderID IN (SELECT TOP 1 SalesOrderID FROM SalesLT.SalesOrderDetail);
```
- Successfully logged to `dbo.OrderAudit`
- Row 2 captured: OldTotal = 713.80, NewTotal = 416.90

---

## 2. Indexes for Performance ✅

### Indexes Created (from `7-Next-steps-exercise.sql`)
```sql
CREATE INDEX IX_SalesLT_SalesOrderID ON SalesLT.SalesOrderDetail(SalesOrderID);
CREATE INDEX IX_SalesLT_SalesOrderDetail_OrderQty_UnitPrice 
    ON SalesLT.SalesOrderDetail(OrderQty, UnitPrice);
```

### Why These Indexes Matter

| Index | Improves | Reason |
|-------|----------|--------|
| `IX_SalesLT_SalesOrderID` | `INNER JOIN AffectedOrders a ON d.SalesOrderID = a.SalesOrderID` | Speeds up joining affected orders with detail rows |
| `IX_SalesLT_SalesOrderDetail_OrderQty_UnitPrice` | `SUM(d.OrderQty * d.UnitPrice)` aggregation | Covering index for computed total |

### Performance Monitoring
```sql
-- Check index stats
SELECT idx.name AS IndexName, idx.type_desc, 
       ps.avg_fragmentation_in_percent, ps.page_count
FROM sys.dm_db_index_physical_stats(DB_ID('AdventureWorks2025'), NULL, NULL, NULL, 'LIMITED') ps
JOIN sys.indexes idx ON ps.object_id = idx.object_id AND ps.index_id = idx.index_id
WHERE idx.name LIKE 'IX_SalesLT%';
```

### Exam Tips for DP800
- Indexes on JOIN columns and aggregated columns improve trigger performance
- Use `sys.dm_db_index_physical_stats` to monitor fragmentation
- Nonclustered indexes are ideal for this scenario
- Consider `INCLUDE` clauses for covering indexes

---

## 3. Secure View and Permissions ✅

### View Creation
```sql
CREATE VIEW saleslt.OrderAuditSafeView
AS
SELECT AuditID, OrderID, NewTotal, ChangedAt
FROM dbo.OrderAudit;
```

### Why a View?
- **Least privilege**: Grant permissions on view, not base table
- **Column filtering**: Expose only needed data (exclude `OldTotal` for privacy)
- **Access control**: Users query view, not base table directly

### Permission Granting
```sql
GRANT SELECT ON saleslt.OrderAuditSafeView TO public;
```

### Testing the View
```sql
SELECT * FROM saleslt.OrderAuditSafeView;
-- Returns: AuditID, OrderID, NewTotal, ChangedAt
-- Excludes: OldTotal (for privacy/sensitivity)
```

### Permission Verification
```sql
SELECT * FROM sys.database_permissions
WHERE major_id = OBJECT_ID('saleslt.OrderAuditSafeView');
-- Shows: GRANT SELECT state = G
```

### Exam Tips for DP800
- Views control access to sensitive data (like audit `OldTotal`)
- GRANT on views, not base tables, follows least privilege
- Can add `EXECUTE AS` clause for impersonation
- Row-Level Security (RLS) can restrict row access further
- Always consider compliance when designing audit views

---

## 4. DP800 Exam Quick Reference

### Trigger Concepts
| Topic | Key Point |
|-------|-----------|
| **Trigger Types** | `AFTER` fires after the operation; `INSTEAD OF` replaces it |
| **INSERT vs UPDATE** | `INSERT`: `inserted` has data, `deleted` is empty |
| **UPDATE**: Both `inserted` and `deleted` have rows |
| **Multiple rows** | Triggers process sets; use `GROUP BY` and aggregates |
| **Performance** | Indexes on JOIN columns improve speed |

### Indexing for Triggers
| Concept | Exam Focus |
|---------|------------|
| **Index purpose** | Speed up JOINs and aggregations in trigger CTEs |
| **Key columns** | `SalesOrderID` for JOINs, `OrderQty, UnitPrice` for SUM |
| **Index type** | Nonclustered is typically sufficient |
| **Monitoring** | `sys.dm_db_index_physical_stats` for fragmentation |

### Security Patterns
| Concept | Exam Focus |
|---------|------------|
| **View vs Table** | Grant on views, not base tables |
| **Least privilege** | Users need only what they require |
| **Audit data** | `OldTotal` may be sensitive; exclude from views |
| **RLS** | Row-Level Security for row-level restrictions |

### Common Patterns
| Scenario | Solution |
|----------|----------|
| **Log changes** | Trigger on INSERT/UPDATE with audit table |
| **Calculate totals** | Use `SUM()` with `GROUP BY` in CTEs |
| **Handle multi-line items** | Aggregate across all `inserted`/`deleted` rows |
| **Secure audit data** | Create view excluding sensitive columns |

---

## 5. Files Created/Modified

| File | Purpose |
|------|---------|
| `6-Create-a-trigger-to-log-changes.sql` | Original trigger exercise |
| `7-Next-steps-exercise.sql` | Indexes already added |
| `test_trigger.sql` | Trigger creation and testing |
| `test_view_permissions.sql` | View and permissions testing |
| `DP800_Trigger_Summary.md` | This summary document |

---

## 6. DP800 Exam Practice Questions

### Question 1: Trigger Mechanics
**Q:** In an `AFTER INSERT` trigger on `SalesLT.SalesOrderDetail`, what will the `deleted` pseudo-table contain?
**A:** Empty set / NULL values (no previous row versions on INSERT)

### Question 2: Index Design
**Q:** Which index would most improve the performance of the trigger's `INNER JOIN` operation?
**A:** `IX_SalesLT_SalesOrderID ON SalesLT.SalesOrderDetail(SalesOrderID)`

### Question 3: Security
**Q:** Why should you grant SELECT permission on a view instead of the base table?
**A:** Follows least privilege principle; controls exactly what data users can access

### Question 4: Multiple Line Items
**Q:** How does the trigger handle orders with multiple line items?
**A:** Uses `GROUP BY d.SalesOrderID` to aggregate across all line items per order

### Question 5: OldTotal Calculation
**Q:** What does `n.Total - ISNULL(i.Total, 0) + ISNULL(d.Total, 0)` calculate?
**A:** The old total by subtracting new contributions and adding old contributions

---

## 7. Key Takeaways for Exam Success

✅ **Triggers** process sets of rows, not single rows  
✅ **Always use SET-based operations** (not cursors) in triggers  
✅ **Indexes on JOIN columns** improve trigger performance significantly  
✅ **GROUP BY and aggregates** handle multiple line items correctly  
✅ **Grant permissions on views**, not base tables (least privilege)  
✅ **Exclude sensitive data** from views (e.g., `OldTotal` in audit tables)  
✅ **Monitor index health** with `sys.dm_db_index_physical_stats`  
✅ **Understand `inserted`/`deleted`** pseudo-table behavior for INSERT/UPDATE  

---
*Generated for DP800 Exam Preparation*  
*Current Date: 2026-08-13*
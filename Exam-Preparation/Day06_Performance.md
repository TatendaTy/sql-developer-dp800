# Day 6: Performance Optimization

**Date:** September 27, 2026 | **Exam Weight:** 35-40% (Secure, Optimize, Deploy)

---

## 🎯 Learning Objectives

- [ ] Database configurations (MAXDOP, memory, tempdb)
- [ ] Transaction isolation levels and concurrency controls
- [ ] Query execution plans (estimated vs actual)
- [ ] DMVs for performance monitoring
- [ ] Query Store configuration and analysis
- [ ] Query Performance Insight (Azure SQL)
- [ ] Blocking and deadlocks identification and resolution

---

## 📚 Core Concepts

### 1. Database Configuration Settings

```sql
-- MAXDOP (Max Degree of Parallelism)
-- Instance level
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'max degree of parallelism', 8;  -- 0 = all CPUs, 1 = no parallelism
RECONFIGURE;

-- Database level (SQL Server 2016+ / Azure SQL)
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 4;

-- Query level hint
SELECT * FROM LargeTable OPTION (MAXDOP 2);

-- Cost Threshold for Parallelism
EXEC sp_configure 'cost threshold for parallelism', 50;  -- Default 5, increase to 25-50
RECONFIGURE;

-- Memory Settings
EXEC sp_configure 'max server memory (MB)', 122880;  -- Leave 4-8GB for OS
RECONFIGURE;
EXEC sp_configure 'min server memory (MB)', 4096;
RECONFIGURE;

-- TempDB Configuration (critical for performance)
-- Multiple data files (1 per logical CPU up to 8)
ALTER DATABASE tempdb ADD FILE (NAME = 'tempdev2', FILENAME = 'D:\Data\tempdb2.ndf', SIZE = 1GB, FILEGROWTH = 512MB);
ALTER DATABASE tempdb ADD FILE (NAME = 'tempdev3', FILENAME = 'D:\Data\tempdb3.ndf', SIZE = 1GB, FILEGROWTH = 512MB);
-- ... up to 8 files
-- Trace flag 1117/1118 (autogrow all files equally) - default ON in 2016+

-- Check tempdb contention
SELECT * FROM sys.dm_os_waiting_tasks
WHERE resource_description LIKE '2:%:%';  -- PFS/GAM/SGAM contention
```

**Key Config Values:**
| Setting | Recommended | Notes |
|---------|-------------|-------|
| MAXDOP | # cores up to 8 | 0 = unlimited (bad), 1 = no parallelism |
| Cost Threshold | 25-50 | Default 5 is too low |
| Max Memory | Total - 4-8GB | Never use default (unlimited) |
| TempDB Files | Min(8, logical CPUs) | Equal size, same growth |
| Instant File Init | Enabled | For data files (not log) |

---

### 2. Transaction Isolation Levels

```sql
-- Read Committed (Default)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- Shared locks released immediately after read
-- Non-repeatable reads, phantoms possible

-- Read Committed Snapshot (RCSI) - Recommended default
ALTER DATABASE MyDB SET READ_COMMITTED_SNAPSHOT ON;
-- Readers don't block writers, writers don't block readers
-- Uses row versioning in tempdb
-- Must be only connection to DB when enabling

-- Snapshot Isolation
ALTER DATABASE MyDB SET ALLOW_SNAPSHOT_ISOLATION ON;
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
-- Transaction-level snapshot; all reads consistent
-- Update conflicts possible (error 3960)

-- Repeatable Read
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Holds shared locks until transaction end
-- Prevents non-repeatable reads; phantoms possible

-- Serializable
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Range locks prevent phantoms
-- Highest isolation, most blocking

-- Read Uncommitted (NOLOCK) - Avoid!
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- Dirty reads; data corruption risk
-- Equivalent to WITH (NOLOCK) hint
```

**Isolation Level Comparison:**
| Level | Dirty Read | Non-Repeatable | Phantom | Locking |
|-------|------------|----------------|---------|---------|
| Read Uncommitted | Yes | Yes | Yes | None |
| Read Committed | No | Yes | Yes | Row (S) |
| RCSI | No | Yes | Yes | Versioning |
| Repeatable Read | No | No | Yes | Row (S) held |
| Snapshot | No | No | No | Versioning |
| Serializable | No | No | No | Range (S) |

---

### 3. Concurrency: Blocking & Deadlocks

```sql
-- Find blocking sessions
SELECT
    blocking_session_id AS Blocker,
    session_id AS Victim,
    wait_type,
    wait_time_ms,
    wait_resource,
    t.text AS BlockerQuery
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE blocking_session_id > 0;

-- Detailed blocking chain
WITH Blocking AS (
    SELECT session_id, blocking_session_id, wait_type, wait_time_ms,
           CAST('' AS VARCHAR(MAX)) AS query_text
    FROM sys.dm_exec_requests
    WHERE blocking_session_id = 0 AND session_id IN (
        SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0
    )
    UNION ALL
    SELECT r.session_id, r.blocking_session_id, r.wait_type, r.wait_time_ms,
           t.text
    FROM sys.dm_exec_requests r
    JOIN Blocking b ON r.blocking_session_id = b.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.blocking_session_id > 0
)
SELECT * FROM Blocking;

-- Deadlock detection (system_health extended event)
-- Or enable trace flags 1204/1222 (legacy)
-- Better: Query Store / Extended Events

-- Deadlock graph from system_health
SELECT
    CAST(event_data AS XML) AS DeadlockGraph
FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
WHERE event_data LIKE '%<deadlock>%';

-- Common deadlock patterns:
-- 1. Key lookup deadlock: SELECT vs UPDATE on same rows different indexes
-- 2. Foreign key deadlock: Parent/Child updates in different order
-- 3. Index maintenance: Page splits during concurrent inserts
```

**Deadlock Prevention:**

- Access tables in consistent order
- Keep transactions short
- Use appropriate indexes (covering queries)
- Consider `ROWLOCK` / `UPDLOCK` hints carefully
- Enable `READ_COMMITTED_SNAPSHOT` to reduce blocking

---

### 4. Query Execution Plans

```sql
-- Estimated Plan (Ctrl+L in SSMS)
SET SHOWPLAN_XML ON;
SELECT * FROM Orders WHERE CustomerID = 123;
SET SHOWPLAN_XML OFF;

-- Actual Plan (Ctrl+M in SSMS)
SET STATISTICS XML ON;
SELECT * FROM Orders WHERE CustomerID = 123;
SET STATISTICS XML OFF;

-- Key Plan Operators to Recognize:
-- Table Scan / Clustered Index Scan = Full scan (bad for large tables)
-- Index Seek = Good (uses index)
-- Key Lookup = Bookmark lookup (add INCLUDE columns)
-- Sort = Expensive (memory grant, spill to tempdb)
-- Hash Match = Join/aggregate (memory intensive)
-- Nested Loops = Good for small outer input
-- Merge Join = Good for sorted inputs
-- Parallelism (Gather Streams) = Parallel plan

-- Plan Analysis Checklist:
-- 1. Estimated vs Actual rows (parameter sniffing?)
-- 2. Missing index warnings (green text in SSMS)
-- 3. Warnings: missing stats, implicit conversion, spill
-- 4. Operator costs (% of total)
-- 5. Memory grant vs used
```

**Sargability (Search ARGument ABILITY):**

```sql
-- Sargable (Index Seek)
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'
WHERE CustomerID = 123
WHERE Name LIKE 'Smith%'  -- Leading wildcard OK

-- Non-Sargable (Index Scan)
WHERE YEAR(OrderDate) = 2024
WHERE CustomerID + 0 = 123
WHERE Name LIKE '%Smith%'
WHERE ISNULL(Status, '') = 'Active'
WHERE DATEDIFF(DAY, OrderDate, GETDATE()) < 30

-- Fix: Rewrite to sargable form
WHERE OrderDate >= DATEADD(DAY, -30, GETDATE())
```

---

### 5. Dynamic Management Views (DMVs)

```sql
-- Top CPU Queries
SELECT TOP 10
    qs.total_worker_time / qs.execution_count AS avg_cpu_ms,
    qs.execution_count,
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_ms,
    SUBSTRING(qt.text, qs.statement_start_offset/2 + 1,
        (CASE WHEN qs.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
              ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) AS query_text,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY avg_cpu_ms DESC;

-- Top I/O Queries
SELECT TOP 10
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    qs.total_logical_writes / qs.execution_count AS avg_logical_writes,
    qs.execution_count,
    SUBSTRING(qt.text, ...) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_logical_reads DESC;

-- Index Usage Stats
SELECT
    OBJECT_NAME(ius.object_id) AS TableName,
    i.name AS IndexName,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    ius.last_user_scan
FROM sys.dm_db_index_usage_stats ius
JOIN sys.indexes i ON ius.object_id = i.object_id AND ius.index_id = i.index_id
WHERE ius.database_id = DB_ID()
  AND OBJECTPROPERTY(ius.object_id, 'IsUserTable') = 1
ORDER BY ius.user_seeks + ius.user_scans + ius.user_lookups DESC;

-- Missing Indexes
SELECT
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id) + '_' +
        REPLACE(REPLACE(REPLACE(mid.equality_columns, ', ', '_'), '[', ''), ']', '') +
        CASE WHEN mid.inequality_columns IS NOT NULL THEN '_' +
            REPLACE(REPLACE(REPLACE(mid.inequality_columns, ', ', '_'), '[', ''), ']', '') ELSE '' END
        + ' ON ' + OBJECT_SCHEMA_NAME(mid.object_id) + '.' + OBJECT_NAME(mid.object_id)
        + ' (' + ISNULL(mid.equality_columns, '') +
        CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ', ' ELSE '' END +
        ISNULL(mid.inequality_columns, '') + ')'
        + CASE WHEN mid.included_columns IS NOT NULL THEN ' INCLUDE (' + mid.included_columns + ')' ELSE '' END
        AS create_index_statement
FROM sys.dm_db_missing_index_group_stats migs
JOIN sys.dm_db_missing_index_groups mig ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;

-- Wait Statistics
SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    max_wait_time_ms,
    signal_wait_time_ms,
    wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
    'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','HADR_FILESTREAM_IOMGR_IOCOMPLETION',
    'CHECKPOINT_QUEUE','REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','XE_DISPATCHER_JOIN',
    'LOGMGR_QUEUE','FT_IFTS_SCHEDULER_IDLE_WAIT','BROKER_TASK_STOP','CLR_MANUAL_EVENT',
    'CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE','TRACEWRITE','DIRTY_PAGE_POLL',
    'SP_SERVER_DIAGNOSTICS_SLEEP')
ORDER BY wait_time_ms DESC;
```

**Key Wait Types:**
| Wait Type | Category | Action |
|-----------|----------|--------|
| `PAGEIOLATCH_*` | I/O | Add memory, faster storage, better indexes |
| `LCK_M_*` | Blocking | Optimize queries, RCSI, index tuning |
| `CXPACKET` | Parallelism | Check MAXDOP, cost threshold |
| `SOS_SCHEDULER_YIELD` | CPU | Query tuning, add CPU |
| `WRITELOG` | Log I/O | Faster log disk, batch commits |
| `PAGELATCH_*` | Contention | Partition, tempdb files, identity gaps |

---

### 6. Query Store (SQL Server 2016+ / Azure SQL)

```sql
-- Enable Query Store
ALTER DATABASE MyDB SET QUERY_STORE = ON
    (OPERATION_MODE = READ_WRITE,
     CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
     DATA_FLUSH_INTERVAL_SECONDS = 900,
     MAX_STORAGE_SIZE_MB = 1000,
     INTERVAL_LENGTH_MINUTES = 60,
     SIZE_BASED_CLEANUP_MODE = AUTO,
     QUERY_CAPTURE_MODE = AUTO);  -- Or ALL for everything

-- Query Store Views
-- sys.query_store_query_text - query text
-- sys.query_store_query - query metadata
-- sys.query_store_plan - execution plans
-- sys.query_store_runtime_stats - aggregated runtime stats
-- sys.query_store_runtime_stats_interval - time intervals

-- Top Regressed Queries (performance regression)
SELECT
    q.query_id,
    qt.query_sql_text,
    rs.avg_duration,
    rs.avg_logical_io_reads,
    rs.avg_cpu_time,
    rs.count_executions,
    p.plan_id,
    p.is_forced_plan
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
ORDER BY rs.avg_duration DESC;

-- Force Plan (plan pinning)
EXEC sp_query_store_force_plan @query_id = 123, @plan_id = 456;

-- Unforce Plan
EXEC sp_query_store_unforce_plan @query_id = 123, @plan_id = 456;

-- Parameter Sniffing Detection
SELECT
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    rs.avg_duration,
    p.query_plan
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE q.query_id IN (
    SELECT query_id FROM sys.query_store_plan
    GROUP BY query_id HAVING COUNT(DISTINCT plan_id) > 1
);
```

---

### 7. Query Performance Insight (Azure SQL)

```sql
-- Available in Azure SQL Database / Managed Instance
-- Portal: Database → Query Performance Insight

-- Programmatic access via DMVs (same as Query Store)
-- Azure-specific: sys.dm_db_resource_stats (DTU/CPU/IO)
SELECT * FROM sys.dm_db_resource_stats
ORDER BY end_time DESC;

-- Resource governance
SELECT * FROM sys.dm_user_db_resource_governance;
```

---

### 8. Indexing Strategies

```sql
-- Covering Index (INCLUDE columns)
CREATE INDEX IX_Orders_CustomerID_Covering
ON dbo.Orders (CustomerID)
INCLUDE (OrderDate, TotalAmount, Status);

-- Filtered Index (partial data)
CREATE INDEX IX_Orders_Active
ON dbo.Orders (CustomerID, OrderDate)
WHERE Status = 'Active';  -- Only 10% of rows

-- Columnstore Index (Analytics)
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales ON FactSales;
-- Or nonclustered for hybrid
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FactSales
ON FactSales (DateKey, ProductKey, CustomerKey, SalesAmount);

-- Index Maintenance
-- Rebuild (offline/online)
ALTER INDEX ALL ON dbo.Orders REBUILD WITH (ONLINE = ON, MAXDOP = 4);
-- Reorganize (always online, less aggressive)
ALTER INDEX ALL ON dbo.Orders REORGANIZE;

-- Fragmentation Check
SELECT
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
  AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

---

## 🧪 Hands-On Labs

Run these from `MyLabs/06-optimize-database-performance/`:

```bash
# Review all files in this folder
```

**Practice Exercises:**

1. Enable Query Store, run workload, identify top queries
2. Analyze execution plans for missing index warnings
3. Set up extended event session for deadlocks
4. Configure RCSI and test concurrency
5. Run index fragmentation analysis

---

## 📝 Practice Questions

### Question 1

A query has `WHERE YEAR(OrderDate) = 2024`. The `OrderDate` column has an index. Why index scan?

A) Index is fragmented
B) Function on column prevents seek (non-sargable)
C) Statistics outdated
D) Parameter sniffing

**Answer: B** - Function on column (`YEAR()`) makes predicate non-sargable. Rewrite: `WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'`.

### Question 2

`READ_COMMITTED_SNAPSHOT` is ON. Session A updates a row. Session B reads same row. What does B see?

A) Blocks until A commits
B) Sees old committed version (before A's update)
C) Sees A's uncommitted change
D) Error

**Answer: B** - RCSI uses row versioning; readers see last committed version, no blocking.

### Question 3

Deadlock: Session 1 updates Table A then Table B. Session 2 updates Table B then Table A. Prevention?

A) Increase lock timeout
B) Access tables in same order in both sessions
C) Use NOLOCK hints
D) Disable parallelism

**Answer: B** - Consistent access order prevents circular wait condition.

### Question 4

Query Store shows two plans for same query_id. One is 10x slower. Likely cause?

A) Statistics update
B) Parameter sniffing
C) Index rebuild
D) MAXDOP change

**Answer: B** - Parameter sniffing causes different plans for different parameter values; multiple plans in Query Store is classic sign.

### Question 5

`sys.dm_os_wait_stats` shows high `PAGEIOLATCH_SH` waits. Best action?

A) Add CPU
B) Increase MAXDOP
C) Add memory / improve I/O / add indexes
D) Enable RCSI

**Answer: C** - PAGEIOLATCH = waiting for data pages from disk. Fix: more memory (buffer pool), faster storage, or better indexes to reduce reads.

---

## 🎯 Exam Tricks & Gotchas

| Topic                  | Trick/Gotcha                                                                            |
| ---------------------- | --------------------------------------------------------------------------------------- |
| **RCSI**               | Must be only user in DB when enabling; uses tempdb version store (size tempdb!)         |
| **Query Store**        | `QUERY_CAPTURE_MODE = AUTO` ignores ad-hoc/low-cost queries; use `ALL` for full capture |
| **Plan Forcing**       | Only forces specific plan; if schema changes, plan may become invalid                   |
| **Parameter Sniffing** | Fixes: `OPTION (RECOMPILE)`, `OPTIMIZE FOR UNKNOWN`, plan guide, Query Store force plan |
| **CXPACKET**           | Not always bad; high CXPACKET + low CPU = parallelism overhead; tune cost threshold     |
| **Missing Index DMV**  | Suggestions are per-query; consolidate, test before creating; don't blindly create      |
| **Index Rebuild**      | `ONLINE = ON` (Enterprise/Dev/Azure); `RESUMABLE = ON` for large indexes (2017+)        |
| **Blocking**           | `sys.dm_exec_requests` shows current; `sys.dm_tran_locks` shows lock details            |
| **Deadlock**           | Extended Events (system_health) captures automatically; query `system_health*.xel`      |
| **Sargability**        | Implicit conversion (int vs varchar) kills seeks; check `CONVERT_IMPLICIT` in plan      |

---

## 📋 Condensed Cheat Sheet

```sql
-- CONFIG
EXEC sp_configure 'max degree of parallelism', 8; RECONFIGURE;
EXEC sp_configure 'cost threshold for parallelism', 50; RECONFIGURE;
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 4;
ALTER DATABASE DB SET READ_COMMITTED_SNAPSHOT ON;

-- ISOLATION LEVELS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- Default
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;        -- Needs ALLOW_SNAPSHOT_ISOLATION ON
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;    -- Range locks

-- BLOCKING
SELECT * FROM sys.dm_exec_requests WHERE blocking_session_id > 0;
SELECT * FROM sys.dm_tran_locks WHERE request_status = 'WAIT';

-- DEADLOCK (system_health XE)
SELECT CAST(event_data AS XML) FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
WHERE event_data LIKE '%<deadlock>%';

-- EXECUTION PLAN KEYS
-- Table Scan = Bad | Index Seek = Good | Key Lookup = Add INCLUDE | Sort = Memory/Spill

-- DMV TOP QUERIES
SELECT TOP 10 qs.total_worker_time/qs.execution_count AS avg_cpu, ...
FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_cpu DESC;

-- MISSING INDEXES
SELECT migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks+migs.user_scans) AS impact, ...
FROM sys.dm_db_missing_index_group_stats migs ... ORDER BY impact DESC;

-- QUERY STORE
ALTER DATABASE DB SET QUERY_STORE = ON (OPERATION_MODE=READ_WRITE, QUERY_CAPTURE_MODE=AUTO);
EXEC sp_query_store_force_plan @query_id=123, @plan_id=456;

-- WAIT STATS
SELECT wait_type, wait_time_ms FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN ('CLR_SEMAPHORE','LAZYWRITER_SLEEP',...) ORDER BY wait_time_ms DESC;

-- INDEX FRAGMENTATION
SELECT OBJECT_NAME(ips.object_id), i.name, ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,'LIMITED') ips
JOIN sys.indexes i ON ips.object_id=i.object_id AND ips.index_id=i.index_id
WHERE ips.avg_fragmentation_in_percent > 10 AND ips.page_count > 1000;
```

---

## ✅ Day 6 Completion Checklist

- [ ] Read all lab files in `MyLabs/06-optimize-database-performance/`
- [ ] Execute each lab script and verify results
- [ ] Complete practice questions (target: 4/5 correct)
- [ ] Memorize cheat sheet syntax patterns
- [ ] Practice: Analyze execution plans, query DMVs, enable Query Store
- [ ] Note weak areas for Day 10 review

---

_Next: Day 7 - CI/CD with SQL Database Projects_

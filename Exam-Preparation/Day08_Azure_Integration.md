# Day 8: Azure Integration

**Date:** September 29, 2026 | **Exam Weight:** 35-40% (Secure, Optimize, Deploy)

---

## Learning Objectives

- [ ] Data API Builder (DAB): config, entities, REST/GraphQL, caching, pagination
- [ ] Expose SPs, views, GraphQL relationships
- [ ] DAB deployment (Container Apps, Functions, Kubernetes)
- [ ] Azure Monitor: Application Insights, Log Analytics
- [ ] Change event streaming: CDC, Change Tracking, CES, SQL trigger bindings, Logic Apps

---

## Core Concepts

### 1. Data API Builder (DAB) Configuration

```json
// dab-config.json
{
  "version": "v1.0.0",
  "source": {
    "connection-string": "@env('SQL_CONNECTION_STRING')",
    "object": "dbo"
  },
  "entities": {
    "customers": {
      "source": "dbo.Customers",
      "rest": {
        "path": "customers",
        "methods": ["GET", "POST", "PUT", "PATCH", "DELETE"],
        "caching": {
          "enabled": true,
          "max-age": 60,
          "stale-while-revalidate": 30
        },
        "pagination": {
          "enabled": true,
          "max-page-size": 100,
          "default-page-size": 20
        },
        "filtering": {
          "enabled": true,
          "fields": ["CustomerName", "Email", "CreatedDate"]
        },
        "sorting": {
          "enabled": true,
          "fields": ["CustomerName", "CreatedDate"]
        }
      },
      "graphql": {
        "type": "Customer",
        "queries": ["customer", "customers"],
        "mutations": ["createCustomer", "updateCustomer", "deleteCustomer"]
      },
      "permissions": [
        { "role": "anonymous", "actions": ["read"] },
        { "role": "authenticated", "actions": ["*"] }
      ]
    },
    "orders": {
      "source": "dbo.Orders",
      "rest": { "path": "orders", "methods": ["GET", "POST"] },
      "graphql": {
        "type": "Order",
        "queries": ["order", "orders"],
        "relationships": {
          "customer": {
            "type": "Customer",
            "source": "dbo.Customers",
            "join": { "field": "CustomerID", "targetField": "CustomerID" }
          },
          "items": {
            "type": "[OrderItem]",
            "source": "dbo.OrderItems",
            "join": { "field": "OrderID", "targetField": "OrderID" }
          }
        }
      }
    }
  },
  "runtime": {
    "rest": { "enabled": true, "host": { "mode": "development" } },
    "graphql": { "enabled": true, "path": "/graphql" }
  },
  "security": {
    "authentication": {
      "provider": "EntraID",
      "audiences": ["api://my-app-id"],
      "claims": ["roles", "scp"]
    },
    "authorization": {
      "roles": {
        "reader": ["read"],
        "writer": ["create", "update", "delete"]
      }
    }
  }
}
```

---

### 2. DAB Entities & Relationships

```json
// Exposing Stored Procedures
"entities": {
  "processOrder": {
    "source": "dbo.usp_ProcessOrder",
    "rest": { "path": "process-order", "methods": ["POST"] },
    "graphql": {
      "type": "ProcessOrderResult",
      "mutations": ["processOrder"]
    },
    "parameters": [
      { "name": "@OrderID", "type": "Int", "required": true },
      { "name": "@TrackingNumber", "type": "String", "direction": "Output" }
    ]
  },
  "getCustomerSummary": {
    "source": "dbo.vw_CustomerOrderSummary",
    "rest": { "path": "customers/{CustomerID}/summary", "methods": ["GET"] },
    "graphql": {
      "type": "CustomerSummary",
      "queries": ["customerSummary"]
    }
  }
}

// GraphQL Relationships (Auto-resolved)
"entities": {
  "orders": {
    "source": "dbo.Orders",
    "graphql": {
      "relationships": {
        "customer": {
          "type": "Customer",
          "source": "dbo.Customers",
          "join": { "field": "CustomerID", "targetField": "CustomerID" },
          "cardinality": "one-to-one"
        },
        "items": {
          "type": "[OrderItem]",
          "source": "dbo.OrderItems",
          "join": { "field": "OrderID", "targetField": "OrderID" },
          "cardinality": "one-to-many"
        }
      }
    }
  }
}
```

---

### 3. DAB Deployment

```yaml
# Azure Container Apps Deployment (dab-config.json + Dockerfile)
# Dockerfile
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest
COPY dab-config.json /App/dab-config.json
EXPOSE 5000
ENTRYPOINT ["dotnet", "DataApiBuilder.dll"]

# GitHub Actions for Container Apps
- name: Deploy DAB to Container Apps
  uses: azure/container-apps-deploy-action@v2
  with:
    container-app-name: dab-api
    resource-group: rg-dab
    image: ${{ secrets.ACR_LOGIN_SERVER }}/dab-api:${{ github.sha }}
    env-vars: |
      SQL_CONNECTION_STRING=${{ secrets.SQL_CONNECTION_STRING }}
      ASPNETCORE_ENVIRONMENT=Production

# Azure Functions Deployment (SQL Trigger Binding)
# function.json
{
  "bindings": [
    {
      "name": "changes",
      "type": "sqlTrigger",
      "direction": "in",
      "tableName": "dbo.Orders",
      "connectionStringSetting": "SQL_CONNECTION_STRING"
    }
  ]
}

# Kubernetes Deployment (Helm)
# helm install dab oci://ghcr.io/azure/data-api-builder/charts/data-api-builder \
#   --set config.connectionString="..." \
#   --set replicaCount=3
```

---

### 4. Azure Monitor Integration

```sql
-- Enable Azure Monitor for SQL Database
-- Portal: SQL Database -> Monitoring -> Diagnostic Settings -> Add Diagnostic Setting
-- Send to: Log Analytics Workspace, Storage Account, Event Hub

-- Key Metrics to Monitor:
-- CPU percentage, DTU percentage, Data IO percentage, Log IO percentage
-- Storage percentage, Sessions percentage, Workers percentage
-- Deadlock count, Blocked connections, Query duration

-- Application Insights for DAB
-- Add to dab-config.json:
{
  "runtime": {
    "telemetry": {
      "applicationInsights": {
        "connectionString": "@env('APPINSIGHTS_CONNECTION_STRING')",
        "enabled": true
      }
    }
  }
}

-- Log Analytics Queries (KQL)
-- Slow queries
AzureDiagnostics
| where ResourceType == "SQLDATABASES"
| where Category == "QueryStoreRuntimeStatistics"
| extend AvgDuration = avg_duration / 1000.0
| where AvgDuration > 1000
| project TimeGenerated, query_id, AvgDuration, execution_count

-- Deadlocks
AzureDiagnostics
| where Category == "Deadlock"
| project TimeGenerated, error_number, error_message

-- Blocking
AzureDiagnostics
| where Category == "Blocking"
| project TimeGenerated, blocked_process, blocking_process
```

---

### 5. Change Event Streaming

```sql
-- 1. Change Data Capture (CDC) - Full history
-- Enable at database level
EXEC sys.sp_cdc_enable_db;

-- Enable on table
EXEC sys.sp_cdc_enable_table
  @source_schema = 'dbo',
  @source_name = 'Orders',
  @role_name = NULL,
  @supports_net_changes = 1;

-- Query CDC changes
DECLARE @from_lsn BINARY(10), @to_lsn BINARY(10);
SELECT @from_lsn = sys.fn_cdc_get_min_lsn('dbo_Orders');
SELECT @to_lsn = sys.fn_cdc_get_max_lsn();
SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_Orders(@from_lsn, @to_lsn, 'all');

-- 2. Change Tracking - Lightweight (net changes only)
ALTER DATABASE MyDB SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);

ALTER TABLE dbo.Orders ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

-- Query changes
DECLARE @last_sync_version BIGINT = CHANGE_TRACKING_CURRENT_VERSION();
-- Later...
SELECT * FROM CHANGETABLE(CHANGES dbo.Orders, @last_sync_version) AS CT
JOIN dbo.Orders O ON CT.OrderID = O.OrderID;

-- 3. Change Event Streaming (CES) - Real-time to Event Hub
-- Enable CES on database
ALTER DATABASE MyDB SET CHANGE_FEED = ON;

-- Read change feed (Azure Function / Logic Apps)
-- Uses same syntax as CDC but streams to Event Hub automatically

-- 4. Azure Functions SQL Trigger Binding
-- Requires: Azure Functions SQL Extension
// function.json
{
  "bindings": [
    {
      "name": "changes",
      "type": "sqlTrigger",
      "direction": "in",
      "tableName": "dbo.Orders",
      "connectionStringSetting": "SQL_CONNECTION_STRING",
      "triggerOn": "Insert,Update,Delete"
    }
  ]
}

// Function code (C#)
[FunctionName("OrderChanged")]
public static void Run(
    [SqlTrigger("dbo.Orders", "SQL_CONNECTION_STRING")] IReadOnlyList<SqlChange<Order>> changes,
    ILogger log)
{
    foreach (var change in changes)
    {
        log.LogInformation($"Order {change.Item.OrderID} {change.Operation}");
        // Process: send to Service Bus, update cache, etc.
    }
}

-- 5. Azure Logic Apps
-- Trigger: "When a row is modified (V2)" for SQL Server
-- Actions: Transform, HTTP call, Send email, etc.
-- Visual designer - no code required
```

---

### 6. Comparing Change Capture Options

| Feature            | CDC                | Change Tracking  | CES            | SQL Trigger  | Logic Apps   |
| ------------------ | ------------------ | ---------------- | -------------- | ------------ | ------------ |
| **Latency**        | Near real-time     | Polling-based    | Real-time      | Real-time    | Polling      |
| **History**        | Full (all changes) | Net changes only | Full           | Full         | Configurable |
| **Schema Changes** | Handled            | Manual           | Handled        | Handled      | Handled      |
| **Performance**    | Moderate           | Low overhead     | Low overhead   | Low overhead | Low overhead |
| **Output**         | Tables             | Functions        | Event Hub      | Function     | Workflow     |
| **Best For**       | Audit, replication | Sync, ETL        | Real-time apps | Event-driven | Low-code     |

---

## Hands-On Labs

Run these from `MyLabs/08-integrate-sql-solutions-with-azure-services/`:

```bash
# Review all files in this folder
```

**Practice Exercises:**

1. Create DAB config for your database with REST + GraphQL
2. Deploy DAB to Azure Container Apps
3. Configure Azure Monitor diagnostic settings
4. Enable CDC on a table, query changes
5. Create Azure Function with SQL trigger binding
6. Build Logic App workflow for order changes

---

## Practice Questions

### Question 1

DAB GraphQL relationship `cardinality: "one-to-many"` generates what in schema?

A) `customer: Customer`
B) `items: [OrderItem]`
C) `items: OrderItem`
D) `customer: [Customer]`

**Answer: B** - One-to-many returns array `[Type]`; one-to-one returns single `Type`.

### Question 2

Change Tracking vs CDC: Which captures INTERMEDIATE values (every update)?

A) Change Tracking
B) CDC
C) Both
D) Neither

**Answer: B** - CDC captures every change; Change Tracking only net changes since last sync.

### Question 3

DAB caching configuration: `max-age: 60, stale-while-revalidate: 30` means?

A) Cache for 60s, serve stale for 30s while revalidating
B) Cache for 30s, revalidate after 60s
C) Cache for 90s total
D) Disable caching

**Answer: A** - Standard HTTP cache-control: fresh for 60s, stale-while-revalidate for 30s.

### Question 4

Azure Function SQL Trigger - what permission does the managed identity need?

A) `db_datareader` on source table
B) `db_owner` on database
C) `SELECT` on table + `VIEW CHANGE TRACKING`
D) `sysadmin`

**Answer: C** - Needs SELECT on table and VIEW CHANGE TRACKING permission (or db_datareader).

### Question 5

Which Azure Monitor log category captures query execution statistics?

A) `QueryStoreRuntimeStatistics`
B) `QueryStoreWaitStatistics`
C) `SQLInsights`
D) `QueryPerformance`

**Answer: A** - `QueryStoreRuntimeStatistics` contains avg_duration, execution_count, etc.

---

## Exam Tricks & Gotchas

| Topic               | Trick/Gotcha                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------- |
| **DAB Config**      | Use `@env('VAR')` for secrets; never hardcode connection strings                            |
| **GraphQL**         | Relationships require matching column names/types; `cardinality` determines array vs scalar |
| **Caching**         | `stale-while-revalidate` serves stale data while fetching fresh in background               |
| **CDC**             | Requires SQL Server Agent running; `sys.sp_cdc_enable_db` first                             |
| **Change Tracking** | Must enable at DB level THEN table level; `TRACK_COLUMNS_UPDATED` for column-level          |
| **CES**             | Azure SQL only; streams to Event Hub; lower latency than CDC polling                        |
| **SQL Trigger**     | Only for Azure Functions; not Logic Apps (uses different connector)                         |
| **Logic Apps**      | Uses polling (configurable interval); not real-time                                         |
| **App Insights**    | Add connection string to DAB config `telemetry.applicationInsights`                         |
| **DAB Deployment**  | Container Apps = serverless containers; Functions = event-driven; K8s = full control        |

---

## Condensed Cheat Sheet

```json
// dab-config.json minimal
{
  "source": { "connection-string": "@env('SQL_CONN')", "object": "dbo" },
  "entities": {
    "customers": { "source": "dbo.Customers", "rest": { "path": "customers" } },
    "orders": {
      "source": "dbo.Orders",
      "graphql": {
        "relationships": {
          "customer": { "type": "Customer", "source": "dbo.Customers", "join": {"field": "CustomerID"} }
        }
      }
    }
  },
  "runtime": { "rest": {"enabled": true}, "graphql": {"enabled": true} }
}

// CDC
EXEC sys.sp_cdc_enable_db;
EXEC sys.sp_cdc_enable_table @source_schema='dbo', @source_name='Orders', @supports_net_changes=1;
SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_Orders(@from_lsn, @to_lsn, 'all');

// Change Tracking
ALTER DATABASE DB SET CHANGE_TRACKING = ON (CHANGE_RETENTION=2 DAYS);
ALTER TABLE dbo.Orders ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED=ON);
SELECT * FROM CHANGETABLE(CHANGES dbo.Orders, @version) CT JOIN dbo.Orders O ON CT.OrderID=O.OrderID;

// Azure Function SQL Trigger
// function.json: "type": "sqlTrigger", "tableName": "dbo.Orders", "connectionStringSetting": "SQL_CONN"
// Code: [SqlTrigger("dbo.Orders", "SQL_CONN")] IReadOnlyList<SqlChange<Order>> changes

// Azure Monitor KQL
AzureDiagnostics | where Category == "QueryStoreRuntimeStatistics" | extend Duration=avg_duration/1000.0 | where Duration>1000
```

---

## Day 8 Completion Checklist

- [ ] Read all lab files in `MyLabs/08-integrate-sql-solutions-with-azure-services/`
- [ ] Create DAB config with REST + GraphQL + relationships
- [ ] Deploy DAB to Container Apps (or local Docker)
- [ ] Enable CDC and Change Tracking, compare
- [ ] Create Azure Function with SQL trigger
- [ ] Complete practice questions (target: 4/5 correct)
- [ ] Note weak areas for Day 10 review

---

_Next: Day 9 - AI: Models, Embeddings & Intelligent Search_

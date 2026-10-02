# Day 4: AI-Assisted Development

**Date:** September 25, 2026 | **Exam Weight:** 35-40% (Design & Develop Database Solutions)

---

## 🎯 Learning Objectives

- [ ] Security impact of using AI-assisted tools
- [ ] Enable GitHub Copilot and Copilot in Fabric
- [ ] Configure model and MCP tool options in GitHub Copilot/Copilot in Fabric chat
- [ ] Create and configure GitHub Copilot instruction files
- [ ] Connect to MCP server endpoints (SQL Server, Fabric lakehouse)

---

## 📚 Core Concepts

### 1. Security Impact of AI-Assisted Tools

**Key Risk Areas:**
| Risk | Mitigation |
|------|------------|
| **Code Injection** | AI may suggest vulnerable patterns (SQL injection, XSS) | Always review; use parameterized queries |
| **Data Leakage** | Prompts sent to cloud may contain sensitive data | Use `.copilotignore`; avoid PII/secrets in context |
| **License Compliance** | Generated code may match copyrighted code | Enable "Block suggestions matching public code" |
| **Dependency Hallucination** | AI suggests non-existent packages/versions | Verify all dependencies before use |
| **Over-reliance** | Accepting suggestions without understanding | Treat AI as pair programmer, not autopilot |

**Organization Policies:**

```json
// .github/copilot-policy.json (example)
{
  "enabled": true,
  "blockPublicCodeSuggestions": true,
  "allowedModels": ["gpt-4o", "claude-3.5-sonnet"],
  "dataRetentionDays": 30,
  "requireReviewFor": ["production", "security-critical"]
}
```

---

### 2. GitHub Copilot Configuration

**Enable in Repository:**

1. Settings → Code & automation → GitHub Copilot → Enable
2. Configure: "Allow Copilot for all repositories" or select specific

**VS Code Settings (`.vscode/settings.json`):**

```json
{
  "github.copilot.enable": {
    "*": true,
    "sql": true,
    "markdown": true
  },
  "github.copilot.advanced": {
    "inlineSuggestCount": 3,
    "showIcon": true
  },
  "github.copilot.chat.locale": "en",
  "github.copilot.chat.welcomeMessage": "never"
}
```

**Copilot Chat Commands:**
| Command | Purpose |
|---------|---------|
| `/explain` | Explain selected code |
| `/tests` | Generate unit tests |
| `/fix` | Fix errors in selection |
| `/doc` | Generate documentation |
| `/optimize` | Performance suggestions |
| `@workspace` | Query entire codebase |
| `@terminal` | Terminal context |

---

### 3. GitHub Copilot Instruction Files

**`.github/copilot-instructions.md` (Repository-level):**

```markdown
# Copilot Instructions for EcommerceDB Project

## Coding Standards

- Use explicit column lists (no SELECT \*)
- Always use SCHEMABINDING for views/functions
- Parameterize all queries (no concatenation)
- Use TRY/CATCH in all stored procedures
- Name constraints explicitly: PK*, FK*, CK*, IX*, DF\_

## T-SQL Patterns

- Temporal tables for audit trails
- JSON for semi-structured metadata
- Partitioned tables for large fact tables
- Inline TVFs over multi-statement TVFs
- Window functions over cursors

## Security

- RLS for multi-tenant data
- Dynamic Data Masking for PII
- Always Encrypted for sensitive columns
- No dynamic SQL without sp_executesql + params

## AI Usage

- Prefer set-based operations
- Generate test data scripts, not production logic
- Document complex logic with comments
```

**`.github/prompts/sql-review.prompt.md` (Custom prompt):**

```markdown
---
description: "Review T-SQL for performance, security, and best practices"
---

Review the selected T-SQL code for:

1. **Performance**: Missing indexes, table scans, parameter sniffing, sargability
2. **Security**: SQL injection risk, permissions, data exposure
3. **Best Practices**: Naming, constraints, error handling, transactions
4. **Maintainability**: Complexity, documentation, modularity

Provide specific, actionable feedback with corrected code examples.
```

---

### 4. Model Context Protocol (MCP) in Copilot

**What is MCP?**

- Standardized protocol for AI to access external tools/data
- Allows Copilot to query databases, run scripts, access APIs
- JSON-RPC 2.0 based, runs over stdio or HTTP/SSE

**Configure MCP in VS Code (`.vscode/mcp.json`):**

```json
{
  "servers": {
    "sql-server": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@microsoft/mcp-server-sql"],
      "env": {
        "SQL_CONNECTION_STRING": "${env:SQL_CONNECTION_STRING}"
      }
    },
    "fabric-lakehouse": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@microsoft/mcp-server-fabric"],
      "env": {
        "FABRIC_WORKSPACE_ID": "${env:FABRIC_WORKSPACE_ID}",
        "FABRIC_LAKEHOUSE_ID": "${env:FABRIC_LAKEHOUSE_ID}"
      }
    }
  }
}
```

**Using MCP in Copilot Chat:**

```
@mcp:sql-server List all tables in the Sales schema
@mcp:sql-server Show execution plan for query: SELECT * FROM Orders WHERE CustomerID = 123
@mcp:fabric-lakehouse List tables in lakehouse 'SalesLH'
@mcp:fabric-lakehouse Run notebook 'DataPreparation'
```

**MCP Tool Capabilities for SQL:**
| Tool | Description |
|------|-------------|
| `list_tables` | List tables/views in schema |
| `describe_table` | Columns, indexes, constraints |
| `execute_query` | Run SELECT (read-only by default) |
| `query_plan` | Get execution plan |
| `suggest_indexes` | Index recommendations |

---

### 5. Copilot in Microsoft Fabric

**Enable in Fabric:**

1. Fabric Portal → Settings → Copilot → Enable for workspace
2. Assign Copilot capacity (F64 or higher)

**Fabric Copilot Capabilities:**
| Area | Features |
|------|----------|
| **Data Engineering** | Generate PySpark/SQL notebooks, pipeline code |
| **Data Warehouse** | Write T-SQL, explain queries, optimize |
| **Data Science** | Generate ML code, feature engineering |
| **Real-Time Intelligence** | KQL queries, Eventstream logic |
| **Power BI** | DAX measures, report design, narratives |

**Fabric Copilot Chat Example:**

```
"Create a PySpark notebook that reads from lakehouse 'SalesLH',
cleans the Orders table (remove duplicates, handle nulls),
and writes to a new table 'CleanOrders' partitioned by year."
```

---

### 6. MCP Server Endpoints for SQL & Fabric

**SQL Server MCP Server (Microsoft official):**

```bash
# Install
npx -y @microsoft/mcp-server-sql

# Environment variables required
SQL_CONNECTION_STRING="Server=myserver;Database=mydb;Authentication=Active Directory Default;"
# Or for SQL Auth:
SQL_CONNECTION_STRING="Server=myserver;Database=mydb;User Id=user;Password=pass;TrustServerCertificate=true;"
```

**Fabric Lakehouse MCP Server:**

```bash
npx -y @microsoft/mcp-server-fabric

# Required env vars
FABRIC_WORKSPACE_ID="<workspace-guid>"
FABRIC_LAKEHOUSE_ID="<lakehouse-guid>"
FABRIC_TOKEN="${env:FABRIC_TOKEN}"  # Or use Azure CLI auth
```

**Custom MCP Server (Example - SQL Agent):**

```python
# mcp_sql_agent.py
from mcp.server import Server
from mcp.types import Tool
import pyodbc

server = Server("sql-agent")

@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(name="run_select", description="Execute read-only SELECT",
             inputSchema={"type": "object", "properties": {"query": {"type": "string"}}}),
        Tool(name="analyze_plan", description="Get execution plan",
             inputSchema={"type": "object", "properties": {"query": {"type": "string"}}}),
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    conn = pyodbc.connect(os.environ["SQL_CONNECTION_STRING"])
    if name == "run_select":
        cursor = conn.execute(arguments["query"])
        return [{"columns": [c[0] for c in cursor.description], "rows": cursor.fetchall()}]
    # ...
```

---

## 🧪 Hands-On Labs

Run these from `MyLabs/04-design-implement-sql-solutions-ai-assisted-tools/`:

```bash
# Review all files in this folder
1. 1-usp_GetCustomerOrderSummary.sql
# ... other files
```

**Practice Exercises:**

1. Create `.github/copilot-instructions.md` for your project
2. Create a custom prompt file for T-SQL code review
3. Configure MCP for SQL Server (if you have a test instance)
4. Try Copilot Chat: `@workspace Explain the partitioning strategy in this project`
5. Generate unit tests for a stored procedure using `/tests`

---

## 📝 Practice Questions

### Question 1

What is the purpose of `.github/copilot-instructions.md`?

A) Configure VS Code settings for Copilot
B) Provide repository-specific coding standards and context to Copilot
C) Define MCP server connections
D) Block public code suggestions

**Answer: B** - It provides project-specific context, standards, and patterns for Copilot to follow.

### Question 2

Which VS Code setting controls whether Copilot suggestions appear for SQL files?

A) `github.copilot.enable.sql`
B) `github.copilot.sql.enabled`
C) `sql.copilot.enable`
D) `editor.inlineSuggest.enabled`

**Answer: A** - `"github.copilot.enable": { "sql": true }` in settings.json.

### Question 3

In MCP configuration, what does `"type": "stdio"` mean?

A) Server communicates over HTTP
B) Server runs as subprocess communicating via stdin/stdout
C) Server uses WebSocket
D) Server uses named pipes

**Answer: B** - stdio = standard input/output; MCP server runs as child process.

### Question 4

You want Copilot to generate a T-SQL stored procedure with proper error handling. Best prompt?

A) "Write a stored procedure"
B) "Write a stored procedure usp_ProcessOrder that takes OrderID, uses TRY/CATCH, XACT_ABORT, and returns tracking number"
C) "Create SP for orders"
D) "/fix on this file"

**Answer: B** - Specific, detailed prompts with requirements yield better results.

### Question 5

What is a key security risk when using GitHub Copilot with database code?

A) Copilot may suggest `SELECT *` queries
B) Prompts containing connection strings or PII sent to cloud
C) Copilot cannot write parameterized queries
D) Copilot disables IntelliSense

**Answer: B** - Never include secrets, connection strings, or real data in prompts. Use `.copilotignore`.

---

## 🎯 Exam Tricks & Gotchas

| Topic                  | Trick/Gotcha                                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Instruction Files**  | `.github/copilot-instructions.md` applies to entire repo; `.github/prompts/*.prompt.md` for reusable prompts |
| **MCP Servers**        | Must be in `.vscode/mcp.json` or user settings; env vars referenced as `${env:VAR}`                          |
| **Copilot in Fabric**  | Requires F64+ capacity; workspace-level enablement                                                           |
| **Prompt Engineering** | Be specific: include table names, constraints, patterns to follow                                            |
| **Code Review**        | Use custom prompts for consistent reviews: `/sql-review`                                                     |
| **Data Privacy**       | Add `.copilotignore` for `.env`, `*.bak`, `secrets.*` files                                                  |
| **Model Selection**    | In Copilot Chat, use `@model gpt-4o` or `@model claude` to switch                                            |

---

## 📋 Condensed Cheat Sheet

```markdown
# .github/copilot-instructions.md

## Project: EcommerceDB

### Standards

- Explicit columns, SCHEMABINDING, parameterized queries
- Temporal tables for audit, JSON for metadata
- Inline TVF > Multi-stmt TVF
- RLS for multi-tenant, Masking for PII

# .vscode/mcp.json

{
"servers": {
"sql": {"type": "stdio", "command": "npx", "args": ["-y", "@microsoft/mcp-server-sql"],
"env": {"SQL_CONNECTION_STRING": "${env:SQL_CONN}"}},
    "fabric": {"type": "stdio", "command": "npx", "args": ["-y", "@microsoft/mcp-server-fabric"],
               "env": {"FABRIC_WORKSPACE_ID": "${env:WS_ID}", "FABRIC_LAKEHOUSE_ID": "${env:LH_ID}"}}
}
}

# Copilot Chat Commands

@workspace <question> # Query codebase
@mcp:sql <query> # SQL MCP tool
@mcp:fabric <query> # Fabric MCP tool
/explain /tests /fix /doc /optimize

# .copilotignore

.env
_.bak
secrets._
\*.pfx
connectionstrings.config
```

---

## ✅ Day 4 Completion Checklist

- [ ] Read all lab files in `MyLabs/04-design-implement-sql-solutions-ai-assisted-tools/`
- [ ] Create `.github/copilot-instructions.md` for your project
- [ ] Create a custom prompt file (`.github/prompts/`)
- [ ] Configure MCP for SQL Server (test connection)
- [ ] Try Copilot Chat with `@workspace` and `@mcp` commands
- [ ] Complete practice questions (target: 4/5 correct)
- [ ] Note weak areas for Day 10 review

---

_Next: Day 5 - Security & Compliance (Encryption, Masking, RLS, Auditing, Passwordless)_

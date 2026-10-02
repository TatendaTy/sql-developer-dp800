# Day 7: CI/CD with SQL Database Projects

**Date:** September 28, 2026 | **Exam Weight:** 35-40% (Secure, Optimize, Deploy)

---

## Learning Objectives

- [ ] SQL Database Projects (SDK-style .sqlproj)
- [ ] Unit tests (tSQLt framework) & integration tests
- [ ] Reference/static data in source control
- [ ] Build, validate, deploy pipelines
- [ ] Branching strategies, PR policies, conflict resolution
- [ ] Secrets management (Azure Key Vault, GitHub secrets)
- [ ] Schema drift detection
- [ ] Deployment pipeline controls: branch policies, approvals, code owners

---

## Core Concepts

### 1. SQL Database Projects (SDK-Style)

```xml
<!-- Modern SDK-style .sqlproj (SQL Server 2022+ / VS 2022+) -->
<Project Sdk="Microsoft.Build.Sql/0.4.0">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <DSP>Microsoft.Data.Tools.Schema.Sql.Sql160DatabaseSchemaProvider</DSP>
    <SqlServerVersion>Sql160</SqlServerVersion>  <!-- SQL Server 2022 -->
    <OutputType>Database</OutputType>
    <DefaultCollation>Latin1_General_CI_AS</DefaultCollation>
  </PropertyGroup>

  <ItemGroup>
    <!-- Reference to master.dacpac for system objects -->
    <PackageReference Include="Microsoft.SqlServer.Dacpac.Master" Version="160.0.0" />
  </ItemGroup>

  <!-- Pre/Post deployment scripts -->
  <ItemGroup>
    <None Update="Scripts\PreDeployment.sql">
      <DeployAction>PreDeploy</DeployAction>
    </None>
    <None Update="Scripts\PostDeployment.sql">
      <DeployAction>PostDeploy</DeployAction>
    </None>
  </ItemGroup>
</Project>
```

**Project Structure:**

```
DatabaseProject/
├── DatabaseProject.sqlproj
├── dbo/
│   ├── Tables/
│   │   ├── Customers.sql
│   │   └── Orders.sql
│   ├── Views/
│   │   └── vw_CustomerOrders.sql
│   ├── Procedures/
│   │   └── usp_ProcessOrder.sql
│   ├── Functions/
│   │   └── fn_CalculateTax.sql
│   └── Security/
│       └── Roles.sql
├── Scripts/
│   ├── PreDeployment.sql
│   └── PostDeployment.sql
└── ReferenceData/
    ├── LookupTables.sql
    └── StaticData.sql
```

**Table Definition (Declarative):**

```sql
-- dbo/Tables/Customers.sql
CREATE TABLE [dbo].[Customers] (
    [CustomerID]     INT            IDENTITY (1, 1) NOT NULL,
    [CustomerName]   NVARCHAR (100) NOT NULL,
    [Email]          NVARCHAR (200) NULL,
    [Phone]          NVARCHAR (20)  NULL,
    [CreatedDate]    DATETIME2 (0)  CONSTRAINT [DF_Customers_CreatedDate] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [RowVersion]     ROWVERSION     NOT NULL,
    CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([CustomerID] ASC)
);

CREATE UNIQUE NONCLUSTERED INDEX [IX_Customers_Email]
ON [dbo].[Customers]([Email] ASC) WHERE [Email] IS NOT NULL;
```

---

### 2. Pre/Post Deployment Scripts

```sql
-- Scripts/PreDeployment.sql
-- Runs before schema changes (use for data migration prep)
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Orders') AND name = 'OldColumn')
BEGIN
    -- Backup data before column drop
    SELECT OrderID, OldColumn INTO #OldColumnBackup FROM dbo.Orders;
END

-- Scripts/PostDeployment.sql
-- Runs after schema changes (use for reference data, data migration)
-- Reference data merge pattern
MERGE INTO dbo.OrderStatus AS Target
USING (VALUES
    (1, 'Pending'),
    (2, 'Processing'),
    (3, 'Shipped'),
    (4, 'Delivered'),
    (5, 'Cancelled')
) AS Source (StatusID, StatusName)
ON Target.StatusID = Source.StatusID
WHEN MATCHED THEN UPDATE SET StatusName = Source.StatusName
WHEN NOT MATCHED BY TARGET THEN INSERT (StatusID, StatusName) VALUES (Source.StatusID, Source.StatusName);

-- Data migration from temp table
IF OBJECT_ID('tempdb..#OldColumnBackup') IS NOT NULL
BEGIN
    UPDATE o SET o.NewColumn = b.OldColumn
    FROM dbo.Orders o
    JOIN #OldColumnBackup b ON o.OrderID = b.OrderID;
    DROP TABLE #OldColumnBackup;
END
```

---

### 3. Reference/Static Data Management

```sql
-- ReferenceData/LookupTables.sql
-- Use MERGE for idempotent reference data deployment
:r .\StaticData\OrderStatus.sql
:r .\StaticData\PaymentTypes.sql
:r .\StaticData\Countries.sql

-- ReferenceData/StaticData/OrderStatus.sql
MERGE INTO [dbo].[OrderStatus] AS Target
USING (VALUES
    (1, N'Pending', 1),
    (2, N'Processing', 2),
    (3, N'Shipped', 3),
    (4, N'Delivered', 4),
    (5, N'Cancelled', 5)
) AS Source ([StatusID], [StatusName], [DisplayOrder])
ON Target.[StatusID] = Source.[StatusID]
WHEN MATCHED THEN UPDATE SET [StatusName] = Source.[StatusName], [DisplayOrder] = Source.[DisplayOrder]
WHEN NOT MATCHED BY TARGET THEN INSERT ([StatusID], [StatusName], [DisplayOrder]) VALUES (Source.[StatusID], Source.[StatusName], Source.[DisplayOrder])
WHEN NOT MATCHED BY SOURCE THEN DELETE;  -- Optional: remove obsolete
```

---

### 4. Unit Testing with tSQLt

```sql
-- Install tSQLt (run once per database)
-- Download from https://tsqlt.org/download/
-- Or via NuGet: Install-Package tSQLt

-- Test class
EXEC tSQLt.NewTestClass 'OrderProcessingTests';

-- Test: usp_ProcessOrder creates tracking number
CREATE PROCEDURE OrderProcessingTests.[test usp_ProcessOrder creates tracking number]
AS
BEGIN
    -- Assemble
    EXEC tSQLt.FakeTable @TableName = 'dbo.Orders';
    EXEC tSQLt.FakeTable @TableName = 'dbo.OrderTracking';

    INSERT INTO dbo.Orders (OrderID, CustomerID, TotalAmount, Status)
    VALUES (1, 100, 500.00, 'Pending');

    -- Act
    DECLARE @TrackingNumber VARCHAR(50);
    EXEC dbo.usp_ProcessOrder @OrderID = 1, @TrackingNumber = @TrackingNumber OUTPUT;

    -- Assert
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @@ERROR;  -- SP returns 0 on success
    EXEC tSQLt.AssertNotNull @Value = @TrackingNumber;
    EXEC tSQLt.AssertLike @Expected = 'TRK00000001%', @Actual = @TrackingNumber;

    -- Verify OrderTracking insert
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = (SELECT COUNT(*) FROM dbo.OrderTracking);
END;

-- Test: usp_ProcessOrder throws on invalid OrderID
CREATE PROCEDURE OrderProcessingTests.[test usp_ProcessOrder throws on invalid OrderID]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = 'dbo.Orders';
    EXEC tSQLt.FakeTable @TableName = 'dbo.OrderTracking';

    DECLARE @TrackingNumber VARCHAR(50);
    EXEC dbo.usp_ProcessOrder @OrderID = 999, @TrackingNumber = @TrackingNumber OUTPUT;

    -- Should have thrown error (catch in test)
    EXEC tSQLt.AssertEquals @Expected = 50001, @Actual = ERROR_NUMBER();
END;

-- Run tests
EXEC tSQLt.Run @TestName = 'OrderProcessingTests';
EXEC tSQLt.RunAll;  -- All test classes
```

---

### 5. Build & Deploy Pipeline (GitHub Actions)

```yaml
# .github/workflows/sql-ci.yml
name: SQL Database CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AZURE_SQL_SERVER: ${{ secrets.AZURE_SQL_SERVER }}
  AZURE_SQL_DATABASE: ${{ secrets.AZURE_SQL_DATABASE }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Restore & Build
        run: |
          cd DatabaseProject
          dotnet restore
          dotnet build --configuration Release

      - name: Run Unit Tests
        run: |
          # Deploy to test database (LocalDB or container)
          sqlpackage /Action:Publish /SourceFile:bin/Release/net8.0/DatabaseProject.dacpac \
            /TargetConnectionString:"Server=(localdb)\MSSQLLocalDB;Database=TestDB;Trusted_Connection=True;" \
            /p:DropObjectsNotInSource=False

          # Run tSQLt tests
          sqlcmd -S "(localdb)\MSSQLLocalDB" -d TestDB -Q "EXEC tSQLt.RunAll;"

      - name: Publish DACPAC Artifact
        uses: actions/upload-artifact@v4
        with:
          name: dacpac
          path: DatabaseProject/bin/Release/net8.0/DatabaseProject.dacpac

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dacpac
          path: ./dacpac

      - name: Deploy to Staging
        uses: azure/sql-action@v2
        with:
          connection-string: ${{ secrets.AZURE_SQL_STAGING_CONNECTION }}
          path: ./dacpac/DatabaseProject.dacpac
          action: "publish"
          arguments: "/p:DropObjectsNotInSource=False /p:BlockOnPossibleDataLoss=True"

  deploy-production:
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: production
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dacpac
          path: ./dacpac

      - name: Generate Deploy Script (Review)
        run: |
          sqlpackage /Action:Script /SourceFile:./dacpac/DatabaseProject.dacpac \
            /TargetConnectionString:"${{ secrets.AZURE_SQL_PROD_CONNECTION }}" \
            /OutputPath:./deploy-script.sql \
            /p:DropObjectsNotInSource=False

      - name: Deploy to Production (Manual Approval)
        uses: azure/sql-action@v2
        with:
          connection-string: ${{ secrets.AZURE_SQL_PROD_CONNECTION }}
          path: ./dacpac/DatabaseProject.dacpac
          action: "publish"
```

---

### 6. Branching & PR Policies

```markdown
# Branching Strategy (GitFlow-inspired)

## Branches

- `main` - Production ready (protected)
- `develop` - Integration branch (protected)
- `feature/*` - Feature branches
- `hotfix/*` - Emergency fixes
- `release/*` - Release preparation

## Branch Policies (GitHub/Azure DevOps)

- Require PR review (2 approvals)
- Require status checks (build, tests)
- Require linear history (squash merge)
- No force push
- Code owners for sensitive areas:
```

# CODEOWNERS

/DatabaseProject/dbo/Security/ @db-admins
/DatabaseProject/Scripts/ @db-admins
/DatabaseProject/ReferenceData/ @db-admins

```

## Conflict Resolution
1. Rebase feature branch onto target
2. Resolve conflicts in `.sql` files (declarative - usually auto-mergeable)
3. For PostDeployment scripts: manual merge required
4. Re-run tests after merge
```

---

### 7. Secrets Management

```yaml
# GitHub Actions - Secrets in Repository Settings
# AZURE_SQL_STAGING_CONNECTION
# AZURE_SQL_PROD_CONNECTION
# AZURE_KEY_VAULT_URI

# Azure Key Vault Integration
- name: Get Secrets from Key Vault
  uses: azure/get-keyvault-secrets@v1
  with:
    keyvault: ${{ secrets.AZURE_KEY_VAULT_URI }}
    secrets: "sql-connection-string,api-key"
  id: kv

- name: Deploy with Key Vault Secret
  uses: azure/sql-action@v2
  with:
    connection-string: ${{ steps.kv.outputs.sql-connection-string }}
    path: ./dacpac/DatabaseProject.dacpac
```

**sqlpackage.exe with Variables:**

```bash
# Use variables for environment-specific values
sqlpackage /Action:Publish \
  /SourceFile:DatabaseProject.dacpac \
  /TargetConnectionString:"$CONNECTION_STRING" \
  /Variables:Environment=Production;EnableFeatureX=True \
  /p:DropObjectsNotInSource=False
```

---

### 8. Schema Drift Detection

```sql
-- Detect drift: Compare deployed DB with source control
-- Method 1: sqlpackage drift report
sqlpackage /Action:DeployReport \
  /SourceFile:DatabaseProject.dacpac \
  /TargetConnectionString:"Server=prod;Database=MyDB;..." \
  /OutputPath:drift-report.xml

-- Method 2: Query Store / sys.objects comparison
SELECT
    o.name, o.type_desc, o.create_date, o.modify_date,
    'In DB not in Project' AS drift_type
FROM sys.objects o
WHERE o.type IN ('U','V','P','FN','IF','TF')
  AND NOT EXISTS (SELECT 1 FROM ProjectObjects po WHERE po.name = o.name)

UNION ALL

SELECT
    po.name, po.type_desc, NULL, NULL,
    'In Project not in DB' AS drift_type
FROM ProjectObjects po
WHERE NOT EXISTS (SELECT 1 FROM sys.objects o WHERE o.name = po.name);

-- Automated drift detection in pipeline
- name: Check Schema Drift
  run: |
    sqlpackage /Action:DeployReport /SourceFile:dacpac.dacpac \
      /TargetConnectionString:"$PROD_CONN" /OutputPath:drift.xml
    # Parse drift.xml - fail if unexpected changes
    python check_drift.py drift.xml
```

---

### 9. Pipeline Controls

```yaml
# Branch Protection Rules (GitHub)
# Settings -> Branches -> Branch protection rules

# Required checks:
# - build
# - unit-tests
# - schema-drift-check

# Required reviews: 2
# Dismiss stale reviews on new commits
# Require review from code owners

# Deployment Gates (Azure DevOps / GitHub Environments)
# Environment: production
#   Required reviewers: @db-admins, @release-managers
#   Wait timer: 30 minutes
#   Deployment branches: main only

# Approval Gates
environment:
  name: production
  url: https://app.contoso.com
  protection_rules:
    - type: required_reviewers
      reviewers: ["db-admin-team", "release-manager"]
    - type: wait_timer
      minutes: 30
```

---

## Hands-On Labs

Run these from `MyLabs/07-implement-cicd-sql-database-projects/`:

```bash
# Review all files in this folder
```

**Practice Exercises:**

1. Create SDK-style SQL project in VS Code
2. Add tables, views, procedures as .sql files
3. Configure Pre/Post deployment scripts
4. Set up tSQLt and write 3 unit tests
5. Create GitHub Actions workflow for build/test
6. Configure branch protection rules

---

## Practice Questions

### Question 1

SDK-style .sqlproj uses which element for target platform?

A) `<DSP>Microsoft.Data.Tools.Schema.Sql.Sql160DatabaseSchemaProvider</DSP>`
B) `<TargetPlatform>SqlAzure</TargetPlatform>`
C) `<SqlServerVersion>2022</SqlServerVersion>`
D) `<DatabaseVersion>160</DatabaseVersion>`

**Answer: A** - DSP (Database Schema Provider) specifies target; Sql160 = SQL Server 2022.

### Question 2

Post-deployment script runs when?

A) Before schema changes
B) After schema changes
C) Only on initial deploy
D) Only when data changes

**Answer: B** - Post-deployment runs after all schema changes; use for reference data, data migration.

### Question 3

tSQLt `FakeTable` does what?

A) Creates a mock table with no data
B) Creates a copy of table structure, no constraints/triggers
C) Creates temp table with same name
D) Disables triggers on real table

**Answer: B** - Creates isolated test double with same structure, no FK/check/trigger.

### Question 4

Which sqlpackage action generates deployment script without executing?

A) `/Action:Publish`
B) `/Action:Script`
C) `/Action:DeployReport`
D) `/Action:Extract`

**Answer: B** - `Script` generates .sql file; `DeployReport` generates XML report.

### Question 5

Reference data should be deployed using:

A) INSERT statements in post-deploy
B) MERGE statements in post-deploy
C) TRUNCATE + INSERT in pre-deploy
D) Separate data-only dacpac

**Answer: B** - MERGE is idempotent (handles insert/update/delete), safe for repeatable deployments.

---

## Exam Tricks & Gotchas

| Topic               | Trick/Gotcha                                                                     |
| ------------------- | -------------------------------------------------------------------------------- |
| **SDK Project**     | Requires .NET SDK; `Microsoft.Build.Sql` package; VS 2022 17.6+                  |
| **DACPAC**          | Single file deployment unit; contains schema + reference data                    |
| **Pre/Post Deploy** | Run once per deploy; use `IF NOT EXISTS` for idempotency                         |
| **Reference Data**  | MERGE with `WHEN NOT MATCHED BY SOURCE THEN DELETE` for sync                     |
| **tSQLt**           | `FakeTable` removes constraints; `SpyProcedure` for mocking SPs                  |
| **Build**           | `dotnet build` produces .dacpac; validate with `sqlpackage /Action:DeployReport` |
| **Secrets**         | Never in code; use GitHub Environments + Key Vault                               |
| **Drift Detection** | `DeployReport` shows differences; automate in PR pipeline                        |
| **Branch Policy**   | Protect `main` and `develop`; require PR + checks + code owners                  |
| **Deployment**      | Production: manual approval + generated script review                            |

---

## Condensed Cheat Sheet

```xml
<!-- SDK-style .sqlproj -->
<Project Sdk="Microsoft.Build.Sql/0.4.0">
  <PropertyGroup>
    <DSP>Microsoft.Data.Tools.Schema.Sql.Sql160DatabaseSchemaProvider</DSP>
    <SqlServerVersion>Sql160</SqlServerVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.SqlServer.Dacpac.Master" Version="160.0.0" />
  </ItemGroup>
</Project>

<!-- PostDeploy: Reference Data -->
MERGE INTO dbo.Lookup AS Target
USING (VALUES (1,'A'),(2,'B')) AS Source(ID,Name)
ON Target.ID = Source.ID
WHEN MATCHED THEN UPDATE SET Name=Source.Name
WHEN NOT MATCHED BY TARGET THEN INSERT (ID,Name) VALUES (Source.ID,Source.Name)
WHEN NOT MATCHED BY SOURCE THEN DELETE;

<!-- tSQLt Test -->
EXEC tSQLt.NewTestClass 'MyTests';
CREATE PROCEDURE MyTests.[test something] AS BEGIN
  EXEC tSQLt.FakeTable 'dbo.Table';
  INSERT dbo.Table ...;
  EXEC dbo.usp_Proc;
  EXEC tSQLt.AssertEquals @Expected=1, @Actual=(SELECT COUNT(*) FROM dbo.Table);
END;

<!-- GitHub Actions Deploy -->
- uses: azure/sql-action@v2
  with:
    connection-string: ${{ secrets.AZURE_SQL_CONN }}
    path: ./dacpac.dacpac
    action: 'publish'

<!-- sqlpackage Commands -->
sqlpackage /Action:Publish /SourceFile:proj.dacpac /TargetConnectionString:"..." /p:DropObjectsNotInSource=False
sqlpackage /Action:Script /SourceFile:proj.dacpac /TargetConnectionString:"..." /OutputPath:deploy.sql
sqlpackage /Action:DeployReport /SourceFile:proj.dacpac /TargetConnectionString:"..." /OutputPath:drift.xml
```

---

## Day 7 Completion Checklist

- [ ] Read all lab files in `MyLabs/07-implement-cicd-sql-database-projects/`
- [ ] Create SDK-style SQL project
- [ ] Write tSQLt unit tests (3+)
- [ ] Create GitHub Actions CI/CD pipeline
- [ ] Complete practice questions (target: 4/5 correct)
- [ ] Note weak areas for Day 10 review

---

_Next: Day 8 - Azure Integration (Data API Builder, Azure Monitor, Change Streaming)_

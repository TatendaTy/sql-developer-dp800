# Project Guidelines for Copilot

Follow these repository conventions whenever generating or editing T-SQL for this project. Keep changes consistent with the existing SQL Server 2025 standards below.

## Database Development Standards

This project uses SQL Server 2025 with the following conventions:

## Naming Conventions

- Tables: PascalCase, singular form (Customer, Product, SalesOrder)
- Columns: PascalCase (FirstName, OrderDate, UnitPrice)
- Stored procedures: usp_ActionEntity (usp_GetCustomerOrders, usp_InsertProduct)
- Views: vw_EntityDescription (vw_ActiveCustomers, vw_ProductInventory)
- Indexes: IX_TableName_ColumnName

## T-SQL Style Guidelines

- Always use explicit column lists in SELECT statements (avoid SELECT \*)
- Include schema prefix for all objects (SalesLT.Product, SalesLT.Customer)
- Use ANSI JOIN syntax (INNER JOIN, LEFT JOIN) instead of comma-separated tables
- Include error handling in all stored procedures
- Use TRY...CATCH blocks for data modification operations

## Security Requirements

- Use parameterized queries, never concatenate user input
- Never include actual credentials or connection strings in code
- Use least-privilege principles for GRANT statements
- Never generate GRANT statements to public
- Avoid dynamic SQL when possible

### Performance Guidelines

- Suggest appropriate indexes when creating tables
- Prefer SET NOCOUNT ON in stored procedures
- Use EXISTS instead of COUNT for existence checks

## Comments

- Include a header comment with procedure name, purpose, and author
- Add inline comments for complex logic

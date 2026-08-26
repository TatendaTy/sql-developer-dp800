# Create Stored Procedure

Generate a stored procedure with the following specifications:

- Procedure name: {{procedureName}}
  If any template variable is missing or still contains a placeholder value, stop and ask the user to supply the missing information before generating the procedure.
- Purpose: {{description}}
- Parameters: {{parameters}}
  If no parameters are provided, generate the procedure without any parameter declarations.

Follow these requirements:

- Include TRY...CATCH error handling
- Add SET NOCOUNT ON at the beginning
- Include appropriate comments
- Follow our naming conventions (usp\_ prefix)
- If the procedure performs any INSERT, UPDATE, or DELETE operations, wrap those statements in an explicit BEGIN TRANSACTION / COMMIT TRANSACTION block inside the TRY clause, with a ROLLBACK in the CATCH block. Omit the transaction wrapper for read-only procedures.

Generate a stored procedure with the following specifications:

- Procedure name: {{procedureName}}
  If any template variable is missing or still contains a placeholder value, stop and ask the user to supply the missing information before generating the procedure.
- Purpose: {{description}}
- Parameters: {{parameters}}
  If no parameters are provided, generate the procedure without any parameter declarations.

Follow these requirements:

- Include TRY...CATCH error handling
- Add SET NOCOUNT ON at the beginning
- Include appropriate comments
- Follow our naming conventions (usp\_ prefix)
- If the procedure performs any INSERT, UPDATE, or DELETE operations, wrap those statements in an explicit BEGIN TRANSACTION / COMMIT TRANSACTION block inside the TRY clause, with a ROLLBACK in the CATCH block. Omit the transaction wrapper for read-only procedures.

Generate a stored procedure with the following specifications:

- Procedure name: {{procedureName}}
- Purpose: {{description}}
- Parameters: {{parameters}}

Follow these requirements:

- Include TRY...CATCH error handling
- Add SET NOCOUNT ON at the beginning
- Include appropriate comments
- Follow our naming conventions (usp\_ prefix)
- Use explicit transactions for data modifications

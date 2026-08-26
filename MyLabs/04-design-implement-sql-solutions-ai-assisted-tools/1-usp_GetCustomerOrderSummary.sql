-- Exercise Part A: Use Copilot to generate a stored procedure

USE [AdventureWorks2025];
GO

-- =============================================
-- Author:              Tatenda Kabanda
-- Create date:         08-26-2025
-- Description:         Retrieves customer order summary including order count, total amount, and last order date
-- =============================================
CREATE PROCEDURE dbo.usp_GetCustomerOrderSummary
    @CustomerID INT = NULL
AS
BEGIN
    -- Prevent extra result sets from interfering with SELECT statements
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            c.CustomerID,
            CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
            COUNT(DISTINCT soh.SalesOrderID) AS TotalOrders,
            ISNULL(SUM(soh.TotalDue), 0) AS TotalOrderAmount,
            MAX(soh.OrderDate) AS LastOrderDate
        FROM SalesLT.Customer AS c
        LEFT JOIN SalesLT.SalesOrderHeader AS soh
            ON c.CustomerID = soh.CustomerID
        WHERE (@CustomerID IS NULL OR c.CustomerID = @CustomerID)
        GROUP BY
            c.CustomerID,
            c.FirstName,
            c.LastName
        ORDER BY
            c.CustomerID;
    END TRY
    BEGIN CATCH
        -- Error handling: return error information
        DECLARE
            @ErrorNumber INT = ERROR_NUMBER(),
            @ErrorSeverity INT = ERROR_SEVERITY(),
            @ErrorState INT = ERROR_STATE(),
            @ErrorProcedure NVARCHAR(200) = ERROR_PROCEDURE(),
            @ErrorLine INT = ERROR_LINE(),
            @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(),
            @ErrorProcedureText NVARCHAR(200) = ISNULL(ERROR_PROCEDURE(), N'');

        RAISERROR (
            N'Error %d: %s in %s (line %d)',
            @ErrorSeverity,
            @ErrorState,
            @ErrorNumber,
            @ErrorMessage,
            @ErrorProcedureText,
            @ErrorLine
        );
    END CATCH;
END;
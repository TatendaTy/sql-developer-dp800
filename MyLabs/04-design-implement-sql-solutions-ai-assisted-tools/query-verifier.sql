USE [AdventureWorks2025];
GO

-- View the first 20 rows of the analysis
SELECT TOP (20) *
FROM dbo.vw_ProductSalesAnalysis
ORDER BY ProductID;
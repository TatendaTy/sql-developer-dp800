USE [AdventureWorks2025];
GO

-- Verify the table creation and inserted data
-- SELECT COUNT(*) AS TotalReviews FROM dbo.ProductReview;
-- GO

-- SELECT 
--     credential_id,
--     name,
--     credential_identity,
--     create_date,
--     modify_date
-- FROM sys.database_scoped_credentials;   -- database-scoped credentials only
-- GO


-- Database‑scoped credentials
-- SELECT credential_id, name, credential_identity
-- FROM sys.database_scoped_credentials;
-- GO

-- -- External models
-- SELECT name, location, api_format, model, credential_id
-- FROM sys.external_models;
-- GO

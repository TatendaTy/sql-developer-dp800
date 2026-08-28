USE SecurityLabDB;
GO

-- Batch 1: create users and grants
CREATE USER WestSalesRep WITHOUT LOGIN;
CREATE USER EastSalesRep WITHOUT LOGIN;

GRANT SELECT ON dbo.Customers TO WestSalesRep;
GRANT SELECT ON dbo.Customers TO EastSalesRep;
GO

-- Batch 2: schema first
CREATE SCHEMA Security;
GO

-- Batch 3: function
CREATE FUNCTION Security.fn_RegionFilter(@SalesRegion nvarchar(20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS fn_securitypredicate_result
    WHERE
        (
            USER_NAME() = 'WestSalesRep' AND @SalesRegion = 'West'
        )
        OR
        (
            USER_NAME() = 'EastSalesRep' AND @SalesRegion = 'East'
        )
        OR
        (
            IS_MEMBER('db_owner') = 1
        )
);
GO

-- Batch 4: policy
CREATE SECURITY POLICY CustomerRegionPolicy
ADD FILTER PREDICATE Security.fn_RegionFilter(SalesRegion)
ON dbo.Customers
WITH (STATE = ON);
GO

-- Test as WestSalesRep (should see only West region customers)
EXECUTE AS USER = 'WestSalesRep';
SELECT * FROM dbo.Customers;
REVERT;
GO

-- Test as EastSalesRep (should see only East region customers)
EXECUTE AS USER = 'EastSalesRep';
SELECT * FROM dbo.Customers;
REVERT;
GO

-- Test as admin (should see all customers)
SELECT * FROM dbo.Customers;
GO
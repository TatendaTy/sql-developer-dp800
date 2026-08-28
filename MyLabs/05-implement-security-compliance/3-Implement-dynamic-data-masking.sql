USE SecurityLabDB;
GO

-- Task 1: Add masks to the Employess table to protect sensitive columns
-- Mask the SSN column to show only the last four digits
ALTER TABLE dbo.Employees
ALTER COLUMN SSN ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XX-",4)');

-- Mask Salary with a random value
ALTER TABLE dbo.Employees
ALTER COLUMN Salary ADD MASKED WITH (FUNCTION = 'random(50000,150000)');

-- Mask Email to show first character and domain
ALTER TABLE dbo.Employees
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');

-- Task 2: Add masks to the Customers table
-- Mask the CreditCardNumber column to show only the last four digits
ALTER TABLE dbo.Customers
ALTER COLUMN CreditCardNumber ADD MASKED WITH (FUNCTION = 'partial(0,"XXXX-XXXX-XXXX-",4)');

-- Mask Phone number to show only the last four digits
ALTER TABLE dbo.Customers
ALTER COLUMN Phone ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');

--Task 3: Create a test user without UNMASK permission and verify masking works
-- Create a test user without UNMASK permission
CREATE USER MaskedViewer WITHOUT LOGIN;
GRANT SELECT ON dbo.Employees TO MaskedViewer;
GRANT SELECT ON dbo.Customers TO MaskedViewer;

-- Query as the masked user (data appears masked)
EXECUTE AS USER = 'MaskedViewer';
SELECT FirstName, LastName, Email, SSN, Salary FROM dbo.Employees;
SELECT CompanyName, ContactName, Phone, CreditCardNumber FROM dbo.Customers;
REVERT;

-- Query as admin (data appears unmasked)
SELECT FirstName, LastName, Email, SSN, Salary FROM dbo.Employees;
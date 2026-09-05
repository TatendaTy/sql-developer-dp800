USE [AdventureWorks2025];
GO

-- Query Store captures query text, execution plans, and runtime statistics directly inside the database. 
ALTER DATABASE CURRENT SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    WAIT_STATS_CAPTURE_MODE = ON
);
GO

-- Clear any prior data so only this exercise's queries appear
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;
GO
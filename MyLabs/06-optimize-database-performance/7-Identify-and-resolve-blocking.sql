-- 1. start a transaction that updates an order’s status but doesn’t commit.
-- This query simulates a warehouse application that crashed mid-transaction:

-- BEGIN TRANSACTION;
UPDATE dbo.OrderHistory SET Status = N'Cancelled' WHERE OrderID = 1;
-- Simulating an application that stopped without committing

-- Resolve the block by rolling back the transaction:
ROLLBACK TRANSACTION;
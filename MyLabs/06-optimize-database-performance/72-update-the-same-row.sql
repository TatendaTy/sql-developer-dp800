-- 2. try to update the same row. This query simulates another warehouse worker processing the same order:

UPDATE dbo.OrderHistory SET Status = N'Shipped' WHERE OrderID = 1;

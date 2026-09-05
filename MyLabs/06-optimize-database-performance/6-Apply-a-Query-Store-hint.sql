SELECT
    oh.CustomerID,
    p.Name AS ProductName,
    pc.Name AS CategoryName,
    oh.Status,
    COUNT(*) AS OrderCount,
    SUM(oh.TotalAmount) AS TotalRevenue,
    AVG(oh.TotalAmount) AS AvgOrderValue,
    STDEV(oh.TotalAmount) AS StdDevOrderValue,
    RANK() OVER (PARTITION BY oh.Status
        ORDER BY SUM(oh.TotalAmount) DESC) AS StatusRevenueRank,
    PERCENT_RANK() OVER (PARTITION BY pc.Name
        ORDER BY AVG(oh.TotalAmount)) AS CategoryPctRank,
    SUM(COUNT(*)) OVER (PARTITION BY oh.Status) AS StatusTotalOrders
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
    ON oh.ProductID = p.ProductID
INNER JOIN SalesLT.ProductCategory AS pc
    ON p.ProductCategoryID = pc.ProductCategoryID
GROUP BY oh.CustomerID, p.Name, pc.Name, oh.Status
ORDER BY TotalRevenue DESC;


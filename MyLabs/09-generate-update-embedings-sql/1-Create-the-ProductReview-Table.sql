USE [AdventureWorks2025];
GO

CREATE TABLE dbo.ProductReview (
    ReviewID      INT IDENTITY(1,1) PRIMARY KEY,
    ProductID     INT NOT NULL,
    ReviewTitle   NVARCHAR(200) NOT NULL,
    ReviewText    NVARCHAR(MAX) NOT NULL,
    Rating        TINYINT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    ReviewVector  VECTOR(1536) NULL   -- will hold the embedding
);
GO

-- Next Step: Run product-reviews-insert.sql script to insert data

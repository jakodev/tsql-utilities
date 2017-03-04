-- RUN THE DROP CODE
SELECT @sql = sql_string FROM [mrwolf].[tbl_scripts] WHERE obj_schema = @myfkschema and obj_name = @myfktable and sql_type = 'FK DROP'
EXEC sp_sqlexec @sql

DROP TABLE [test].[Categories]

CREATE TABLE [test].[Categories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CategoryName] [nvarchar](50) NOT NULL,
	[TimeStamp] [timestamp] NULL,
 CONSTRAINT [PK_testCategories] PRIMARY KEY CLUSTERED 
(
	[Id] ASC,
	[CategoryName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

SELECT @sql = sql_string FROM [mrwolf].[tbl_scripts] WHERE obj_schema = @myfkschema and obj_name = @myfktable and sql_type = 'FK CREATION'
EXEC sp_sqlexec @sql

ALTER TABLE [store].[Orders] ADD CONSTRAINT [FK_Orders_Customers] FOREIGN KEY(CustomerId) REFERENCES [store].[Customers] (Id)
ALTER TABLE [store].[Orders] DROP CONSTRAINT FK_Orders_Customers
ALTER TABLE [store].[ShoppingCartRecords] ADD CONSTRAINT [FK_ShoppingCartRecords_Customers] FOREIGN KEY(CustomerId) REFERENCES [store].[Customers] (Id)
ALTER TABLE [store].[ShoppingCartRecords] DROP CONSTRAINT FK_ShoppingCartRecords_Customers


-- ORDERS DROPPING
ALTER TABLE [store].[Orders] ADD CONSTRAINT [FK_Orders_Customers] FOREIGN KEY(CustomerId) REFERENCES [store].[Customers] (Id)
ALTER TABLE [store].[OrderDetails] ADD CONSTRAINT [FK_OrderDetails_Orders] FOREIGN KEY(OrderId) REFERENCES [store].[Orders] (Id)
ALTER TABLE [store].[Orders] DROP CONSTRAINT FK_Orders_Customers
ALTER TABLE [store].[OrderDetails] DROP CONSTRAINT FK_OrderDetails_Orders

-- ORDER DETAILS
ALTER TABLE [store].[OrderDetails] ADD CONSTRAINT [FK_OrderDetails_Orders] FOREIGN KEY(OrderId) REFERENCES [store].[Orders] (Id)
ALTER TABLE [store].[OrderDetails] ADD CONSTRAINT [FK_OrderDetails_Products] FOREIGN KEY(ProductId) REFERENCES [store].[Products] (Id)
ALTER TABLE [store].[OrderDetails] DROP CONSTRAINT FK_OrderDetails_Orders
ALTER TABLE [store].[OrderDetails] DROP CONSTRAINT FK_OrderDetails_Products

-- PRODUCTS 
ALTER TABLE store.Products DROP CONSTRAINT FK_Products_Categories
ALTER TABLE store.ShoppingCartRecords DROP CONSTRAINT FK_ShoppingCartRecords_Products
ALTER TABLE store.OrderDetails DROP CONSTRAINT FK_OrderDetails_Products
ALTER TABLE store.ShoppingCartRecords ADD CONSTRAINT FK_ShoppingCartRecords_Products FOREIGN KEY(ProductId) REFERENCES store.Products (Id)
ALTER TABLE store.Products ADD CONSTRAINT FK_Products_Categories FOREIGN KEY(CategoryId) REFERENCES store.Categories (Id) ON DELETE SET NULL
ALTER TABLE store.OrderDetails ADD CONSTRAINT FK_OrderDetails_Products FOREIGN KEY(ProductId) REFERENCES store.Products (Id)
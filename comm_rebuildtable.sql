USE [IntroToEF6]
GO

DECLARE	@return_value int

EXEC	@return_value = [JakodevUtils].[uspRebuildTable]
		@tableToRebuildDatabase = NULL,
		@tableToRebuildSchema = N'store',
		@tableToRebuildTable = N'Products',
		@tableToRebuildSql = N'(
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CategoryId] [int] NULL,
	[CurrentPrice] [money] NOT NULL,
	[Description] [nvarchar](3800) NOT NULL,
	[IsFeatured] [bit] NOT NULL,
	[ModelName] [nvarchar](50) NOT NULL,
	[ModelNumber] [nvarchar](50) NOT NULL,
	[ProductImage] [nvarchar](150) NULL,
	[ProductImageThumb] [nvarchar](150) NULL,
	[TimeStamp] [timestamp] NOT NULL,
	[UnitCost] [money] NOT NULL,
	[UnitsInStock] [int] NOT NULL,
 CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]',
		@Debugmode = true

SELECT	'Return Value' = @return_value

GO

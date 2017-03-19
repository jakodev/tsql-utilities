USE [IntroToEF6]
GO

DECLARE @runResetBefore bit = 'true' -- reset the DDL script before run. To use to rebuild the same table more than once.
DECLARE	@return_value nvarchar(500)

if @runResetBefore = 'true'
	EXEC [JakodevUtilities].[uspReset]


EXEC	@return_value = [JakodevUtilities].[uspRebuildTable]
		@database = NULL,
		@schema = 'store',
		@table = 'Products',
		@debugMode = 'true',
		@DDL = N'
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
	[UnitsInStock] [int] NOT NULL
 CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
'
		

SELECT	'Return Value' = @return_value

GO

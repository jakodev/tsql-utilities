USE [Sandbox]
GO

DECLARE @runResetBefore bit = 'true' -- reset the DDL script before run. To use to rebuild the same table more than once.
DECLARE	@return_value nvarchar(500)

if @runResetBefore = 'true'
	EXEC [JdevUtils].[uspReset]


EXEC	@return_value = [JdevUtils].[uspRebuildTable]
		@database = NULL,
		@schema = 'dbo',
		@table = 'Orders',
		@debugMode = 'false',
		@DDL = N'
--<INSERT_YOUR_COLUMNS_BETWEEN_THIS_TAG>

	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[PersonID] [int] NOT NULL,
	[OrderAmount] [money] NOT NULL,
	[ShippingAddress] [nvarchar](250) NOT NULL

--</INSERT_YOUR_COLUMNS_BETWEEN_THIS_TAG>
'
		

SELECT	'Return Value' = @return_value

GO

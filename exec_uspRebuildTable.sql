-- switch to your database
USE [YOUR_DATABASE]
GO

-- declarations
DECLARE @testmode bit = 'false'				-- run this script in test mode (suggested on every first approach). Allowed values: true, false
DECLARE @runResetBefore varchar(1) = null	-- reset the DDL scripts (table SqlScript) before to run. Use it when you want rebuild the same table more than once.
											-- allowed values: 	null = do nothing; 
											-- 					'T' = truncate table SqlScript; 
											-- 					'R' = reset the status to 0 of all the scripts in SqlScript

DECLARE @myschema nvarchar(128) = '<your_schema_name>';	-- e.g. 'dbo'
DECLARE @mytable nvarchar(128) = '<your_table_name>';	-- e.g. 'Orders'

DECLARE @myddl nvarchar(max) = N'			
--<INSERT_YOUR_COLUMNS_BETWEEN_THIS_TAG>

-- e.g. 
	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerID] [nchar](5) NULL,
	[EmployeeID] [int] NULL,
	[OrderDate] [datetime] NULL,
	[RequiredDate] [datetime] NULL,
	[ShippedDate] [datetime] NULL,
	[ShipVia] [int] NULL,
	[Freight] [money] NULL,
	[ShipName] [nvarchar](40) NULL,
	[ShipAddress] [nvarchar](60) NULL,
	[ShipCity] [nvarchar](15) NULL,
	[ShipRegion] [nvarchar](15) NULL,
	[ShipPostalCode] [nvarchar](10) NULL,
	[ShipCountry] [nvarchar](15) NULL,
 CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED 
 ([OrderID] ASC)

--</INSERT_YOUR_COLUMNS_BETWEEN_THIS_TAG>
'

DECLARE	@return_value nvarchar(500)

-- Run reset
if @runResetBefore is not null
	EXEC [JdevUtils].[uspReset] @method = @runResetBefore

-- Perform main procedure
EXEC	@return_value = [JdevUtils].[uspRebuildTable]
		@schema = @myschema,
		@table = @mytable,
		@debugMode = @testmode,
		@DDL = @myddl
		

SELECT	'Return Value' = @return_value

GO

-- switch to your database
USE [NORTHWND]
GO

-- declarations
DECLARE @testmode bit = 'false'				-- run in test mode (suggested on every first approach)
DECLARE @runResetBefore bit = 'true'		-- reset the DDL scripts (table SqlScript) before to run. Use it when you want rebuild the same table more than once.
DECLARE @resettype nvarchar(1) = 'R'		-- reset table SqlScripts in two ways: T > truncate table SqlScript; R > change status to 0 in all records.

DECLARE @myschema nvarchar(128) = 'dbo';	-- insert your schema name
DECLARE @mytable nvarchar(128) = 'Orders';	-- insert your table name

DECLARE @myddl nvarchar(max) = N'			
--<INSERT_YOUR_COLUMNS_BETWEEN_THIS_TAG>

	-- this is only an example:

	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerID] [nchar](5) NULL,
	[EmployeeID] [int] NULL,
	[OrderDate] [datetime] NULL,
	[RequiredDate] [datetime] NULL,
	[ShippedDate] [datetime] NULL,
	[ShipVia] [int] NULL,
	[Freight] [money] NULL CONSTRAINT [DF_Orders_Freight]  DEFAULT (0),
	[ShipName] [nvarchar](40) NULL,
	[ShipAddress] [nvarchar](60) NULL,
	[ShipCity] [nvarchar](15) NULL,
	[ShipRegion] [nvarchar](15) NULL,
	[ShipPostalCode] [nvarchar](10) NULL,
	[ShipCountry] [nvarchar](15) NULL,

--</INSERT_YOUR_COLUMNS_BETWEEN_THIS_TAG>
'

DECLARE	@return_value nvarchar(500)

-- Run reset
if @runResetBefore = 'true'
	EXEC [JdevUtils].[uspReset] @method = @resettype

-- Perform main procedure
EXEC	@return_value = [JdevUtils].[uspRebuildTable]
		@schema = @myschema,
		@table = @mytable,
		@debugMode = @testmode,
		@DDL = @myddl
		

SELECT	'Return Value' = @return_value

GO

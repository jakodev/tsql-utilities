# README #

I've begun this tiny program to easily handle the *table drop and recreate* when one or more *foreign keys* are referencing to it... I got carried away and I've developed a little *T-SQL Infrastructure* for easily handle future requirements in a reliable way. 

For this reason this project seems to big for handling only *table drop and recreate* when some *foreign keys* are in the middle.


## Getting Started ##

To begin using this project please do the following:
* Clone the repo: https://github.com/jakodev/tsql-utilities.git
* Fork the repo


## Summary ##
This project comes with a series of objeects to install in your database. Actually there is only one main feature: **Rebuild of tables referenced by foreign keys**.

All the objects (procedures, tables, etc..) will be installed into an independent **SCHEMA** (default name is _JdevUtils_), so you can remove them easily when you don't need anymore. The SCHEMA name is customizable, see the **Configuration** section to learn more about.


## How do I get set up? ##

### Installation ###

+ Open SSMS, choose your database and open a new query editor
+ Import the __Setup.sql__ file into query editor and run it (pressing F5). This script installs the following objects:
    -   1 table
        * [SqlScripts]
    -   4 stored procedures
        * [uspExecScriptsByKeys]
        * [uspDropMe]
        * [uspReset]
        * [uspRebuildTable]
    -   1 view
        * [vForeignKeyCols]


### Configuration ###
All the objects (procedures, tables, etc..) will be installed into a specified **SCHEMA** (default is _JdevUtils_), so you can remove they easily when you don't need anymore. The SCHEMA name is customizable, you can named as you want: edit the variable @schema in **Setup.sql** file:
```sql 
DECLARE @schema nvarchar(128) = N'JdevUtils'
```
If you rename this **SCHEMA** name remember your choice when you are will use the exec_* scripts!


### Dependencies ###
### Database configuration ###
* Tested and developed with SQLSERVER 2014 (using SSMS 2014). I didn't test previous versions but let me know if something don't work in one of them.
* User should have __db_owner__ role or at least rights to CREATE SCHEMA, PROCEDURE, VIEWS, FUNCTIONS, DROP/CREATE/ALTER TABLES.

### How to run tests ###

For testing __Rebuild of tables referenced by foreign keys__ use the script **exec_uspRebuiltTable.sql**
+ You have to configure some item:
	1. Change your database
	1. Set the variable @runResetBefore
	1. 

See the following example:
```sql 
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

```

#### Deployment instructions ####

## Bug and Issue ##

Have a problem with this project? Open an issue here in Github

## Contribution guidelines ##

* Writing tests
* Code review
* Other guidelines

## Who do I talk to? ##

* Repo owner or admin
* Other community or team contact


* [Learn Markdown](https://bitbucket.org/tutorials/markdowndemo)
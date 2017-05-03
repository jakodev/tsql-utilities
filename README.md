# README #

I've begun this small program to easily handle the *re-creation of a table* referenced by one or more **Foreign Keys**. I got carried away and, instead of develop a single easy query, I've developed a *T-SQL based infrastructure* for implement future requirements in a reliable way. Maybe I will not anyway, who knows ;)

For this reason this project seems too big for handling only the *re-creation of a table* when some *foreign keys* are concerned.


## Getting Started ##

To begin using this project please do the following:
* [Clone the repo](https://github.com/jakodev/tsql-utilities.git)
* Fork the repo if you prefer


## Summary ##
This project comes with a series of objects to install in your database. Actually there is only one main feature: **Rebuild of tables referenced by foreign keys**.

All the objects (procedures, tables, etc..) will be installed into an independent **SCHEMA** (default name is _JdevUtils_), so you can remove them easily when you don't need anymore. The SCHEMA name is customizable, if you don't like it you can rename easily (see the [**Configuration**](#configuration) section to learn more about).


## Installation ##

+ Open SSMS, choose your database and open a new query editor
+ Drag and drop the `Setup.sql` file into the query editor and run it (pressing F5). This script installs the following objects:
	- 1 schema
		* [JdevUtils] *(customizable)*
    -   1 table
        * [SqlScript]
    -   4 stored procedures
        * [uspExecScriptsByKeys]
        * [uspDropMe]
        * [uspReset]
        * [uspRebuildTable]
    -   1 view
        * [vForeignKeyCols]

## Uninstall ##
To clean your database simply use the script `exec_uspDropMe.sql` or call directly the procedure `[JdevUtils].[uspDropMe]`. Every objects belonging to the schema `[JdevUtils]` and the **SCHEMA itself** will be removed.

**NOTE**: if during the installation you have changed the default name of the SCHEMA remember your choice in this step.

## Configuration ##
All the objects (procedures, tables, etc..) will be installed under the **SCHEMA** `[JdevUtils]`, so you can remove them easily when you don't need anymore. As I've said above, The **SCHEMA** name is customizable, so you can rename as you want. To do that set your desired name to the variable `@schema` in the `Setup.sql` file:
```sql 
DECLARE @schema nvarchar(128) = N'JdevUtils'
```
**<span style="color: red;">
If you change this default SCHEMA name remember your choice when you will use the  exec_xxxxx.sql scripts!
</span>**

## Database configuration ##
User should have `[db_owner]` role or at least rights to create: SCHEMA, PROCEDURE, VIEWS, FUNCTIONS, DROP/CREATE/ALTER TABLES.

The database doesn't need any particular settings, but for your information I've developed and tested with:
- SQL SERVER 2014 on Windows 7 SP1 (VM VirtualBox)
- SQL SERVER vNEXT on Ubuntu 16.04 (Virtualized with Vagrant + Virtual Box)
- SSMS 2014 and 2017

*Unfortunately I didn't test other mssql versions, but let me know if something don't work in one of them.*


## How to run tests ##

For testing the function __Rebuild of table referenced by foreign keys__ use the script `exec_uspRebuiltTable.sql`

You have to configure some variables in this file before to start:
1. Make sure to exec the script in the intended target database
	- Customize the first row and use your database
1. Set the variables 
	* @testmode, allows to exec the script in test/debug mode. Allowed values:
		- true = run without save anything
		- false = exec the script at your own risk ;)
	* @runResetBefore, if needed reset the `[JdevUtils].[SqlScript]` table before to exec this script. Allowed values: 
		- null = do nothing
		- 'T' = Truncate table
		- 'R' = Set the status 0 to all the scripts contained
	* @myschema : The schema which contains the table to rebuild
	* @mytable : The table to rebuild
	* @myddl : should contains only the DDL of columns, primary key and unique contraints


See the following example:
```sql 
-- switch to your database
USE [NORTHWND]
GO

-- declarations
DECLARE @testmode bit = 'false'				
DECLARE @runResetBefore varchar(1) = null	
DECLARE @myschema nvarchar(128) = 'dbo';
DECLARE @mytable nvarchar(128) = 'Orders';

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
EXEC @return_value = [JdevUtils].[uspRebuildTable] @schema = @myschema, @table = @mytable, @debugMode = @testmode, @DDL = @myddl
		
SELECT	'Return Value' = @return_value

GO

```

## Bug and Issue ##

Have a problem with this project? Open an issue here in Github



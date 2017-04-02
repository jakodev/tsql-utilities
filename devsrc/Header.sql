-- ================================================================================================================================================
/*
-- Name: T-SQL Utilities
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: MAR-2017
-- Version:		0.93.00
-- Description:	
I've begun this tiny program to easily handle the DROP/CREATE TABLE procedure when one or more Foreign Keys are referencing to it. So, to accomplish this
task in a reliable way I have to add some objects like tables, functions, stored procedures etc.. in the target database. And that is what this setup script do

Add a new schema named as the variable @schema (customizable) to the <current database>.
Into this new schema the script add the these items:
- A new table named @tableSqlScripts [SqlScript], used to save the sql scripts to be executed;
- A new stored procedure named [uspExecScriptsByKeys], used to run the scripts saved in @tableSqlScripts;
- A new stored procedure named [uspDropMe], used to delete all the items beloging to this schema, and the schema itself, in order to clean your database;
- A new stored procedure named [uspReset], used to reset/truncate the table @tableSqlScripts;
- A new stored procedure named [uspRebuildTable], used to rebuild your table and at the same time take care of all the referenced foreign keys;
- A new view named vForeignKeyCols, for consulting purpose only;
*/
-- ==================================================================================================================================================

-- You can choose your preferred name (remember this choice for using the provided exec_ scripts) or use the default name
DECLARE @schema nvarchar(128) = N'JdevUtils'


-- ##################################################################################################################################################
DECLARE @version varchar(10) = '0.93.00'	-- Application Version
DECLARE @itemVersion varchar(10)			-- version of each item for PRINT purpose
DECLARE @sql nvarchar(max)					-- used to perform all items creation
DECLARE @procedure nvarchar(128)			-- variable used to name each procedure
DECLARE @view nvarchar(128)					-- variable used to name each view
DECLARE @tableSqlScripts nvarchar(50) = N'SqlScript' 
DECLARE @replaceItem bit = 'true'			-- force drop create items
DECLARE @warnCounter int -- <warning counter that affect last PRINT - TO DO!>
DECLARE @errCounter int -- <error counter that affect last PRINT - TO DO!>

DECLARE @comm_create_function nvarchar(max)
DECLARE @comm_create_procedure nvarchar(max)
-- ##################################################################################################################################################

-- > [@schema] SCHEMA CREATION		*****************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = N'CREATE  SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, N'{schema}', @schema)

if SCHEMA_ID(@schema) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'Schema [' + @schema + N'] has been created in [' + DB_NAME() + N'] database.'
	END TRY
	BEGIN CATCH
		PRINT N'ERROR: ' + N'Cannot create the Schema [' + @schema + N'] in [' + DB_NAME() + N'] database!!'
		PRINT N'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT N'WARNING: ' + N'Schema [' + @schema + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [@schema] SCHEMA CREATION		*****************************************************************************************************************

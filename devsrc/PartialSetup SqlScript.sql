-- > [@tableSqlScripts] TABLE CREATION		*********************************************************************************************************
DECLARE @comm_create_table_scripts varchar(max)

SET @comm_create_table_scripts = 
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	FEB-2017
-- Version:		0.91.00
-- Description:	Table used to store sql script to be executed
-- =============================================

CREATE TABLE {schema}.{table} 
	(	
		obj_schema nvarchar(128) not null
	,	obj_name nvarchar(128) not null
	,	sql_key nvarchar(128) not null
	,	sql_string nvarchar(1000) not null
	,	sql_type nvarchar(50) not null
	,	sql_hash nvarchar(100) not null
	,	sql_status int DEFAULT 0
	,	sql_status_message nvarchar(500) DEFAULT {q}Not executed yet{q}
	,	Timestamp timestamp
	)
	
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_{table} PRIMARY KEY (sql_hash)

-- add description about column sql_status
EXEC sys.sp_addextendedproperty @name=N{q}MS_Description{q}, @value=N{q}0=Never Run; 1=Run Successful; -x=Error code{q} , @level0type=N{q}SCHEMA{q},@level0name=N{q}{schema}{q}, @level1type=N{q}TABLE{q},@level1name=N{q}{table}{q}, @level2type=N{q}COLUMN{q},@level2name=N{q}sql_status{q}
'

SET @sql = @comm_create_table_scripts

if OBJECT_ID(@schema +'.'+@tableSqlScripts) is not null AND @replaceItem = 'true'
BEGIN
	SET @sql = 'DROP TABLE ' + QUOTENAME(@schema)+'.'+QUOTENAME(@tableSqlScripts) + '; PRINT N''Table [{schema}].[{table}] has been dropped from the [{database}] database.''; EXEC sp_sqlexec N''' + @sql + ''''
END

SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{table}', @tableSqlScripts)
SET @sql = REPLACE(@sql, N'{database}', DB_NAME())
SET @sql = REPLACE(@sql, N'{q}', '''''')

if OBJECT_ID(@schema +'.'+@tableSqlScripts) is null OR @replaceItem = 'true'
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'Table [' + @schema + N'].[' + @tableSqlScripts + N'] has been created in the [' + DB_NAME() + N'] database.'
	END TRY
	BEGIN CATCH
		PRINT N'ERROR: ' + N'Cannot create the Table [' + @schema + N'].[' + @tableSqlScripts + N'] in the [' + DB_NAME() + N'] database!!'
		PRINT N'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT N'WARNING: ' + N'Table [' + @schema + N'].[' + @tableSqlScripts + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [@tableSqlScripts] TABLE CREATION		*********************************************************************************************************
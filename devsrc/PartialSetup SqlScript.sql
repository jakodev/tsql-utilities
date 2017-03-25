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
	,	sql_status_message nvarchar(500) DEFAULT ''Not executed yet''
	,	Timestamp timestamp
	)
	
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_{table} PRIMARY KEY (sql_hash)

-- add description about column sql_status
EXEC sys.sp_addextendedproperty @name=N''MS_Description'', @value=N''0=Never Run; 1=Run Successful; -x=Error code'' , @level0type=N''SCHEMA'',@level0name=N''{schema}'', @level1type=N''TABLE'',@level1name=N''{table}'', @level2type=N''COLUMN'',@level2name=N''sql_status''
'

SET @sql = @comm_create_table_scripts
SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{table}', @tableSqlScripts)
if OBJECT_ID(@schema +'.'+@tableSqlScripts) is null
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
-- > [uspReset] PROCEDURE CREATION		*************************************************************************************************************
SET @procedure = N'uspReset'
SET @comm_create_procedure =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: MAR-2017
-- Last update:	MAR-2017
-- Version:		0.91.00
-- Description:	Reset or truncate the table {table}
-- Params:		@method, allows two olny values > {q}R{q} > Reset (set status 0) all the scripts;
--												> {q}T{q} > Truncate the table.	
-- =============================================

CREATE PROCEDURE {schema}.{procedure} 

	@method varchar(1) = {q}R{q}
	
AS

BEGIN

	if @method = {q}T{q}
	BEGIN
		truncate table {schema}.{table}
		PRINT {q}Table {schema}.{table} trucated successful.{q}
	END 

	if @method = {q}R{q}
	BEGIN
		update {schema}.{table} set sql_status = 0, sql_status_message = {q}Reset{q}
		PRINT CONVERT(varchar(100), @@ROWCOUNT) + {q} rows of table {schema}.{table} reset successful.{q}
	END

END
'

SET @sql = @comm_create_procedure

if OBJECT_ID(@schema + N'.' + @procedure) is not null AND @replaceItem = 'true'
BEGIN
	SET @sql = 'DROP PROCEDURE ' + QUOTENAME(@schema)+'.'+QUOTENAME(@procedure) + '; PRINT N''Stored Procedure [{schema}].[{procedure}] has been dropped from the [{database}] database.''; EXEC sp_sqlexec N''' + @sql + ''''
END

SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{procedure}', @procedure)
SET @sql = REPLACE(@sql, N'{table}', @tableSqlScripts)
SET @sql = REPLACE(@sql, N'{database}', DB_NAME())
SET @sql = REPLACE(@sql, N'{q}', '''''') -- double quote because it's an exec of exec

if OBJECT_ID(@schema + N'.' + @procedure) is null OR @replaceItem = 'true'
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'Stored Procedure [' + @schema + N'].[' + @procedure + N'] has been created in the [' + DB_NAME() + N'] database.'
	END TRY
	BEGIN CATCH
		PRINT N'ERROR: ' + N'Cannot create the Stored Procedure [' + @schema + N'].[' + @procedure + N'] in the [' + DB_NAME() + N'] database!!'
		PRINT N'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT N'WARNING: '+ N'Stored Procedure [' + @schema + N'].[' + @procedure + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [uspReset] PROCEDURE CREATION		*************************************************************************************************************

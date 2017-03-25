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
-- Params:		@method, allows two olny values > ''R'' > Reset (set status 0) all the scripts;
--												> ''T'' > Truncate the table.	
-- =============================================

CREATE PROCEDURE {schema}.{procedure} 

	@method varchar(1) = ''R''
	
AS

BEGIN

	if @method = ''T''
	BEGIN
		truncate table {schema}.{table}
		PRINT ''Table {schema}.{table} trucated successful.''
	END 

	if @method = ''R''
	BEGIN
		update {schema}.{table} set sql_status = 0, sql_status_message = ''Reset''
		PRINT CONVERT(varchar(100), @@ROWCOUNT) + '' rows of table {schema}.{table} reset successful.''
	END

END
'

SET @sql = @comm_create_procedure
SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{procedure}', @procedure)
SET @sql = REPLACE(@sql, N'{table}', @tableSqlScripts)
if OBJECT_ID(@schema + N'.' + @procedure) is null
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
	PRINT N'WARNING: ' + N'Stored Procedure [' + @schema + N'].[' + @procedure + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [uspReset] PROCEDURE CREATION		*************************************************************************************************************

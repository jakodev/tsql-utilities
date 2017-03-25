-- > [uspDropMe] PROCEDURE CREATION		*************************************************************************************************************
SET @procedure = N'uspDropMe'
SET @comm_create_procedure =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: FEB-2017
-- Last update:	MAR-2017
-- Version:		0.91.00
-- Description:	Drop all the items (tables, procedures, functions..) belonging the schema {schema} and the schema itself.
-- =============================================

CREATE PROCEDURE {schema}.{procedure}
(
	@schema varchar(128) = ''{schema}''
)

AS

BEGIN

	DECLARE @object_name varchar(128)
	DECLARE @object_type varchar(2)
	DECLARE @sql varchar(max)

	DECLARE drop_cursor CURSOR FOR select name, type from sys.objects where SCHEMA_NAME(schema_id) = @schema and type in (''FN'', ''P'', ''U'', ''V'')

	OPEN drop_cursor
	FETCH NEXT FROM drop_cursor INTO @object_name, @object_type

	-- check for schema existence
	IF (@@FETCH_STATUS = -1)
	BEGIN
		PRINT ''Cannot find any Schema named ['' + @schema + ''] in the ['' + DB_NAME() + ''] database!!''
		CLOSE drop_cursor
		DEALLOCATE drop_cursor
		RETURN 0
	END 

	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		SET @sql =
			CASE @object_type
				WHEN ''FN'' THEN ''DROP FUNCTION {schema}.{object}''
				WHEN ''P'' THEN ''DROP PROCEDURE {schema}.{object}''
				WHEN ''U'' THEN ''DROP TABLE {schema}.{object}''
				WHEN ''V'' THEN ''DROP VIEW {schema}.{object}''
				ELSE null
			END

		IF @sql is not null
			BEGIN
				SET @sql = REPLACE(@sql, ''{schema}'', @schema)
				SET @sql = REPLACE(@sql, ''{object}'', @object_name)
				EXEC sp_sqlexec @sql
				PRINT ''OBJECT '' + @schema +''.''+@object_name + '' dropped!''
			END	

		FETCH NEXT FROM drop_cursor INTO @object_name, @object_type

	END

	CLOSE drop_cursor
	DEALLOCATE drop_cursor

	IF SCHEMA_ID(@schema) is not null
		BEGIN
			SET @sql = ''DROP SCHEMA {schema}''
			SET @sql = REPLACE(@sql, ''{schema}'', @schema)
			EXEC sp_sqlexec @sql
			PRINT ''SCHEMA '' + @schema + '' dropped!''
		END
		
END
'

SET @sql = @comm_create_procedure
SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{procedure}', @procedure)
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
-- < [uspDropMe] PROCEDURE CREATION		*************************************************************************************************************

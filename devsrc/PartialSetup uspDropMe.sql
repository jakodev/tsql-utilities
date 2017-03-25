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
	@schema varchar(128) = {q}{schema}{q}
)

AS

BEGIN

	DECLARE @object_name varchar(128)
	DECLARE @object_type varchar(2)
	DECLARE @sql varchar(max)

	DECLARE drop_cursor CURSOR FOR select name, type from sys.objects where SCHEMA_NAME(schema_id) = @schema and type in ({q}FN{q}, {q}P{q}, {q}U{q}, {q}V{q})

	OPEN drop_cursor
	FETCH NEXT FROM drop_cursor INTO @object_name, @object_type

	-- check for schema existence
	IF (@@FETCH_STATUS = -1)
	BEGIN
		PRINT {q}Cannot find any Schema named [{q} + @schema + {q}] in the [{q} + DB_NAME() + {q}] database!!{q}
		CLOSE drop_cursor
		DEALLOCATE drop_cursor
		RETURN 0
	END 

	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		SET @sql =
			CASE @object_type
				WHEN {q}FN{q} THEN {q}DROP FUNCTION {schema}.{object}{q}
				WHEN {q}P{q} THEN {q}DROP PROCEDURE {schema}.{object}{q}
				WHEN {q}U{q} THEN {q}DROP TABLE {schema}.{object}{q}
				WHEN {q}V{q} THEN {q}DROP VIEW {schema}.{object}{q}
				ELSE null
			END

		IF @sql is not null
			BEGIN
				SET @sql = REPLACE(@sql, {q}{schema}{q}, @schema)
				SET @sql = REPLACE(@sql, {q}{object}{q}, @object_name)
				EXEC sp_sqlexec @sql
				PRINT {q}OBJECT {q} + @schema +{q}.{q}+@object_name + {q} dropped!{q}
			END	

		FETCH NEXT FROM drop_cursor INTO @object_name, @object_type

	END

	CLOSE drop_cursor
	DEALLOCATE drop_cursor

	IF SCHEMA_ID(@schema) is not null
		BEGIN
			SET @sql = {q}DROP SCHEMA {schema}{q}
			SET @sql = REPLACE(@sql, {q}{schema}{q}, @schema)
			EXEC sp_sqlexec @sql
			PRINT {q}SCHEMA {q} + @schema + {q} dropped!{q}
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
	PRINT N'WARNING: ' + N'Stored Procedure [' + @schema + N'].[' + @procedure + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [uspDropMe] PROCEDURE CREATION		*************************************************************************************************************

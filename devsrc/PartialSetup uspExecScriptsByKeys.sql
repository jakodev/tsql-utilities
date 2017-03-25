-- > [uspExecScriptsByKeys] PROCEDURE CREATION		*************************************************************************************************
SET @procedure = N'uspExecScriptsByKeys'
SET @comm_create_procedure =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	FEB-2017
-- Version:		0.91.00
-- Description:	Execute the scripts stored into the {table} table based on the filters passed as arguments. 
--				Each argument different from NULL or {q}{q} is used as AND operator in the where clause. 
--				Only scripts in status 0 will be executed, otherwise a warning will be printed.
-- =============================================

CREATE PROCEDURE {schema}.{procedure}
(
	@obj_schema varchar(128) = null,
	@obj_name varchar(128) = null,
	@sql_key varchar(128) = null,
	@sql_type varchar(50) = null,
	@sql_hash varchar(100) = null
)
AS

DECLARE sql_script_cursor CURSOR FOR	SELECT sql_string, sql_hash, sql_status
										FROM {schema}.{table}
										WHERE	(ISNULL(@obj_schema,{q}0{q}	) in ({q}0{q},{q}{q}) or (	obj_schema	= @obj_schema	))
										AND		(ISNULL(@obj_name,	{q}0{q}	) in ({q}0{q},{q}{q}) or (	obj_name	= @obj_name		))
										AND		(ISNULL(@sql_key,	{q}0{q}	) in ({q}0{q},{q}{q}) or (	sql_key		= @sql_key		))
										AND		(ISNULL(@sql_type,	{q}0{q}	) in ({q}0{q},{q}{q}) or (	sql_type	= @sql_type		))
										AND		(ISNULL(@sql_hash,	{q}0{q}	) in ({q}0{q},{q}{q}) or (	sql_hash	= @sql_hash		))
										AND		(COALESCE(NULLIF(@obj_schema,	{q}{q})
														, NULLIF(@obj_name,		{q}{q})
														, NULLIF(@sql_key,		{q}{q})
														, NULLIF(@sql_type,		{q}{q})
														, NULLIF(@sql_hash,		{q}{q})
												) is not null)

DECLARE @sql varchar(max)
DECLARE @hash varchar(50)
DECLARE @status int

BEGIN
	
	OPEN sql_script_cursor
	FETCH NEXT FROM sql_script_cursor INTO @sql, @hash, @status
	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		BEGIN TRY
			
			IF @status = 1
				BEGIN
					PRINT {q}WARNING: This script was skipped due to a previous execution: {q} + {q}"{q} + @sql + {q}"{q} + {q} ({q} + @hash + {q}){q}
				END
			ELSE
				BEGIN
					EXEC sp_sqlexec @sql
					PRINT {q}Successful execution of {q} + {q}"{q} + @sql + {q}"{q}
					UPDATE {schema}.{table} SET sql_status = 1, sql_status_message = {q}Success{q} WHERE sql_hash = @hash
				END

		END TRY

		BEGIN CATCH
		
			DECLARE @ErrorMessage NVARCHAR(4000);
			DECLARE @ErrorNumber INT;

			SELECT	@ErrorMessage = ERROR_MESSAGE(),
					@ErrorNumber = ERROR_NUMBER();
			
			UPDATE {schema}.{table} SET sql_status = -@ErrorNumber, sql_status_message = @ErrorMessage WHERE sql_hash = @hash
		
		END CATCH
		
		FETCH NEXT FROM sql_script_cursor INTO @sql, @hash, @status

	END

	CLOSE sql_script_cursor
	DEALLOCATE sql_script_cursor

END'

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
-- < [uspExecScriptsByKeys] PROCEDURE CREATION		*************************************************************************************************
/*-- ================================================================================================================================================
-- Name: MRWOLF-UTILITIES
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: JAN-2017
-- Version:		2.01.00
-- Description:	
Drop all the stored procedure, functions and table belonging to MRWOLF schema, and the schema itself.
-- ================================================================================================================================================*/
BEGIN

	DECLARE @schema varchar(128) = 'mrwolf'
	DECLARE @object_name varchar(128)
	DECLARE @object_type varchar(2)
	DECLARE @sql varchar(max)

	DECLARE drop_cursor CURSOR FOR select name, type from sys.objects where SCHEMA_NAME(schema_id) = @schema and type in ('FN', 'P', 'U')

	OPEN drop_cursor
	FETCH NEXT FROM drop_cursor INTO @object_name, @object_type
	WHILE (@@FETCH_STATUS = 0)
	BEGIN

		SET @sql =
			CASE @object_type
				WHEN 'FN' THEN 'DROP FUNCTION {schema}.{object}'
				WHEN 'P' THEN 'DROP PROCEDURE {schema}.{object}'
				WHEN 'U' THEN 'DROP TABLE {schema}.{object}'
				ELSE null
			END

		IF @sql is not null
			BEGIN
				SET @sql = REPLACE(@sql, '{schema}', @schema)
				SET @sql = REPLACE(@sql, '{object}', @object_name)
				EXEC sp_sqlexec @sql
				PRINT 'OBJECT ' + @schema +'.'+@object_name + ' dropped!'
			END	

		FETCH NEXT FROM drop_cursor INTO @object_name, @object_type

	END

	CLOSE drop_cursor
	DEALLOCATE drop_cursor

	IF SCHEMA_ID(@schema) is not null
		BEGIN
			SET @sql = 'DROP SCHEMA {schema}'
			SET @sql = REPLACE(@sql, '{schema}', @schema)
			EXEC sp_sqlexec @sql
			PRINT 'SCHEMA ' + @schema + ' dropped!'
		END
		

END
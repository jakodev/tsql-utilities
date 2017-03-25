-- > [uspRebuildTable] PROCEDURE CREATION		*****************************************************************************************************
SET @procedure = N'uspRebuildTable'
SET @comm_create_procedure =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	MAR-2017
-- Version:		0.92.00
-- Description:	Dropping and Creation of an existing table and, at the same time, takes care of all the attached foreign keys. 
-- Goal is performed in 5 steps:
-- 1) Analisys and saving DDL of all foreign keys;
-- 2) Drop of the Foreign Keys;
-- 3) Drop of the Table;
-- 4) Creation of the Table (you must provide as parameter only the code to add the columns);
-- 5) Creation of the Foreign Keys saved before;


-- Params:	@database (optional): the database where reside the table to rebuild;
--			@schema: the schema of the table;
--			@table: the table to rebuild;
--			@DDL: Columns DDL (you must provide only the DDL to add the columns)
--			@debugMode: allow only two values	> ''true'', no drop performed. To use for checking if all the necessary scripts will be generated;
--												> ''false'', performs all the tasks that the procedure is intended to do.
-- =============================================

CREATE PROCEDURE {schema}.{procedure}

	@database varchar(128) = NULL, -- NULL means current database
	@schema varchar(128),
	@table varchar(128),
	@DDL varchar(max),
	@debugMode bit = ''true''

AS
BEGIN
	IF @debugMode = ''true''
		PRINT ''Debug mode enabled, no changes will be saved''

	IF COALESCE(@schema,'''') = ''''
	BEGIN
		PRINT ''Schema cannot be empty or null''
		RETURN -1
	END

	IF COALESCE(@table, '''') = ''''
	BEGIN
		PRINT ''Table cannot be empty or null''
		RETURN -1
	END
	
	DECLARE @sql varchar(max)
	DECLARE @tableToRebuild varchar(384) = COALESCE(@database, DB_NAME()) + ''.'' + @schema + ''.'' + @table	
	DECLARE @comm_create_table varchar(max) = N''CREATE TABLE {usp_table} ('' + @DDL + '')''
	DECLARE @returnValue int = 0
	
	-- > (1) ANALISYS AND SAVING FK''s DDL **********************************************************************************************************
	BEGIN TRY
	INSERT INTO [{schema}].[{table}] (obj_schema, obj_name, sql_key, sql_string, sql_type, sql_hash)
	select	mainquery.obj_schema
	,		mainquery.obj_name
	,		mainquery.sql_key
	,		mainquery.sql_string
	,		mainquery.sql_type
	,		CONVERT( varchar(50), HASHBYTES(''SHA1'',mainquery.sql_string), 2) as "sql_hash"
	from ( 
		-- query for create foreign keys
		SELECT	OBJECT_SCHEMA_NAME(fk.object_id) as "obj_schema"
		,		OBJECT_NAME(fk.parent_object_id) as "obj_name"
		,		OBJECT_NAME(OBJECT_ID(@tableToRebuild)) as "sql_key"
		,		''ALTER TABLE '' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.object_id))+''.''+ QUOTENAME(OBJECT_NAME(fk.parent_object_id))
		+		'' ADD CONSTRAINT '' + QUOTENAME(OBJECT_NAME(object_id))
		+		'' FOREIGN KEY'' 
		-- concatenation of the child''s (constraint) columns name (STUFF is used to remove the first comma)
		+		''('' +   STUFF ((SELECT '','' + QUOTENAME(col.name) FROM sys.foreign_key_columns fkcol
											JOIN sys.all_columns col on (col.column_id = fkcol.parent_column_id and col.object_id = fkcol.parent_object_id) -- child (constraint) fk columns
											WHERE constraint_object_id = fk.object_id order by fkcol.parent_column_id
											FOR XML PATH (N''''), TYPE).value(''.'', ''varchar(max)''), 1, 1, N'''') + '')''
		+		'' REFERENCES '' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.referenced_object_id)) + ''.'' + QUOTENAME(OBJECT_NAME(fk.referenced_object_id))
		-- concatenation of the parent''s (referenced) columns name (STUFF is used to remove the first comma)
		+		''('' + STUFF ((SELECT '','' + QUOTENAME(col.name) FROM sys.foreign_key_columns fkcol
											JOIN sys.all_columns col on (col.column_id = fkcol.referenced_column_id and col.object_id = fkcol.referenced_object_id) -- parent (referenced) fk columns
											WHERE constraint_object_id = fk.object_id order by fkcol.parent_column_id
											FOR XML PATH (N''''), TYPE).value(''.'', ''varchar(max)''), 1, 1, N'''') + '')''
		+		CASE WHEN fk.update_referential_action_desc != ''NO_ACTION'' THEN '' ON UPDATE '' + REPLACE(fk.update_referential_action_desc, ''_'', '' '') ELSE '''' END
		+		CASE WHEN fk.delete_referential_action_desc != ''NO_ACTION'' THEN '' ON DELETE '' + REPLACE(fk.delete_referential_action_desc, ''_'', '' '') ELSE '''' END COLLATE database_default as "sql_string"
		,		''ADD_FOREIGN_KEY_CONSTRAINT'' as "sql_type"
		FROM sys.foreign_keys fk
		WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)
		
		UNION ALL

		-- query for drop foreign keys
		SELECT	OBJECT_SCHEMA_NAME(fk.object_id) as "obj_schema"
		,		OBJECT_NAME(fk.parent_object_id) as "obj_name"
		,		OBJECT_NAME(OBJECT_ID(@tableToRebuild)) as "sql_key"
		,		''ALTER TABLE '' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + ''.'' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + '' DROP CONSTRAINT ''+ QUOTENAME(fk.name) COLLATE database_default as "sql_string"
		,		''DROP_FOREIGN_KEY_CONSTRAINT'' as sql_type 
		FROM sys.foreign_keys fk
		WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)
	) mainquery
	END TRY
	BEGIN CATCH
		SET @returnValue = -ERROR_NUMBER()
		DECLARE @err_num INT = ERROR_NUMBER()
		DECLARE @err_msg NVARCHAR(4000) = ERROR_MESSAGE()
		PRINT ''Something gone wrong! the insert statement raised the following error:''
		PRINT ''Error Number:'' + CONVERT( varchar(10), @err_num) + '' - ''+ @err_msg 
		IF @err_num = 2627 -- known issue, not a real problem
		BEGIN
			PRINT ''Maybe you''''ve run this procedure in debug mode more than once without reset the environment between the first and the last execution''
			PRINT ''''
			@returnValue = 0
		END
		ELSE
			RETURN @returnValue
	END CATCH
	-- < (1) ANALISYS AND SAVING FK''s DDL **********************************************************************************************************

	-- > (2) DROP THE FOREIGN KEYS	*****************************************************************************************************************
	SET @sql = ''EXEC {schema}.uspExecScriptsByKeys @sql_key=''''{usp_table}'''', @sql_type=''''DROP_FOREIGN_KEY_CONSTRAINT''''''
	SET @sql = REPLACE(@sql, ''{usp_table}'', OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
	IF @debugMode = ''false''
	BEGIN
		-- try/catch handled by called procedure
		EXEC sp_sqlexec @sql
	END
	ELSE
		PRINT ''DROP FOREIGN KEYS (Debug mode enabled)''

	-- < (2) DROP THE FOREIGN KEYS	*****************************************************************************************************************

	-- > (3) DROP TABLE		*************************************************************************************************************************
	DECLARE @comm_drop_table varchar(max) = ''DROP TABLE {usp_table}''
	SET @sql = @comm_drop_table
	SET @sql = REPLACE(@sql, ''{usp_table}'', @tableToRebuild)
	IF OBJECT_ID(@tableToRebuild) is not null
	BEGIN
		IF @debugMode = ''false''
		BEGIN
			BEGIN TRY
				EXEC sp_sqlexec @sql
				PRINT ''Table '' + @tableToRebuild + '' has been dropped successful!''
			END TRY
			BEGIN CATCH
				SET @returnValue = -ERROR_NUMBER()
				PRINT ''SQLERROR-'' + CONVERT( varchar(10), ERROR_NUMBER()) + '': '' + ERROR_MESSAGE()
				RETURN @returnValue
			END CATCH
		END	
		ELSE
			PRINT ''DROP TABLE (Debug mode enabled)''
	END
	-- < (3) DROP TABLE		*************************************************************************************************************************
	
	-- > (4) CREATE TABLE	*************************************************************************************************************************
	SET @sql = @comm_create_table
	SET @sql = REPLACE(@sql, ''{usp_table}'', @tableToRebuild)
	IF OBJECT_ID(@tableToRebuild) is null
	BEGIN
		IF @debugMode = ''false''
		BEGIN
			BEGIN TRY
				EXEC sp_sqlexec @sql
				PRINT ''Table '' + @tableToRebuild + '' has been created successful!''
			END TRY
			BEGIN CATCH
				SET @returnValue = -ERROR_NUMBER()
				PRINT ''SQLERROR-'' + CONVERT( varchar(10), ERROR_NUMBER()) + '': '' + ERROR_MESSAGE()
				RETURN @returnValue
			END CATCH
		END
		ELSE
			PRINT ''CREATE TABLE (Debug mode enabled)''
	END
	ELSE
		PRINT ''CREATE TABLE ignored, table already exists!''
	-- < (4) CREATE TABLE	*************************************************************************************************************************
	
	-- > (5) FOREIGN KEYS RESTORING		*************************************************************************************************************
	SET @sql = ''EXEC {schema}.uspExecScriptsByKeys @sql_key=''''{usp_table}'''', @sql_type=''''ADD_FOREIGN_KEY_CONSTRAINT''''''
	SET @sql = REPLACE(@sql, ''{usp_table}'', OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
	IF @debugMode = ''false''
	BEGIN
		-- try/catch handled by called procedure
		EXEC sp_sqlexec @sql
	END
	ELSE
	BEGIN
		PRINT ''RESTORE FOREIGN KEYS (Debug mode enabled)''
		SET @sql = ''SELECT * FROM [{schema}].[{table}]''
		EXEC sp_sqlexec @sql
	END
	-- < (5) FOREIGN KEYS RESTORING		*************************************************************************************************************

	DECLARE @errors int
	SELECT @errors = COUNT(*)
	FROM [{schema}].[{table}] 
	WHERE sql_status < 0 AND sql_key=OBJECT_NAME(OBJECT_ID(@tableToRebuild)) AND sql_type IN (''ADD_FOREIGN_KEY_CONSTRAINT'',''DROP_FOREIGN_KEY_CONSTRAINT'')

	IF @errors > 0
	BEGIN
		PRINT ''ATTENTION: check for the table {table} (or the ''''Results'''' panel), some errors was raised!''
		SET @sql = ''SELECT * FROM [{schema}].[{table}] WHERE sql_status < 0''
		EXEC sp_sqlexec @sql
	END
		
	RETURN @returnValue
-- **************************************************************************************************************************************************

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
-- < [uspRebuildTable] PROCEDURE CREATION		*****************************************************************************************************
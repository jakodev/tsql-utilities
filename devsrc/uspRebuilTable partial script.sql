-- > [uspRebuildTable] PROCEDURE CREATION		*************************************************************************************************
SET @procedure = 'uspRebuildTable'
SET @comm_create_procedure =
N'CREATE PROCEDURE {schema}.{procedure}
	-- Add the parameters for the stored procedure here
	@tableToRebuildDatabase varchar(128) = NULL, -- NULL means current database
	@tableToRebuildSchema varchar(128),
	@tableToRebuildTable varchar(128),
	@tableToRebuildSql varchar(max),
	@Debugmode bit = ''true''

AS
BEGIN
	IF @Debugmode = ''true''
		PRINT ''Debug mode enabled, no changes will be saved''

	IF @tableToRebuildSchema = '''' or @tableToRebuildSchema is null
	BEGIN
		PRINT ''Schema cannot be empty or null''
		RETURN
	END

	IF @tableToRebuildTable = '''' or @tableToRebuildTable is null
	BEGIN
		PRINT ''Table cannot be empty or null''
		RETURN
	END
	
	DECLARE @sql varchar(max)
	DECLARE @schema varchar(128) = ''{schema}''
		
	DECLARE @tableToRebuild varchar(384) = COALESCE(@tableToRebuildDatabase, DB_NAME()) + ''.'' + @tableToRebuildSchema + ''.'' + @tableToRebuildTable	
	DECLARE @comm_create_table varchar(max) = N''CREATE TABLE {usp_table} '' + @tableToRebuildSql
	
	-- > BUILDING SCRIPTS FOR DROP and CREATE FOREIGN KEYS **********************************************************************************************
	BEGIN TRY
	INSERT INTO [{schema}].[SqlScript] (obj_schema, obj_name, sql_key, sql_string, sql_type, sql_hash)
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
		,		''ALTER TABLE '' + OBJECT_SCHEMA_NAME(fk.object_id)+''.''+ OBJECT_NAME(fk.parent_object_id) 
		+		'' ADD CONSTRAINT '' + OBJECT_NAME(object_id)
		+		'' FOREIGN KEY('' +   [{schema}].[ufnConcatFkColumnNames](fk.object_id, fk.parent_object_id, ''C'') + '')''
		+		'' REFERENCES '' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + ''.'' + OBJECT_NAME(fk.referenced_object_id) + '' ('' + [{schema}].[ufnConcatFkColumnNames](fk.object_id, fk.referenced_object_id, ''P'') + '')'' 
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
		,		''ALTER TABLE '' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + ''.'' + OBJECT_NAME(fk.parent_object_id) + '' DROP CONSTRAINT ''+fk.name COLLATE database_default as "sql_string"
		,		''DROP_FOREIGN_KEY_CONSTRAINT'' as sql_type 
		FROM sys.foreign_keys fk
		WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)
	) mainquery
	END TRY
	BEGIN CATCH
		DECLARE @err_num INT = ERROR_NUMBER()
		DECLARE @err_msg NVARCHAR(4000) = ERROR_MESSAGE()
		PRINT ''Something gone wrong! the insert statement raised the following error:''
		PRINT ''Error Number:'' + CONVERT( varchar(10), @err_num) + '' - ''+ @err_msg 
		IF @err_num = 2627
			PRINT ''Maybe you''''ve run this procedure in debug mode more than once without reset the environment between the first and the last execution''
			PRINT ''''
	END CATCH
	-- < BUILDING SCRIPTS FOR DROP and CREATE FOREIGN KEYS **********************************************************************************************

	/*
	Following code will perform:
	1) DROP FOREIGN KEYS (connected to @tableToRebuild)
	2) DROP TABLE (@tableToRebuild)
	3) CREATE TABLE: <this part shoul be edited in order to apply desidered modification>
	4) RESTORE FOREIGN KEYS : If all gone well, all the fk will be restored by the script saved before, do you rememeber?
	*/
	
	-- > (1) DROP THE FOREIGN KEYS	*********************************************************************************************************************
	SET @sql = ''EXEC {schema}.uspExecScriptsByKeys @sql_key=''''{usp_table}'''', @sql_type=''''DROP_FOREIGN_KEY_CONSTRAINT''''''
	SET @sql = REPLACE(@sql, ''{usp_table}'', OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
	IF @Debugmode = ''false''
	BEGIN
		-- try/catch handled by called procedure
		EXEC sp_sqlexec @sql
	END
	ELSE
		PRINT ''DROP FOREIGN KEYS (Debug mode enabled)''

	-- < (1) DROP THE FOREIGN KEYS	*********************************************************************************************************************

	
	-- > (2) DROP TABLE		*****************************************************************************************************************************
	DECLARE @comm_drop_table varchar(max) = ''DROP TABLE {usp_table}''
	SET @sql = @comm_drop_table
	SET @sql = REPLACE(@sql, ''{usp_table}'', @tableToRebuild)
	IF OBJECT_ID(@tableToRebuild) is not null
	BEGIN
		IF @Debugmode = ''false''
		BEGIN
			BEGIN TRY
				EXEC sp_sqlexec @sql
				PRINT ''Table '' + @tableToRebuild + '' has been dropped successful!''
			END TRY
			BEGIN CATCH
				PRINT ''SQLERROR-'' + CONVERT( varchar(10), ERROR_NUMBER()) + '': '' + ERROR_MESSAGE()
			END CATCH
		END	
		ELSE
		PRINT ''DROP TABLE (Debug mode enabled)''
	END
	-- < (2) DROP TABLE		*****************************************************************************************************************************
	
	-- > (3) CREATE TABLE	*****************************************************************************************************************************
	SET @sql = @comm_create_table
	SET @sql = REPLACE(@sql, ''{usp_table}'', @tableToRebuild)
	IF OBJECT_ID(@tableToRebuild) is null
	BEGIN
		IF @Debugmode = ''false''
		BEGIN
			BEGIN TRY
				EXEC sp_sqlexec @sql
				PRINT ''Table '' + @tableToRebuild + '' has been created successful!''
			END TRY
			BEGIN CATCH
				PRINT ''SQLERROR-'' + CONVERT( varchar(10), ERROR_NUMBER()) + '': '' + ERROR_MESSAGE()
			END CATCH
		END
		ELSE
			PRINT ''CREATE TABLE (Debug mode enabled)''
	END
	ELSE
		PRINT ''CREATE TABLE ignored, table already exists!''
	-- < (3) CREATE TABLE	*****************************************************************************************************************************
	
	-- > (4) RESTORE THE FOREIGN KEYS		*************************************************************************************************************
	SET @sql = ''EXEC {schema}.uspExecScriptsByKeys @sql_key=''''{usp_table}'''', @sql_type=''''ADD_FOREIGN_KEY_CONSTRAINT''''''
	SET @sql = REPLACE(@sql, ''{usp_table}'', OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
	IF @Debugmode = ''false''
	BEGIN
		-- try/catch handled by called procedure
		EXEC sp_sqlexec @sql
	END
	ELSE
		BEGIN
			PRINT ''RESTORE FOREIGN KEYS (Debug mode enabled)''
			SET @sql = ''SELECT * FROM [{schema}].[SqlScript]''
			EXEC sp_sqlexec @sql
		END
	-- < (4) RESTORE THE FOREIGN KEYS		*************************************************************************************************************

	DECLARE @errors int
	SELECT @errors = COUNT(*)
	FROM [{schema}].[SqlScript] 
	WHERE sql_status < 0 AND sql_key=OBJECT_NAME(OBJECT_ID(@tableToRebuild)) AND sql_type IN (''ADD_FOREIGN_KEY_CONSTRAINT'',''DROP_FOREIGN_KEY_CONSTRAINT'')

	IF @errors > 0
		BEGIN
			PRINT ''ATTENTION: check for the table SqlScript (or the ''''Results'''' panel), some errors was raised!''
			SET @sql = ''SELECT * FROM [{schema}].[SqlScript] WHERE sql_status < 0''
			EXEC sp_sqlexec @sql
		END
		
-- **************************************************************************************************************************************************

END
'

SET @sql = @comm_create_procedure
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
if OBJECT_ID(@schema +'.'+@procedure) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT 'Stored Procedure [' + @schema + '].[' + @procedure + '] has been created in the [' + DB_NAME() + '] database.'
	END TRY
	BEGIN CATCH
		PRINT 'ERROR: ' + 'Cannot create the Stored Procedure [' + @schema + '].[' + @procedure + '] in the [' + DB_NAME() + '] database!!'
		PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT 'WARNING: '+ 'Stored Procedure [' + @schema + '].[' + @procedure + '] has not been created because was already present in [' + DB_NAME() + '] database.'
END
-- < [uspRebuildTable] PROCEDURE CREATION		*************************************************************************************************
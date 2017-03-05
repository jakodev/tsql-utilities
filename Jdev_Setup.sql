-- ================================================================================================================================================
/*
-- Name: JAKODEV-UTILITIES
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: MAR-2017
-- Version:		0.91.00
-- Description:	
I've begun this tiny program to easily handle the DROP/CREATE TABLE procedure when one o more Foreign Keys are referencing to it. So, to accomplish this
task I need to add some items like tables, functions, stored procedures etc.. in the target database. And that is what this setup script do

Add a new schema named as the variable @schema (customizable) to the <current database> (DB_NAME()).
Into this new schema add the following items:
- A new table named [SqlScript], used to save the sql scripts to be executed;
- A new function named [ufnConcatFkColumnNames], used to concatenate column names belonging to the foreign keys;
- A new stored procedure named [uspExecScriptsByKeys], used to run the scripts saved in @tbl_scripts;
- A new stored procedure named [uspDropMe], used to delete all the items beloging to this schema, and the schema itself, in order to clean your database;
- A new stored procedure named [uspReset], used to truncate the table SqlScript;
- A new stored procedure named [uspRebuildTable], used to rebuild your table and at the same time take care of all the referenced foreign keys
- A new view named vForeignKeyCols, for consulting purpose only;
*/
-- ==================================================================================================================================================

-- You can choose your preferred name (remember this choice) or use the default name
DECLARE @schema nvarchar(128) = N'JakodevUtilities'


-- ##################################################################################################################################################
DECLARE @sql nvarchar(max)
DECLARE @function nvarchar(128)
DECLARE @procedure nvarchar(128)
DECLARE @view nvarchar(128)
DECLARE @tableSqlScripts nvarchar(50) = N'SqlScript'
DECLARE @forceItemCreation bit = 'false'	-- <da implementare>!!

DECLARE @comm_create_function nvarchar(max)
DECLARE @comm_create_procedure nvarchar(max)
-- ##################################################################################################################################################

-- > [@schema] SCHEMA CREATION		*****************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = N'CREATE  SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, N'{schema}', @schema)
if SCHEMA_ID(@schema) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'Schema [' + @schema + N'] has been created in [' + DB_NAME() + N'] database.'
	END TRY
	BEGIN CATCH
		PRINT N'ERROR: ' + N'Cannot create the Schema [' + @schema + N'] in [' + DB_NAME() + N'] database!!'
		PRINT N'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT N'WARNING: ' + N'Schema [' + @schema + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [@schema] SCHEMA CREATION		*****************************************************************************************************************

-- > [@tbl_scripts] TABLE CREATION		*************************************************************************************************************
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
-- < [@tbl_scripts] TABLE CREATION		*************************************************************************************************************

-- > [ufnConcatFkColumnNames] FUNCTION CREATION		*************************************************************************************************
SET @function = N'ufnConcatFkColumnNames'
SET @comm_create_function =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	MAR-2017
-- Version:		0.90.00
-- Description:	Returns a concatenated list of Foreign Key''s column names.
-- Params:		@tableIdRef, the table referenced by the foreign key identified by its object_id
--				@tableId, object_id of parent table or child table, the value passed here must be in according with arg @tableIdType
--				@tableIdType, allow two only values	> ''C'' returns the constraint columns (fk child columns)	>> @tableId must be the parent_object_id
--													> ''P'' returns the referenced columns (fk parent columns)	>> @tableId must be the referenced_object_id

-- Note: 
-- in SQLSERVER the child table is identified by the field parent_object_id
-- in SQLSERVER the parent table is identified by the field referenced_object_id
-- =============================================

CREATE FUNCTION {schema}.{function}
(
	@tableIdRef int,	
	@tableId int,				
	@tableIdType char(1)				
)
RETURNS nvarchar(500)

AS

BEGIN
	
	DECLARE @ResultVar nvarchar(1000) = ''''
	DECLARE @Name nvarchar(50)
	DECLARE @index int = 1
	DECLARE @parentCol int		-- the constrained column (child table)
	DECLARE @referencedCol int	-- the referenced column (parent table)

	DECLARE c_cols CURSOR FOR SELECT parent_column_id, referenced_column_id FROM sys.foreign_key_columns WHERE constraint_object_id = @tableIdRef
	
	OPEN c_cols
	FETCH NEXT FROM c_cols INTO @parentCol, @referencedCol
	WHILE (@@FETCH_STATUS = 0)

	BEGIN
		IF @index > 1
			SET @ResultVar = CONCAT(@ResultVar, '', '');

		IF @tableIdType = ''C''
			SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableId and column_id = @parentCol
		ELSE
			IF @tableIdType = ''P''
				SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableId and column_id = @referencedCol
			ELSE
				SET @Name = ''Undefined''

		SET @ResultVar = CONCAT(@ResultVar, @Name)
		SET @index = @index + 1

		FETCH NEXT FROM c_cols INTO @parentCol, @referencedCol
	END

	CLOSE c_cols
	DEALLOCATE c_cols

	RETURN @ResultVar

END
'
SET @sql = @comm_create_function
SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{function}', @function)
if OBJECT_ID(@schema + N'.' + @function) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'Function [' + @schema + N'].[' + @function + N'] has been created in the [' + DB_NAME() + N'] database.'
	END TRY
	BEGIN CATCH
		PRINT N'ERROR: ' + N'Cannot create the Function [' + @schema + N'].[' + @function + N'] in the [' + DB_NAME() + N'] database!!'
		PRINT N'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT N'WARNING: ' + N'Function [' + @schema + N'].[' + @function + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [ufnConcatFkColumnNames] FUNCTION CREATION		*************************************************************************************************

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
--				Each argument different from NULL or '''' is used as AND operator in the where clause. 
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
										WHERE	(ISNULL(@obj_schema,''0''	) in (''0'','''') or (	obj_schema	= @obj_schema	))
										AND		(ISNULL(@obj_name,	''0''	) in (''0'','''') or (	obj_name	= @obj_name		))
										AND		(ISNULL(@sql_key,	''0''	) in (''0'','''') or (	sql_key		= @sql_key		))
										AND		(ISNULL(@sql_type,	''0''	) in (''0'','''') or (	sql_type	= @sql_type		))
										AND		(ISNULL(@sql_hash,	''0''	) in (''0'','''') or (	sql_hash	= @sql_hash		))
										AND		(COALESCE(NULLIF(@obj_schema,	'''')
														, NULLIF(@obj_name,		'''')
														, NULLIF(@sql_key,		'''')
														, NULLIF(@sql_type,		'''')
														, NULLIF(@sql_hash,		'''')
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
					PRINT ''WARNING: This script was skipped due to a previous execution: '' + ''"'' + @sql + ''"'' + '' ('' + @hash + '')''
				END
			ELSE
				BEGIN
					EXEC sp_sqlexec @sql
					PRINT ''Successful execution of '' + ''"'' + @sql + ''"''
					UPDATE {schema}.{table} SET sql_status = 1, sql_status_message = ''Success'' WHERE sql_hash = @hash
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
	PRINT N'WARNING: '+ N'Stored Procedure [' + @schema + N'].[' + @procedure + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [uspExecScriptsByKeys] PROCEDURE CREATION		*************************************************************************************************

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

-- > [uspRebuildTable] PROCEDURE CREATION		*****************************************************************************************************
SET @procedure = N'uspRebuildTable'
SET @comm_create_procedure =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	MAR-2017
-- Version:		0.91.00
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
		SET @returnValue = @returnValue - 1
		DECLARE @err_num INT = ERROR_NUMBER()
		DECLARE @err_msg NVARCHAR(4000) = ERROR_MESSAGE()
		PRINT ''Something gone wrong! the insert statement raised the following error:''
		PRINT ''Error Number:'' + CONVERT( varchar(10), @err_num) + '' - ''+ @err_msg 
		IF @err_num = 2627
			PRINT ''Maybe you''''ve run this procedure in debug mode more than once without reset the environment between the first and the last execution''
			PRINT ''''
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
				SET @returnValue = @returnValue - 1
				PRINT ''SQLERROR-'' + CONVERT( varchar(10), ERROR_NUMBER()) + '': '' + ERROR_MESSAGE()
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
				SET @returnValue = @returnValue - 1
				PRINT ''SQLERROR-'' + CONVERT( varchar(10), ERROR_NUMBER()) + '': '' + ERROR_MESSAGE()
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

-- > [vForeignKeyCols] VIEW CREATION		*********************************************************************************************************
DECLARE @comm_create_view_scripts varchar(max)
SET @view = N'vForeignKeyCols'

SET @comm_create_view_scripts = 
N'
create view {schema}.{view} as
select SCHEMA_NAME(obj.schema_id) as "Schema"
,	fkcol.constraint_object_id as "Foreign Key Id", OBJECT_NAME(fkcol.constraint_object_id) as "Foreign Key Name"
,	fkcol.parent_object_id as "Child Table Id", ''[''+SCHEMA_NAME(tbl_child.schema_id)+'']''+''.''+''[''+OBJECT_NAME(fkcol.parent_object_id)+'']'' as "Child Table Name"
,	fkcol.parent_column_id as "Child Column Id", parent_cols.name as "Child Column Name"
,	fkcol.referenced_object_id as "Parent Table Id", ''[''+SCHEMA_NAME(tbl_parent.schema_id)+'']''+''.''+''[''+OBJECT_NAME(fkcol.referenced_object_id)+'']'' as "Parent Table Name"
,	fkcol.referenced_column_id as "Parent Column Id", referred_cols.name as "Parent Column Name"
from sys.foreign_key_columns fkcol
left join sys.all_columns parent_cols on (fkcol.parent_object_id = parent_cols.object_id and fkcol.parent_column_id = parent_cols.column_id)
left join sys.all_columns referred_cols on (fkcol.referenced_object_id = referred_cols.object_id and fkcol.referenced_column_id = referred_cols.column_id)
left join sys.all_columns constraint_cols on (fkcol.referenced_object_id = constraint_cols.object_id and fkcol.constraint_column_id = constraint_cols.column_id)
left join sys.all_objects obj on (fkcol.constraint_object_id = obj.object_id)
left join sys.tables tbl_child on (tbl_child.object_id = fkcol.parent_object_id)
left join sys.tables tbl_parent on (tbl_parent.object_id = fkcol.referenced_object_id)

'

SET @sql = @comm_create_view_scripts
SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{view}', @view)
if OBJECT_ID(@schema +'.'+@view) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'View [' + @schema + N'].[' + @view + N'] has been created in the [' + DB_NAME() + N'] database.'
	END TRY
	BEGIN CATCH
		PRINT N'ERROR: ' + N'Cannot create the View [' + @schema + N'].[' + @view + N'] in the [' + DB_NAME() + N'] database!!'
		PRINT N'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT N'WARNING: ' + N'View [' + @schema + N'].[' + @view + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [vForeignKeyCols] VIEW CREATION		*********************************************************************************************************


-- ##################################################################################################################################################




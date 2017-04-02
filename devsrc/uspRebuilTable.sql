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
--			@debugMode: allow only two values	> {q}true{q}, no drop performed. To use for checking if all the necessary scripts will be generated;
--												> {q}false{q}, performs all the tasks that the procedure is intended to do.
-- =============================================

CREATE PROCEDURE {schema}.{procedure}

	@database varchar(128) = NULL, -- NULL means current database
	@schema varchar(128),
	@table varchar(128),
	@DDL varchar(max),
	@debugMode bit = {q}true{q}

AS
BEGIN
	IF @debugMode = {q}true{q}
		PRINT {q}Debug mode enabled, no changes will be saved{q}

	IF COALESCE(@schema,{q}{q}) = {q}{q}
	BEGIN
		PRINT {q}Schema cannot be empty or null{q}
		RETURN -1
	END

	IF COALESCE(@table, {q}{q}) = {q}{q}
	BEGIN
		PRINT {q}Table cannot be empty or null{q}
		RETURN -1
	END
	
	DECLARE @sql varchar(max)
	DECLARE @tableToRebuild varchar(384) = COALESCE(@database, DB_NAME()) + {q}.{q} + @schema + {q}.{q} + @table	
	DECLARE @comm_create_table varchar(max) = N{q}CREATE TABLE {usp_table} ({q} + @DDL + {q}){q}
	DECLARE @returnValue int = 0
	
	-- > (1) ANALISYS AND SAVING FK{q}s DDL **********************************************************************************************************
	BEGIN TRY
	INSERT INTO [{schema}].[{table}] (obj_schema, obj_name, sql_key, sql_string, sql_type, sql_hash)
	select	mainquery.obj_schema
	,		mainquery.obj_name
	,		mainquery.sql_key
	,		mainquery.sql_string
	,		mainquery.sql_type
	,		CONVERT( varchar(50), HASHBYTES({q}SHA1{q},mainquery.sql_string), 2) as "sql_hash"
	from ( 
		-- query for create foreign keys
		SELECT	OBJECT_SCHEMA_NAME(fk.object_id) as "obj_schema"
		,		OBJECT_NAME(fk.parent_object_id) as "obj_name"
		,		OBJECT_NAME(OBJECT_ID(@tableToRebuild)) as "sql_key"
		,		{q}ALTER TABLE {q} + QUOTENAME(OBJECT_SCHEMA_NAME(fk.object_id))+{q}.{q}+ QUOTENAME(OBJECT_NAME(fk.parent_object_id))
		+		{q} ADD CONSTRAINT {q} + QUOTENAME(OBJECT_NAME(object_id))
		+		{q} FOREIGN KEY{q} 
		-- concatenation of the child{q}s (constraint) columns name (STUFF is used to remove the first comma)
		+		{q}({q} +   STUFF ((SELECT {q},{q} + QUOTENAME(col.name) FROM sys.foreign_key_columns fkcol
											JOIN sys.all_columns col on (col.column_id = fkcol.parent_column_id and col.object_id = fkcol.parent_object_id) -- child (constraint) fk columns
											WHERE constraint_object_id = fk.object_id order by fkcol.parent_column_id
											FOR XML PATH (N{q}{q}), TYPE).value({q}.{q}, {q}varchar(max){q}), 1, 1, N{q}{q}) + {q}){q}
		+		{q} REFERENCES {q} + QUOTENAME(OBJECT_SCHEMA_NAME(fk.referenced_object_id)) + {q}.{q} + QUOTENAME(OBJECT_NAME(fk.referenced_object_id))
		-- concatenation of the parent{q}s (referenced) columns name (STUFF is used to remove the first comma)
		+		{q}({q} + STUFF ((SELECT {q},{q} + QUOTENAME(col.name) FROM sys.foreign_key_columns fkcol
											JOIN sys.all_columns col on (col.column_id = fkcol.referenced_column_id and col.object_id = fkcol.referenced_object_id) -- parent (referenced) fk columns
											WHERE constraint_object_id = fk.object_id order by fkcol.parent_column_id
											FOR XML PATH (N{q}{q}), TYPE).value({q}.{q}, {q}varchar(max){q}), 1, 1, N{q}{q}) + {q}){q}
		+		CASE WHEN fk.update_referential_action_desc != {q}NO_ACTION{q} THEN {q} ON UPDATE {q} + REPLACE(fk.update_referential_action_desc, {q}_{q}, {q} {q}) ELSE {q}{q} END
		+		CASE WHEN fk.delete_referential_action_desc != {q}NO_ACTION{q} THEN {q} ON DELETE {q} + REPLACE(fk.delete_referential_action_desc, {q}_{q}, {q} {q}) ELSE {q}{q} END COLLATE database_default as "sql_string"
		,		{q}ADD_FOREIGN_KEY_CONSTRAINT{q} as "sql_type"
		FROM sys.foreign_keys fk
		WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)
		
		UNION ALL

		-- query for drop foreign keys
		SELECT	OBJECT_SCHEMA_NAME(fk.object_id) as "obj_schema"
		,		OBJECT_NAME(fk.parent_object_id) as "obj_name"
		,		OBJECT_NAME(OBJECT_ID(@tableToRebuild)) as "sql_key"
		,		{q}ALTER TABLE {q} + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + {q}.{q} + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + {q} DROP CONSTRAINT {q}+ QUOTENAME(fk.name) COLLATE database_default as "sql_string"
		,		{q}DROP_FOREIGN_KEY_CONSTRAINT{q} as sql_type 
		FROM sys.foreign_keys fk
		WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)
	) mainquery
	END TRY
	BEGIN CATCH
		DECLARE @err_num INT = ERROR_NUMBER()
		DECLARE @err_msg NVARCHAR(4000) = ERROR_MESSAGE()
		SET @returnValue = @err_num
		PRINT {q}Something gone wrong! the insert statement raised the following error:{q}
		PRINT {q}Error Number:{q} + CONVERT( varchar(10), @err_num) + {q} - {q}+ @err_msg 
		IF @err_num = 2627 -- known issue, not a real problem
		BEGIN
			PRINT {q}Maybe you{q}{q}ve run this procedure in debug mode more than once without reset the environment between the first and the last execution{q}
			PRINT {q}{q}
			SET @returnValue = 0
		END
		ELSE
			RETURN @returnValue
	END CATCH
	-- < (1) ANALISYS AND SAVING FK{q}s DDL **********************************************************************************************************

	-- > (2) DROP THE FOREIGN KEYS	*****************************************************************************************************************
	SET @sql = {q}EXEC {schema}.uspExecScriptsByKeys @sql_key={q}{q}{usp_table}{q}{q}, @sql_type={q}{q}DROP_FOREIGN_KEY_CONSTRAINT{q}{q}{q}
	SET @sql = REPLACE(@sql, {q}{usp_table}{q}, OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
	IF @debugMode = {q}false{q}
	BEGIN
		-- try/catch handled by called procedure
		EXEC sp_sqlexec @sql
	END
	ELSE
		PRINT {q}DROP FOREIGN KEYS (Debug mode enabled){q}

	-- < (2) DROP THE FOREIGN KEYS	*****************************************************************************************************************

	-- > (3) DROP TABLE		*************************************************************************************************************************
	DECLARE @comm_drop_table varchar(max) = {q}DROP TABLE {usp_table}{q}
	SET @sql = @comm_drop_table
	SET @sql = REPLACE(@sql, {q}{usp_table}{q}, @tableToRebuild)
	IF OBJECT_ID(@tableToRebuild) is not null
	BEGIN
		IF @debugMode = {q}false{q}
		BEGIN
			BEGIN TRY
				EXEC sp_sqlexec @sql
				PRINT {q}Table {q} + @tableToRebuild + {q} has been dropped successful!{q}
			END TRY
			BEGIN CATCH
				SET @returnValue = ERROR_NUMBER()
				PRINT {q}SQLERROR-{q} + CONVERT( varchar(10), ERROR_NUMBER()) + {q}: {q} + ERROR_MESSAGE()
				RETURN @returnValue
			END CATCH
		END	
		ELSE
			PRINT {q}DROP TABLE (Debug mode enabled){q}
	END
	-- < (3) DROP TABLE		*************************************************************************************************************************
	
	-- > (4) CREATE TABLE	*************************************************************************************************************************
	SET @sql = @comm_create_table
	SET @sql = REPLACE(@sql, {q}{usp_table}{q}, @tableToRebuild)
	IF OBJECT_ID(@tableToRebuild) is null
	BEGIN
		IF @debugMode = {q}false{q}
		BEGIN
			BEGIN TRY
				EXEC sp_sqlexec @sql
				PRINT {q}Table {q} + @tableToRebuild + {q} has been created successful!{q}
			END TRY
			BEGIN CATCH
				SET @returnValue = ERROR_NUMBER()
				PRINT {q}SQLERROR-{q} + CONVERT( varchar(10), ERROR_NUMBER()) + {q}: {q} + ERROR_MESSAGE()
				RETURN @returnValue
			END CATCH
		END
		ELSE
			PRINT {q}CREATE TABLE (Debug mode enabled){q}
	END
	ELSE
		PRINT {q}CREATE TABLE ignored, table already exists!{q}
	-- < (4) CREATE TABLE	*************************************************************************************************************************
	
	-- > (5) FOREIGN KEYS RESTORING		*************************************************************************************************************
	SET @sql = {q}EXEC {schema}.uspExecScriptsByKeys @sql_key={q}{q}{usp_table}{q}{q}, @sql_type={q}{q}ADD_FOREIGN_KEY_CONSTRAINT{q}{q}{q}
	SET @sql = REPLACE(@sql, {q}{usp_table}{q}, OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
	IF @debugMode = {q}false{q}
	BEGIN
		-- try/catch handled by called procedure
		EXEC sp_sqlexec @sql
	END
	ELSE
	BEGIN
		PRINT {q}RESTORE FOREIGN KEYS (Debug mode enabled){q}
		SET @sql = {q}SELECT * FROM [{schema}].[{table}]{q}
		EXEC sp_sqlexec @sql
	END
	-- < (5) FOREIGN KEYS RESTORING		*************************************************************************************************************

	DECLARE @errors int
	SELECT @errors = COUNT(*)
	FROM [{schema}].[{table}] 
	WHERE sql_status < 0 AND sql_key=OBJECT_NAME(OBJECT_ID(@tableToRebuild)) AND sql_type IN ({q}ADD_FOREIGN_KEY_CONSTRAINT{q},{q}DROP_FOREIGN_KEY_CONSTRAINT{q})

	IF @errors > 0
	BEGIN
		PRINT {q}ATTENTION: check for the table {table} (or the {q}{q}Results{q}{q} panel), some errors was raised!{q}
		SET @sql = {q}SELECT * FROM [{schema}].[{table}] WHERE sql_status < 0{q}
		EXEC sp_sqlexec @sql
	END
		
	RETURN @returnValue
-- **************************************************************************************************************************************************

END
'

SET @sql = @comm_create_procedure

if OBJECT_ID(@schema + N'.' + @procedure) is not null AND @replaceItem = 'true'
BEGIN
	SET @sql = 'DROP PROCEDURE ' + QUOTENAME(@schema)+'.'+QUOTENAME(@procedure) + '; PRINT N''Stored Procedure [{schema}].[{procedure}] has been dropped from the [{database}] database.''; EXEC sp_sqlexec N''' + @sql + ''''
	SET @sql = REPLACE(@sql, N'{q}', '''''') -- four quote because it's an exec of exec
END
ELSE
	SET @sql = REPLACE(@sql, N'{q}', '''') -- two quote

SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{procedure}', @procedure)
SET @sql = REPLACE(@sql, N'{table}', @tableSqlScripts)
SET @sql = REPLACE(@sql, N'{database}', DB_NAME())

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
-- < [uspRebuildTable] PROCEDURE CREATION		*****************************************************************************************************
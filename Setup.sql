-- ================================================================================================================================================
/*
-- Name: T-SQL Utilities
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: MAR-2017
-- Version:		0.93.00
-- Description:	
I've begun this tiny program to easily handle the DROP/CREATE TABLE procedure when one or more Foreign Keys are referencing to it. So, to accomplish this
task in a reliable way I have to add some objects like tables, functions, stored procedures etc.. in the target database. And that is what this setup script do

Add a new schema named as the variable @schema (customizable) to the <current database>.
Into this new schema the script add the these items:
- A new table named @tableSqlScripts [SqlScript], used to save the sql scripts to be executed;
- A new stored procedure named [uspExecScriptsByKeys], used to run the scripts saved in @tableSqlScripts;
- A new stored procedure named [uspDropMe], used to delete all the items beloging to this schema, and the schema itself, in order to clean your database;
- A new stored procedure named [uspReset], used to reset/truncate the table @tableSqlScripts;
- A new stored procedure named [uspRebuildTable], used to rebuild your table and at the same time take care of all the referenced foreign keys;
- A new view named vForeignKeyCols, for consulting purpose only;
*/
-- ==================================================================================================================================================

-- You can choose your preferred name (remember this choice for using the provided exec_ scripts) or use the default name
DECLARE @schema nvarchar(128) = N'JdevUtils'


-- ##################################################################################################################################################
DECLARE @version varchar(10) = '0.93.00'	-- Application Version
DECLARE @itemVersion varchar(10)			-- version of each item for PRINT purpose
DECLARE @sql nvarchar(max)					-- used to perform all items creation
DECLARE @procedure nvarchar(128)			-- variable used to name each procedure
DECLARE @view nvarchar(128)					-- variable used to name each view
DECLARE @tableSqlScripts nvarchar(50) = N'SqlScript' 
DECLARE @replaceItem bit = 'true'			-- force drop create items
DECLARE @warnCounter int -- <warning counter that affect last PRINT - TO DO!>
DECLARE @errCounter int -- <error counter that affect last PRINT - TO DO!>

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

 
-- > [@tableSqlScripts] TABLE CREATION		*********************************************************************************************************
DECLARE @comm_create_table_scripts varchar(max)

SET @itemVersion = @version
SET @comm_create_table_scripts = 
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	FEB-2017
-- Version:		'+@itemVersion+'
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
	,	sql_status_message nvarchar(500) DEFAULT {q}Not executed yet{q}
	,	Timestamp timestamp
	)
	
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_{table} PRIMARY KEY (sql_hash)

-- add description about column sql_status
EXEC sys.sp_addextendedproperty @name=N{q}MS_Description{q}, @value=N{q}0=Never Run; 1=Run Successful; -x=Error code{q} , @level0type=N{q}SCHEMA{q},@level0name=N{q}{schema}{q}, @level1type=N{q}TABLE{q},@level1name=N{q}{table}{q}, @level2type=N{q}COLUMN{q},@level2name=N{q}sql_status{q}
'

SET @sql = @comm_create_table_scripts

if OBJECT_ID(@schema +'.'+@tableSqlScripts) is not null AND @replaceItem = 'true'
BEGIN
	SET @sql = 'DROP TABLE ' + QUOTENAME(@schema)+'.'+QUOTENAME(@tableSqlScripts) + '; PRINT N''Table [{schema}].[{table}] has been dropped from the [{database}] database.''; EXEC sp_sqlexec N''' + @sql + ''''
	SET @sql = REPLACE(@sql, N'{q}', '''''') -- four quote because it's an exec of exec
END
ELSE
	SET @sql = REPLACE(@sql, N'{q}', '''') -- two quote

SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{table}', @tableSqlScripts)
SET @sql = REPLACE(@sql, N'{database}', DB_NAME())


if OBJECT_ID(@schema +'.'+@tableSqlScripts) is null OR @replaceItem = 'true'
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT N'Table [' + @schema + N'].[' + @tableSqlScripts + N'] v' + @itemVersion + ' has been created in the [' + DB_NAME() + N'] database.'
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
-- < [@tableSqlScripts] TABLE CREATION		*********************************************************************************************************
 
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

AS

BEGIN
	
	SET NOCOUNT ON
	DECLARE @schema varchar(128) = OBJECT_SCHEMA_NAME(@@PROCID)
	DECLARE @object_name varchar(128)
	DECLARE @object_type varchar(2)
	DECLARE @object_type_desc varchar(20)
	DECLARE @sql varchar(max)

	DECLARE @myarray table (id varchar(2), sqlstring varchar(100), typedesc varchar(20))
	INSERT INTO @myarray VALUES ({q}FN{q}, {q}DROP FUNCTION {schema}.{object}{q}, {q}Function{q}) 
	INSERT INTO @myarray VALUES ({q}P{q}, {q}DROP PROCEDURE {schema}.{object}{q}, {q}Stored Procedure{q})
	INSERT INTO @myarray VALUES ({q}U{q}, {q}DROP TABLE {schema}.{object}{q}, {q}Table{q})
	INSERT INTO @myarray VALUES ({q}V{q}, {q}DROP VIEW {schema}.{object}{q}, {q}View{q})

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

		SELECT @sql = sqlstring, @object_type_desc = typedesc FROM @myarray WHERE id = @object_type

		IF @sql is not null
			BEGIN
				SET @sql = REPLACE(@sql, {q}{schema}{q}, @schema)
				SET @sql = REPLACE(@sql, {q}{object}{q}, @object_name)
				EXEC sp_sqlexec @sql
				PRINT @object_type_desc + {q} {q} + QUOTENAME(@schema) +{q}.{q}+QUOTENAME(@object_name) + {q} has been dropped from {q} + QUOTENAME(DB_NAME()) + {q} database.{q}
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
			PRINT {q}SCHEMA {q} + QUOTENAME(@schema) + {q} dropped!{q}
		END
		
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
	PRINT N'WARNING: ' + N'Stored Procedure [' + @schema + N'].[' + @procedure + N'] has not been created because was already present in [' + DB_NAME() + N'] database.'
END
-- < [uspDropMe] PROCEDURE CREATION		*************************************************************************************************************

 
-- > [uspRebuildTable] PROCEDURE CREATION		*****************************************************************************************************
SET @procedure = N'uspRebuildTable'
SET @comm_create_procedure =
N'
-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last update:	MAR-2017
-- Version:		0.92.01
-- Description:	Dropping and Creation of an existing table and, at the same time, takes care of all the attached foreign keys. 
-- Goal is performed in 5 steps:
-- 1) Analisys and saving DDL of all foreign keys;
-- 2) Drop of the Foreign Keys;
-- 3) Drop of the Table;
-- 4) Creation of the Table (you must provide as parameter only the code to add the columns);
-- 5) Creation of the Foreign Keys saved before;


-- Params:	@schema: the schema of the table;
--			@table: the table to rebuild;
--			@DDL: Columns DDL (you must provide only the DDL to add the columns)
--			@debugMode: allow only two values	> {q}true{q}, no drop performed. To use for checking if all the necessary scripts will be generated;
--												> {q}false{q}, performs all the tasks that the procedure is intended to do.
-- =============================================

CREATE PROCEDURE {schema}.{procedure}

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
	DECLARE @tableToRebuild varchar(384) = DB_NAME() + {q}.{q} + @schema + {q}.{q} + @table	
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
-- < [uspReset] PROCEDURE CREATION		*************************************************************************************************************

 
-- > [vForeignKeyCols] VIEW CREATION		*********************************************************************************************************
DECLARE @comm_create_view_scripts varchar(max)
SET @view = N'vForeignKeyCols'

SET @comm_create_view_scripts = 
N'
create view {schema}.{view} as
select SCHEMA_NAME(obj.schema_id) as "Schema"
,	fkcol.constraint_object_id as "Foreign Key Id", OBJECT_NAME(fkcol.constraint_object_id) as "Foreign Key Name"
,	fkcol.parent_object_id as "Child Table Id", {q}[{q}+SCHEMA_NAME(tbl_child.schema_id)+{q}]{q}+{q}.{q}+{q}[{q}+OBJECT_NAME(fkcol.parent_object_id)+{q}]{q} as "Child Table Name"
,	fkcol.parent_column_id as "Child Column Id", parent_cols.name as "Child Column Name"
,	fkcol.referenced_object_id as "Parent Table Id", {q}[{q}+SCHEMA_NAME(tbl_parent.schema_id)+{q}]{q}+{q}.{q}+{q}[{q}+OBJECT_NAME(fkcol.referenced_object_id)+{q}]{q} as "Parent Table Name"
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

if OBJECT_ID(@schema + N'.' + @view) is not null AND @replaceItem = 'true'
BEGIN
	SET @sql = 'DROP VIEW ' + QUOTENAME(@schema)+'.'+QUOTENAME(@view) + '; PRINT N''View [{schema}].[{view}] has been dropped from the [{database}] database.''; EXEC sp_sqlexec N''' + @sql + ''''
	SET @sql = REPLACE(@sql, N'{q}', '''''') -- four quote because it's an exec of exec
END
ELSE
	SET @sql = REPLACE(@sql, N'{q}', '''') -- two quote
	
SET @sql = REPLACE(@sql, N'{schema}', @schema)
SET @sql = REPLACE(@sql, N'{view}', @view)
SET @sql = REPLACE(@sql, N'{database}', DB_NAME())

if OBJECT_ID(@schema + N'.' + @view) is null OR @replaceItem = 'true'
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

 
PRINT N''
PRINT N'Congratulations! T-SQL Utilities v'+@version+' has been installed successfully!'
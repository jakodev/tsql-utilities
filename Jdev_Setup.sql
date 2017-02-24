/*-- ================================================================================================================================================
-- Name: JAKODEV-UTILITIES
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: FEB-2017
-- Version:		0.90.00
-- Description:	
I've begun this tiny program to easily handle the DROP/CREATE TABLE procedure when one o more Foreign Keys are referencing to it. So, to handle this
intention I certainly need to add some item like tables, functions, stored procedures etc.. in the current database. And that is what this script do

Add the following items to the current database DB_NAME():
- A new schema named as the variable @schema;
- A new table named as the variable @tbl_scripts, used to save sql scripts;
- A new function named ufnConcatFkColumnNames, used to concat column names belonging to specified foreign keys;
- A new stored procedure named uspExecScriptsByKeys, used to run the scripts saved in @tbl_scripts;
- A new stored procedure named uspDropMe, used to remove all these items from the current database;
- A new view named vForeignKeyCols, for consulting purpose only;

-- ================================================================================================================================================*/

-- ##################################################################################################################################################
--						GLOBAL VARIABLES						
/* DON'T TOUCH THESE VARIABLES */											
DECLARE @schema varchar(128) = 'JakodevUtils'
DECLARE @sql varchar(max)
DECLARE @function varchar(128)
DECLARE @procedure varchar(128)
DECLARE @view varchar(128)
DECLARE @tbl_scripts varchar(50) = 'SqlScript'

DECLARE @comm_create_function varchar(max)
DECLARE @comm_create_procedure varchar(max)
-- ##################################################################################################################################################

-- > [@schema] SCHEMA CREATION		*****************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = 'CREATE  SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, '{schema}', @schema)
if SCHEMA_ID(@schema) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT 'Schema [' + @schema + '] has been created in [' + DB_NAME() + '] database.'
	END TRY
	BEGIN CATCH
		PRINT 'ERROR: ' + 'Cannot create the Schema [' + @schema + '] in [' + DB_NAME() + '] database!!'
		PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT 'WARNING: '+ 'Schema [' + @schema + '] has not been created because was already present in [' + DB_NAME() + '] database.'
END
-- < [@schema] SCHEMA CREATION		*****************************************************************************************************************

-- > [@tbl_scripts] TABLE CREATION		*************************************************************************************************************
DECLARE @comm_create_table_scripts varchar(max)

SET @comm_create_table_scripts = 
'CREATE TABLE {schema}.{table} 
	(	obj_schema varchar(128) not null
	,	obj_name varchar(128) not null
	,	sql_key varchar(128) not null
	,	sql_string varchar(1000) not null
	,	sql_type varchar(50) not null
	,	sql_hash varchar(100) not null
	,	sql_status int DEFAULT 0
	,	sql_status_message varchar(500) DEFAULT ''Not executed yet'')
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_<schema><table> PRIMARY KEY (sql_hash)

-- add description about column sql_status
EXEC sys.sp_addextendedproperty @name=N''MS_Description'', @value=N''0=Never Run; 1=Run Successful; -x=Error code'' , @level0type=N''SCHEMA'',@level0name=N''<schema>'', @level1type=N''TABLE'',@level1name=N''<table>'', @level2type=N''COLUMN'',@level2name=N''sql_status''
'

SET @sql = @comm_create_table_scripts
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{table}', @tbl_scripts)
SET @sql = REPLACE(@sql, '<schema>', REPLACE(REPLACE(@schema, '[',''), ']','')) 
SET @sql = REPLACE(@sql, '<table>', REPLACE(REPLACE(@tbl_scripts, '[',''), ']',''))
if OBJECT_ID(@schema +'.'+@tbl_scripts) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT 'Table [' + @schema + '].[' + @tbl_scripts + '] has been created in the [' + DB_NAME() + '] database.'
	END TRY
	BEGIN CATCH
		PRINT 'ERROR: ' + 'Cannot create the Table [' + @schema +'].['+@tbl_scripts + '] in the [' + DB_NAME() + '] database!!'
		PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT 'WARNING: '+ 'Table [' + @schema + '].[' + @tbl_scripts + '] has not been created because was already present in [' + DB_NAME() + '] database.'
END
-- < [@tbl_scripts] TABLE CREATION		*************************************************************************************************************

-- > [ufnConcatFkColumnNames] FUNCTION CREATION		*************************************************************************************************
SET @function = 'ufnConcatFkColumnNames'
SET @comm_create_function =
'CREATE FUNCTION {schema}.{function}
(
	/* Purpose:
	Speaking of foreign keys this function returns a concatenated list of column names
	in one case the list of constraint columns, in another the list of referenced columns
	*/
	@tableid_referenced int,	-- table referenced by the foreign key
	@tableid int,				-- could be the parent table or the child table. (beware: the child table, from the point of view of the FK in SQLSERVER, is called parent_object_id)
	@type char(1)				-- could assume two only value	''P'' = parent table (referenced_object_id in SQLSERVER)
								--								''C'' = child table (parent_object_id in SQLSERVER)

)
RETURNS nvarchar(150)

AS

BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar nvarchar(1000) = ''''
	DECLARE @Name nvarchar(50)
	DECLARE @index int = 1
	DECLARE @parent_col int		-- the constrained column (child table)
	DECLARE @referenced_col int	-- the referenced column (parent table)

	DECLARE c_cols CURSOR FOR SELECT parent_column_id, referenced_column_id FROM sys.foreign_key_columns WHERE constraint_object_id = @tableid_referenced
	
	OPEN c_cols
	FETCH NEXT FROM c_cols INTO @parent_col, @referenced_col
	WHILE (@@FETCH_STATUS = 0)

	BEGIN
		IF @index > 1
			SET @ResultVar = CONCAT(@ResultVar, '', '');

		IF @type = ''C''
			SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableid and column_id = @parent_col
		ELSE
			IF @type = ''P''
				SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableid and column_id = @referenced_col
			ELSE
				SET @Name = ''Undefined''

		SET @ResultVar = CONCAT(@ResultVar, @Name)
		SET @index = @index + 1

		FETCH NEXT FROM c_cols INTO @parent_col, @referenced_col
	
	END

	
	CLOSE c_cols
	DEALLOCATE c_cols

	RETURN @ResultVar

	
END
'
SET @sql = @comm_create_function
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{function}', @function)
if OBJECT_ID(@schema +'.'+ @function) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT 'Function [' + @schema + '].[' + @function + '] has been created in the [' + DB_NAME() + '] database.'
	END TRY
	BEGIN CATCH
		PRINT 'ERROR: ' + 'Cannot create the Function [' + @schema +'].['+@function + '] in the [' + DB_NAME() + '] database!!'
		PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT 'WARNING: '+ 'Function [' + @schema + '].[' + @function + '] has not been created because was already present in [' + DB_NAME() + '] database.'
END
-- < [ufnConcatFkColumnNames] FUNCTION CREATION		*************************************************************************************************

-- > [uspExecScriptsByKeys] PROCEDURE CREATION		*************************************************************************************************
SET @procedure = 'uspExecScriptsByKeys'
SET @comm_create_procedure =
'CREATE PROCEDURE {schema}.{procedure}
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
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
SET @sql = REPLACE(@sql, '{table}', @tbl_scripts)
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
-- < [uspExecScriptsByKeys] PROCEDURE CREATION		*************************************************************************************************

-- > [uspDropMe] PROCEDURE CREATION		*************************************************************************************************
SET @procedure = 'uspDropMe'
SET @comm_create_procedure =
'CREATE PROCEDURE {schema}.{procedure}
(
	@schema varchar(128) = ''JakodevUtils''
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
-- < [uspDropMe] PROCEDURE CREATION		*************************************************************************************************

-- > [vForeignKeyCols] VIEW CREATION		*********************************************************************************************************
DECLARE @comm_create_view_scripts varchar(max)
SET @view = 'vForeignKeyCols'

SET @comm_create_view_scripts = 
'create view {schema}.{view} as
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
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{view}', @view)
if OBJECT_ID(@schema +'.'+@view) is null
BEGIN
	BEGIN TRY
		EXEC sp_sqlexec @sql
		PRINT 'View [' + @schema + '].[' + @view + '] has been created in the [' + DB_NAME() + '] database.'
	END TRY
	BEGIN CATCH
		PRINT 'ERROR: ' + 'Cannot create the View [' + @schema + '].[' + @view + '] in the [' + DB_NAME() + '] database!!'
		PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
	END CATCH
END
ELSE
BEGIN
	PRINT 'WARNING: '+ 'View [' + @schema + '].[' + @view + '] has not been created because was already present in [' + DB_NAME() + '] database.'
END
-- < [vForeignKeyCols] VIEW CREATION		*********************************************************************************************************


-- ##################################################################################################################################################




/*-- ================================================================================================================================================
-- Name: MRWOLF-UTILITIES
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: JAN-2017
-- Version:		2.02.00
-- Description:	
Stash in ad hoc new schema called [mrwolf] some, hopefully useful, features to stop arguing with sql server. 
It comes with extra features appended
--------------------------------------------------------------------------------------------------------------------------
This first release start with an utility to drop/create a table referenced by one or more foreign key. This code
provide an automatic mechanism to save to code to rebuild that foreign after thier dropping. Of course the code rebuild
the table shuold be provided by YOU, this utility cannot read your mind ;)
-- ================================================================================================================================================*/

-- ##################################################################################################################################################
--						GLOBAL VARIABLES						
/* DON'T TOUCH THESE VARIABLES */											
DECLARE @schema varchar(10) = '[mrwolf]'
DECLARE @sql varchar(max)
DECLARE @function varchar(128) = '[fn_concat_column_names_fk]'
DECLARE @procedure varchar(128)
DECLARE @tbl_scripts varchar(50) = '[tbl_scripts]'
-- ##################################################################################################################################################

-- > [MRWOLF] SCHEMA CREATION		*****************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = 'CREATE SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, '{schema}', @schema)
if SCHEMA_ID(REPLACE(REPLACE(@schema, '[', ''), ']', '')) is null
	BEGIN
		BEGIN TRY
			EXEC sp_sqlexec @sql
			PRINT 'SCHEMA ' + @schema + ' Has been created!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END
-- < [MRWOLF] SCHEMA CREATION		*****************************************************************************************************************

-- > [fn_concat_column_names_fk] FUNCTION CREATION		*********************************************************************************************
DECLARE @comm_create_function varchar(max)

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
			PRINT 'FUNCTION ' + @schema + '.' + @function + ' Has been created!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END
-- < [fn_concat_column_names_fk] FUNCTION CREATION		*********************************************************************************************

-- > [sp_exec_scripts_by_key] PROCEDURE CREATION		*********************************************************************************************
SET @procedure = '[sp_exec_scripts_by_keys]'
SET @comm_create_function =
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

SET @sql = @comm_create_function
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
SET @sql = REPLACE(@sql, '{table}', @tbl_scripts)
if OBJECT_ID(@schema +'.'+@procedure) is null
	BEGIN
		BEGIN TRY
			EXEC sp_sqlexec @sql
			PRINT 'STORED PROCEDURE ' + @schema + '.' + @procedure + ' Has been created!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END
-- < [sp_exec_scripts_by_key] PROCEDURE CREATION		*********************************************************************************************

-- > [tbl_scripts] TABLE CREATION		*************************************************************************************************************
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
			PRINT 'TABLE ' + @schema + '.' + @tbl_scripts + ' Has been created!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END
-- < [tbl_scripts] TABLE CREATION		*************************************************************************************************************

-- ##################################################################################################################################################




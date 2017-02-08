/*-- ================================================================================================================================================
-- Name: MRWOLF-UTILITIES
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: JAN-2017
-- Version:		2.01.00
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
DECLARE @procedure varchar(128) = '[sp_exec_scripts_by_key]'
DECLARE @tbl_scripts varchar(50) = '[tbl_scripts]'
-- ##################################################################################################################################################

-- > [MRWOLF] SCHEMA CREATION		*****************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = 'CREATE SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, '{schema}', @schema)
if SCHEMA_ID(REPLACE(REPLACE(@schema, '[', ''), ']', '')) is null
	BEGIN
		EXEC sp_sqlexec @sql
		PRINT 'SCHEMA ' + @schema + ' Has been created!'
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
	@fk_parent_tableid int,	-- table referenced by the foreign key
	@tableid int,			-- could be the parent table or child table. (beware: the child table, from the point of view of FK, is called parent_object_id)
	@type nvarchar(1)		-- could assume two only value ''P'' = parent table; ''C'' = child table (parent_object_id for FK)
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

	DECLARE c_cols CURSOR FOR SELECT parent_column_id, referenced_column_id FROM sys.foreign_key_columns WHERE constraint_object_id = @fk_parent_tableid
	
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
		EXEC sp_sqlexec @sql
		PRINT 'FUNCTION ' + @schema + '.' + @function + ' Has been created!'
	END
-- < [fn_concat_column_names_fk] FUNCTION CREATION		*********************************************************************************************

-- > [sp_exec_scripts_by_key] PROCEDURE CREATION		*********************************************************************************************
SET @comm_create_function =
'CREATE PROCEDURE {schema}.{procedure}
(
	@sql_key varchar(128),
	@sql_type varchar(50)	
)
AS

DECLARE sql_script_cursor CURSOR FOR SELECT sql_string FROM [mrwolf].[tbl_scripts] WHERE sql_key = @sql_key and sql_type = @sql_type
DECLARE @sql varchar(max)

BEGIN

	OPEN sql_script_cursor
	FETCH NEXT FROM sql_script_cursor INTO @sql
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		EXEC sp_sqlexec @sql
		PRINT ''Successful execution of '' + ''"'' + @sql + ''"''
		FETCH NEXT FROM sql_script_cursor INTO @sql
	END
	CLOSE sql_script_cursor
	DEALLOCATE sql_script_cursor

END'

SET @sql = @comm_create_function
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
if OBJECT_ID(@schema +'.'+@procedure) is null
	BEGIN
		EXEC sp_sqlexec @sql
		PRINT 'STORED PROCEDURE ' + @schema + '.' + @procedure + ' Has been created!'
	END
-- < [sp_exec_scripts_by_key] PROCEDURE CREATION		*********************************************************************************************

-- > [tbl_scripts] TABLE CREATION		*************************************************************************************************************
DECLARE @comm_create_table_scripts varchar(max)

SET @comm_create_table_scripts = 
'CREATE TABLE {schema}.{table} (obj_schema varchar(128) not null, obj_name varchar(128) not null, sql_key varchar(128) not null, sql_string varchar(1000) not null, sql_type varchar(50) not null, sql_hash varchar(100) not null)
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_<schema><table> PRIMARY KEY (sql_hash)'

SET @sql = @comm_create_table_scripts
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{table}', @tbl_scripts)
SET @sql = REPLACE(@sql, '<schema>', REPLACE(REPLACE(@schema, '[',''), ']','')) 
SET @sql = REPLACE(@sql, '<table>', REPLACE(REPLACE(@tbl_scripts, '[',''), ']',''))
if OBJECT_ID(@schema +'.'+@tbl_scripts) is null
	BEGIN
		EXEC sp_sqlexec @sql
		PRINT 'TABLE ' + @schema + '.' + @tbl_scripts + ' Has been created!'
	END
-- < [tbl_scripts] TABLE CREATION		*************************************************************************************************************

-- ##################################################################################################################################################




/*-- =============================================
-- Name: MRWOLF-UTILITIES
-- Author:		Jakodev
-- Create date: JAN-2017
-- Last Update: JAN-2017
-- Description:	
Stash in ad hoc new schema called [mrwolf] some, hopefully useful, features to stop arguing with sql server. 
It comes with extra features appended
--------------------------------------------------------------------------------------------------------------------------
This first release start with an utility to drop/create a table referenced by one or more foreign key. This code
provide an automatic mechanism to save to code to rebuild that foreign after thier dropping. Of course the code rebuild
the table shuold be provided by YOU, this utility cannot read your mind ;)
-- =============================================*/

DECLARE @TableToDrop varchar(50) = '[IntroToEF6].[store].[Categories]'  -- used by FEATURE 1


-- ###########################################################################################################################################
--						GLOBAL VARIABLES						
/* DON'T TOUCH THESE VARIABLES */											
DECLARE @schema varchar(50) = '[mrwolf]'
DECLARE @sql varchar(max)
DECLARE @function varchar(50) = '[fn_concat_column_names_fk]'
DECLARE @tbl_scripts varchar(50) = '[tbl_scripts]'
-- ###########################################################################################################################################

-- [MRWOLF] SCHEMA CREATION		**************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = 'CREATE SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, '{schema}', @schema)
if SCHEMA_ID(REPLACE(REPLACE(@schema, '[', ''), ']', '')) is null
	EXEC sp_sqlexec @sql
-- [MRWOLF] SCHEMA CREATION		**************************************************************************************************************

-- [fn_concat_column_names_fk] FUNCTION CREATION		**************************************************************************************************
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
	EXEC sp_sqlexec @sql


-- [tbl_scripts] TABLE CREATION		**********************************************************************************************************
DECLARE @comm_create_table_scripts varchar(max)

SET @comm_create_table_scripts = 
'CREATE TABLE {schema}.{table} (obj_schema varchar(128) not null, obj_name varchar(128) not null, sql_string varchar(1000) not null, sql_type varchar(50) not null)
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_<schema><table> PRIMARY KEY (obj_schema, obj_name, sql_type)'

SET @sql = @comm_create_table_scripts
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{table}', @tbl_scripts)
SET @sql = REPLACE(@sql, '<schema>', REPLACE(REPLACE(@schema, '[',''), ']','')) 
SET @sql = REPLACE(@sql, '<table>', REPLACE(REPLACE(@tbl_scripts, '[',''), ']',''))
if OBJECT_ID(@schema +'.'+@tbl_scripts) is null
	EXEC sp_sqlexec @sql

-- ###########################################################################################################################################

-- :::::::::::::::::::::::::::::::::::::::::::::::::::::::::FEATURE 1:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
/*
FEATURE 1
Discover all the FK that referencing a table you want to drop, after that
performs TABLE DROP/CREATE specified in @TableToDrop variable, taking care of its referenced FK. 
Taking care means: save all the code needed to rebuild these FK after the table creation
*/
DECLARE @myfkschema varchar(50)
DECLARE @myfktable varchar(50)

SELECT @myfkschema = '['+OBJECT_SCHEMA_NAME(fk.object_id)+']' FROM sys.foreign_keys fk WHERE fk.referenced_object_id = object_id(@TableToDrop)
SELECT @myfktable = '['+OBJECT_NAME(fk.parent_object_id)+']' FROM sys.foreign_keys fk WHERE fk.referenced_object_id = object_id(@TableToDrop)

-- FK CODE BUILDING AND SAVING (Code for create the foreign keys)
-- (insert the code into the mrwolf.tbl_scripts table)
INSERT INTO [mrwolf].[tbl_scripts] (obj_schema, obj_name, sql_string, sql_type) 
SELECT '['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
,	'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
,	'ALTER TABLE ' + '['+OBJECT_SCHEMA_NAME(fk.object_id)+'].['+ OBJECT_NAME(fk.parent_object_id) + ']' 
+	' ADD CONSTRAINT ' + '[' + OBJECT_NAME(object_id) + ']'
+	' FOREIGN KEY(' +   [mrwolf].[fn_concat_column_names_fk](fk.object_id, fk.parent_object_id, 'C') + ')'
+	' REFERENCES ' + '[' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '].[' + OBJECT_NAME(fk.referenced_object_id) + ']' + ' (' + [mrwolf].[fn_concat_column_names_fk](fk.object_id, fk.referenced_object_id, 'P') + ')' 
+ CASE WHEN fk.update_referential_action_desc != 'NO_ACTION' THEN ' ON UPDATE ' + REPLACE(fk.update_referential_action_desc, '_', ' ') ELSE '' END
+ CASE WHEN fk.delete_referential_action_desc != 'NO_ACTION' THEN ' ON DELETE ' + REPLACE(fk.delete_referential_action_desc, '_', ' ') ELSE '' END
as "sql_string"
, 'FK CREATION' as "sql_type"
FROM sys.foreign_keys fk
WHERE fk.referenced_object_id = object_id(@TableToDrop)

-- FK CODE BUILDING AND SAVING (Code for DROP the foreign keys)
-- (insert the code into the mrwolf.tbl_scripts table)
INSERT INTO [mrwolf].[tbl_scripts] (obj_schema, obj_name, sql_string, sql_type) 
SELECT   '['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
,	'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
,	'ALTER TABLE ' + '[' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + ']' + '.[' + OBJECT_NAME(fk.parent_object_id) + '] DROP CONSTRAINT '+fk.name as "sql_string"
, 'FK DROP' as sql_type
FROM sys.foreign_keys fk
WHERE referenced_object_id = object_id(@TableToDrop)

/*
Following code will perform:
1) DROP FOREIGN KEYS (connected to @TableToDrop)
2) DROP TABLE (@TableToDrop)
3) CREATE TABLE: <this part shoul be edited in order to apply desidered modification>
4) RESTORE FOREIGN KEYS : If all gone well, all the fk will be restored by the script saved before, do you rememeber?
*/

/*
-- (1)
-- DROP THE FOREIGN KEYS	******************************************************************************************************************
SELECT @sql = sql_string FROM [mrwolf].[tbl_scripts] WHERE obj_schema = @myfkschema and obj_name = @myfktable and sql_type = 'FK DROP'
EXEC sp_sqlexec @sql
-- DROP THE FOREIGN KEYS	******************************************************************************************************************

-- (2)
-- DROP/CREATE TABLE	**********************************************************************************************************************
DROP TABLE [store].[Categories]

-- (3)
CREATE TABLE [store].[Categories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CategoryName] [nvarchar](50) NULL,
	[TimeStamp] [timestamp] NOT NULL,
 CONSTRAINT [PK_Categories] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
-- DROP/CREATE TABLE	**********************************************************************************************************************

-- (4)
-- CREATE THE SAVED FOREIGN KEYS	**********************************************************************************************************
SELECT @sql = sql_string FROM [mrwolf].[tbl_scripts] WHERE obj_schema = @myfkschema and obj_name = @myfktable and sql_type = 'FK CREATION'
EXEC sp_sqlexec @sql
-- CREATE THE SAVED FOREIGN KEYS	**********************************************************************************************************
*/


-- :::::::::::::::::::::::::::::::::::::::::::::::::::::::::FEATURE 1:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


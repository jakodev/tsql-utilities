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

DECLARE @TableToDrop varchar(50) = '[IntroToEF6].[store].[Categories]'


-- ###########################################################################################################################################
--						GLOBAL VARIABLES						
/* DON'T TOUCH THESE */											
DECLARE @schema varchar(50) = '[mrwolf]'
DECLARE @sql varchar(max)
DECLARE @function varchar(50) = '[get_column_names]'
DECLARE @tbl_scripts varchar(50) = '[tbl_scripts]'
-- ###########################################################################################################################################

-- [MRWOLF] SCHEMA CREATION		**************************************************************************************************************
DECLARE @comm_create_schema varchar(50) = 'CREATE SCHEMA {schema}'

SET @sql = @comm_create_schema
SET @sql = REPLACE(@sql, '{schema}', @schema)
if SCHEMA_ID(REPLACE(REPLACE(@schema, '[', ''), ']', '')) is null
	EXEC sp_sqlexec @sql

-- [get_column_names] FUNCTION CREATION		**************************************************************************************************
DECLARE @comm_create_function varchar(max)

SET @comm_create_function =
'CREATE FUNCTION {schema}.{function}
(
	@fktableid int,
	@tableid int,
	@type nvarchar(1)
)
RETURNS nvarchar(150)

AS

BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar nvarchar(1000) = ''''
	DECLARE @Name nvarchar(50)
	DECLARE @index int = 1
	DECLARE @parent_col int
	DECLARE @referenced_col int

	DECLARE c_cols CURSOR FOR SELECT parent_column_id, referenced_column_id FROM sys.foreign_key_columns WHERE constraint_object_id = @fktableid
	
	OPEN c_cols
	FETCH NEXT FROM c_cols INTO @parent_col, @referenced_col
	WHILE (@@FETCH_STATUS = 0)

	BEGIN
		IF @index > 1
			SET @ResultVar = CONCAT(@ResultVar, '', '');

		IF @type = ''P''
			SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableid and column_id = @parent_col
		ELSE
			IF @type = ''R''
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
'CREATE TABLE {schema}.{table} (obj_schema varchar(128) not null, obj_name varchar(128) not null, sql_string varchar(1000) not null, sql_type varchar(50) null)
ALTER TABLE {schema}.{table} ADD CONSTRAINT PK_<schema><table> PRIMARY KEY (obj_schema, obj_name, sql_string)'

SET @sql = @comm_create_table_scripts
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{table}', @tbl_scripts)
SET @sql = REPLACE(@sql, '<schema>', REPLACE(REPLACE(@schema, '[',''), ']','')) 
SET @sql = REPLACE(@sql, '<table>', REPLACE(REPLACE(@tbl_scripts, '[',''), ']',''))
if OBJECT_ID(@schema +'.'+@tbl_scripts) is null
	EXEC sp_sqlexec @sql

-- ###########################################################################################################################################

/*
FEATURE 1
Discover all the foreign keys that referencing a table you want to drop
*/
DECLARE @myfkschema varchar(50)
DECLARE @myfktable varchar(50)

SELECT @myfkschema = '['+OBJECT_SCHEMA_NAME(fk.object_id)+']' FROM sys.foreign_keys fk WHERE fk.referenced_object_id = object_id(@TableToDrop)
SELECT @myfktable = '['+OBJECT_NAME(fk.parent_object_id)+']' FROM sys.foreign_keys fk WHERE fk.referenced_object_id = object_id(@TableToDrop)

-- SAVING THE CODE TO REBUILD THE FOREIGN KEYS	
-- (insert the code into the mrwolf.tbl_scripts table)
INSERT INTO [mrwolf].[tbl_scripts] (obj_schema, obj_name, sql_string, sql_type) 
SELECT '['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
,	'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
,	'ALTER TABLE ' + '['+OBJECT_SCHEMA_NAME(fk.object_id)+'].['+ OBJECT_NAME(fk.parent_object_id) + ']' 
+	' ADD CONSTRAINT ' + '[' + OBJECT_NAME(object_id) + ']'
+	' FOREIGN KEY(' +   [mrwolf].[get_column_names](fk.object_id, fk.parent_object_id, 'P') + ')'
+	' REFERENCES ' + '[' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '].[' + OBJECT_NAME(fk.referenced_object_id) + ']' + ' (' + [mrwolf].[get_column_names](fk.object_id, fk.referenced_object_id, 'R') + ')' 
+ CASE WHEN fk.update_referential_action_desc != 'NO_ACTION' THEN ' ON UPDATE ' + REPLACE(fk.update_referential_action_desc, '_', ' ') ELSE '' END
+ CASE WHEN fk.delete_referential_action_desc != 'NO_ACTION' THEN ' ON DELETE ' + REPLACE(fk.delete_referential_action_desc, '_', ' ') ELSE '' END
as "sql_string"
, 'FK CREATION' as "sql_type"
FROM sys.foreign_keys fk
WHERE fk.referenced_object_id = object_id(@TableToDrop)

-- SAVING THE CODE TO DROP THE FOREIGN KEYS	
-- (insert the code into the mrwolf.tbl_scripts table)
INSERT INTO [mrwolf].[tbl_scripts] (obj_schema, obj_name, sql_string, sql_type) 
SELECT   '['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
,	'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
,	'ALTER TABLE ' + '[' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + ']' + '.[' + OBJECT_NAME(fk.parent_object_id) + '] DROP CONSTRAINT '+fk.name as "sql_string"
, 'FK DROP' as sql_type
FROM sys.foreign_keys fk
WHERE referenced_object_id = object_id(@TableToDrop)

-- RUN THE DROP CODE
SELECT @sql = sql_string FROM [mrwolf].[tbl_scripts] WHERE obj_schema = @myfkschema and obj_name = @myfktable and sql_type = 'FK DROP'
EXEC sp_sqlexec @sql

DROP TABLE [store].[Categories]

CREATE TABLE [store].[Categories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CategoryName] [nvarchar](50) NULL,
	[TimeStamp] [timestamp] NOT NULL,
	[Test] [nvarchar](10) NULL,
	[Test2] [nvarchar](10) NULL,
	[Test3] [nvarchar](10) NOT NULL,
 CONSTRAINT [PK_Categories] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

SELECT @sql = sql_string FROM [mrwolf].[tbl_scripts] WHERE obj_schema = @myfkschema and obj_name = @myfktable and sql_type = 'FK CREATION'
EXEC sp_sqlexec @sql



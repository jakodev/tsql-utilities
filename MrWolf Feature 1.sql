/*-- ================================================================================================================================================
--	Name: MRWOLF-FEATURE-1
--	MRWOLF-UTILITIES Compatibility: 2.02.00
--	Author:			Jakodev
--	Create date:	JAN-2017
--	Last Update:	JAN-2017
--	Version:		1.04.00

[+]	Description:	-----------------------------------------------------------------
	Performs TABLE DROP/CREATE taking care of their foreign key dependencies

[+]	Prerequisites:	-----------------------------------------------------------------
	Having the above mentioned version, at least, of MRWOLF-UTILITIES installed 
	into the right database (where the drop/create should be perfomed).
	---------------------------------------------------------------------------------
[+]	Customizing:
	@TableToRebuild		> insert the name of the table you want to drop/create safely
	@Debugmode			> execute the code without performs any FK/TABLE drop/create
	@comm_create_table	> You can specify here the columns and constraint for the table to rebuild. Write your code <BETWEEN_THIS_TAG>
-- ================================================================================================================================================*/
-- ##################################################################################################################################################
--						GLOBAL VARIABLES						
/* DON'T TOUCH THESE VARIABLES */											
DECLARE @sql varchar(max)
DECLARE @schema varchar(10) = '[mrwolf]'
DECLARE @procedure varchar(128) = '[sp_exec_scripts_by_keys]' 
-- ##################################################################################################################################################

-- CUSTOM DECLARATIONS ******************************************************************************************************************************
DECLARE	@TableToRebuild varchar(384) = '[IntroToEF6].[store].[Customers]'
DECLARE @Debugmode bit = 'false'
DECLARE @comm_create_table varchar(max) =
'
CREATE TABLE {table} (
	/*<BETWEEN_THIS_TAG>*/

	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmailAddress] [nvarchar](50) NOT NULL,
	[FullName] [nvarchar](50) NOT NULL,
	[Password] [nvarchar](50) NOT NULL,
	[TimeStamp] [timestamp] NOT NULL,
 CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]


	/*<BETWEEN_THIS_TAG>*/
'
-- **************************************************************************************************************************************************

-- > BUILDING SCRIPTS FOR DROP and CREATE FOREIGN KEYS **********************************************************************************************
INSERT INTO [mrwolf].[tbl_scripts] (obj_schema, obj_name, sql_key, sql_string, sql_type, sql_hash)
select	mainquery.obj_schema
,		mainquery.obj_name
,		mainquery.sql_key
,		mainquery.sql_string
,		mainquery.sql_type
,		CONVERT( varchar(50), HASHBYTES('SHA1',mainquery.sql_string), 2) as "sql_hash"
from ( 
	-- query for create foreign keys
	SELECT	'['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
	,		'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
	,		OBJECT_NAME(OBJECT_ID(@TableToRebuild)) as "sql_key"
	,		'ALTER TABLE ' + '['+OBJECT_SCHEMA_NAME(fk.object_id)+'].['+ OBJECT_NAME(fk.parent_object_id) + ']' 
	+		' ADD CONSTRAINT ' + '[' + OBJECT_NAME(object_id) + ']'
	+		' FOREIGN KEY(' +   [mrwolf].[fn_concat_column_names_fk](fk.object_id, fk.parent_object_id, 'C') + ')'
	+		' REFERENCES ' + '[' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '].[' + OBJECT_NAME(fk.referenced_object_id) + ']' + ' (' + [mrwolf].[fn_concat_column_names_fk](fk.object_id, fk.referenced_object_id, 'P') + ')' 
	+		CASE WHEN fk.update_referential_action_desc != 'NO_ACTION' THEN ' ON UPDATE ' + REPLACE(fk.update_referential_action_desc, '_', ' ') ELSE '' END
	+		CASE WHEN fk.delete_referential_action_desc != 'NO_ACTION' THEN ' ON DELETE ' + REPLACE(fk.delete_referential_action_desc, '_', ' ') ELSE '' END COLLATE database_default as "sql_string"
	,		'ADD_FOREIGN_KEY_CONSTRAINT' as "sql_type"
	FROM sys.foreign_keys fk
	WHERE fk.referenced_object_id = OBJECT_ID(@TableToRebuild) or fk.parent_object_id = OBJECT_ID(@TableToRebuild)

	UNION ALL

	-- query for drop foreign keys
	SELECT	'['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
	,		'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
	,		OBJECT_NAME(OBJECT_ID(@TableToRebuild)) as "sql_key"
	,		'ALTER TABLE ' + '[' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + ']' + '.[' + OBJECT_NAME(fk.parent_object_id) + '] DROP CONSTRAINT '+fk.name COLLATE database_default as "sql_string"
	,		'DROP_FOREIGN_KEY_CONSTRAINT' as sql_type 
	FROM sys.foreign_keys fk
	WHERE fk.referenced_object_id = OBJECT_ID(@TableToRebuild) or fk.parent_object_id = OBJECT_ID(@TableToRebuild)
) mainquery
-- < BUILDING SCRIPTS FOR DROP and CREATE FOREIGN KEYS **********************************************************************************************

/*
Following code will perform:
1) DROP FOREIGN KEYS (connected to @TableToRebuild)
2) DROP TABLE (@TableToRebuild)
3) CREATE TABLE: <this part shoul be edited in order to apply desidered modification>
4) RESTORE FOREIGN KEYS : If all gone well, all the fk will be restored by the script saved before, do you rememeber?
*/

-- > (1) DROP THE FOREIGN KEYS	*********************************************************************************************************************
SET @sql = 'EXEC {schema}.{procedure} @sql_key=''{table}'', @sql_type=''DROP_FOREIGN_KEY_CONSTRAINT'''
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
SET @sql = REPLACE(@sql, '{table}', OBJECT_NAME(OBJECT_ID(@TableToRebuild)))
IF @Debugmode = 'false'
BEGIN
	-- try/catch handled by called procedure
	EXEC sp_sqlexec @sql
END
ELSE
	PRINT 'DROP FOREIGN KEYS (Debug mode enabled)'

-- < (1) DROP THE FOREIGN KEYS	*********************************************************************************************************************

-- > (2) DROP TABLE		*****************************************************************************************************************************
DECLARE @comm_drop_table varchar(max) = 'DROP TABLE {table}'
SET @sql = @comm_drop_table
SET @sql = REPLACE(@sql, '{table}', @TableToRebuild)
IF OBJECT_ID(@TableToRebuild) is not null
BEGIN
	IF @Debugmode = 'false'
	BEGIN
		BEGIN TRY
			EXEC sp_sqlexec @sql
			PRINT 'Table ' + @TableToRebuild + ' has been dropped successful!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END	
	ELSE
	PRINT 'DROP TABLE (Debug mode enabled)'
END
-- < (2) DROP TABLE		*****************************************************************************************************************************

-- > (3) CREATE TABLE	*****************************************************************************************************************************
SET @sql = @comm_create_table
SET @sql = REPLACE(@sql, '{table}', @TableToRebuild)
IF OBJECT_ID(@TableToRebuild) is null
BEGIN
	IF @Debugmode = 'false'
	BEGIN
		BEGIN TRY
			EXEC sp_sqlexec @sql
			PRINT 'Table ' + @TableToRebuild + ' has been created successful!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END
	ELSE
	PRINT 'CREATE TABLE (Debug mode enabled)'
END
-- < (3) CREATE TABLE	*****************************************************************************************************************************

-- > (4) RESTORE THE FOREIGN KEYS		*************************************************************************************************************
SET @sql = 'EXEC {schema}.{procedure} @sql_key=''{table}'', @sql_type=''ADD_FOREIGN_KEY_CONSTRAINT'''
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
SET @sql = REPLACE(@sql, '{table}', OBJECT_NAME(OBJECT_ID(@TableToRebuild)))
IF @Debugmode = 'false'
BEGIN
	-- try/catch handled by called procedure
	EXEC sp_sqlexec @sql
END
ELSE
	BEGIN
		PRINT 'RESTORE FOREIGN KEYS (Debug mode enabled)'
		SET @sql = 'SELECT * FROM [mrwolf].[tbl_scripts]'
		EXEC sp_sqlexec @sql
	END
-- < (4) RESTORE THE FOREIGN KEYS		*************************************************************************************************************


DECLARE @errors int
SELECT @errors = COUNT(*)
FROM [mrwolf].[tbl_scripts] 
WHERE sql_status < 0 AND sql_key=OBJECT_NAME(OBJECT_ID(@TableToRebuild)) AND sql_type IN ('ADD_FOREIGN_KEY_CONSTRAINT','DROP_FOREIGN_KEY_CONSTRAINT')

IF @errors > 0
	BEGIN
		PRINT 'ATTENTION: check for the tbl_scripts (or the ''Results'' panel), some errors was raised!'
		SET @sql = 'SELECT * FROM [mrwolf].[tbl_scripts] WHERE sql_status < 0'
		EXEC sp_sqlexec @sql
	END
	



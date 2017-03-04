-- ==================================================================================================================================================
/*
--	Name: JAKODEV-TABLE-REBUILD
--	JAKODEV-UTILITIES Compatibility: 0.90.00
--	Author:			Jakodev
--	Create date:	JAN-2017
--	Last Update:	JAN-2017
--	Version:		0.90.00

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
*/
-- ==================================================================================================================================================
-- ##################################################################################################################################################
--						GLOBAL VARIABLES						
/* DON'T TOUCH THESE VARIABLES */											
DECLARE @sql varchar(max)
DECLARE @schema varchar(128) = 'JakodevUtils'
DECLARE @procedure varchar(128) = 'uspExecScriptsByKeys' 
-- ##################################################################################################################################################

-- CUSTOM DECLARATIONS ******************************************************************************************************************************
DECLARE @tableToRebuildDatabase varchar(128) = NULL -- NULL means current database
DECLARE @tableToRebuildSchema varchar(128) = 'store'
DECLARE	@tableToRebuildTable varchar(128) = 'Products'
DECLARE @tableToRebuild varchar(384) = COALESCE(@tableToRebuildDatabase, DB_NAME()) + '.' + @tableToRebuildSchema + '.' + @tableToRebuildTable

DECLARE @Debugmode bit = 'false'
DECLARE @comm_create_table varchar(max) =
'
CREATE TABLE {usp_table} (
	/*<BETWEEN_THIS_TAG>*/

	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CategoryId] [int] NULL,
	[CurrentPrice] [money] NOT NULL,
	[Description] [nvarchar](3800) NOT NULL,
	[IsFeatured] [bit] NOT NULL,
	[ModelName] [nvarchar](50) NOT NULL,
	[ModelNumber] [nvarchar](50) NOT NULL,
	[ProductImage] [nvarchar](150) NULL,
	[ProductImageThumb] [nvarchar](150) NULL,
	[TimeStamp] [timestamp] NOT NULL,
	[UnitCost] [money] NOT NULL,
	[UnitsInStock] [int] NOT NULL,
	[Pippo] [nvarchar](50) NULL,
 CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]


	/*<BETWEEN_THIS_TAG>*/
'
-- **************************************************************************************************************************************************

-- > BUILDING SCRIPTS FOR DROP and CREATE FOREIGN KEYS **********************************************************************************************
BEGIN TRY
INSERT INTO [JakodevUtils].[SqlScript] (obj_schema, obj_name, sql_key, sql_string, sql_type, sql_hash)
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
	,		OBJECT_NAME(OBJECT_ID(@tableToRebuild)) as "sql_key"
	,		'ALTER TABLE ' + '['+OBJECT_SCHEMA_NAME(fk.object_id)+'].['+ OBJECT_NAME(fk.parent_object_id) + ']' 
	+		' ADD CONSTRAINT ' + '[' + OBJECT_NAME(object_id) + ']'
	+		' FOREIGN KEY(' +   [JakodevUtils].[ufnConcatFkColumnNames](fk.object_id, fk.parent_object_id, 'C') + ')'
	+		' REFERENCES ' + '[' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '].[' + OBJECT_NAME(fk.referenced_object_id) + ']' + ' (' + [JakodevUtils].[ufnConcatFkColumnNames](fk.object_id, fk.referenced_object_id, 'P') + ')' 
	+		CASE WHEN fk.update_referential_action_desc != 'NO_ACTION' THEN ' ON UPDATE ' + REPLACE(fk.update_referential_action_desc, '_', ' ') ELSE '' END
	+		CASE WHEN fk.delete_referential_action_desc != 'NO_ACTION' THEN ' ON DELETE ' + REPLACE(fk.delete_referential_action_desc, '_', ' ') ELSE '' END COLLATE database_default as "sql_string"
	,		'ADD_FOREIGN_KEY_CONSTRAINT' as "sql_type"
	FROM sys.foreign_keys fk
	WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)

	UNION ALL

	-- query for drop foreign keys
	SELECT	'['+OBJECT_SCHEMA_NAME(fk.object_id)+']' as "obj_schema"
	,		'['+ OBJECT_NAME(fk.parent_object_id) + ']' as "obj_name"
	,		OBJECT_NAME(OBJECT_ID(@tableToRebuild)) as "sql_key"
	,		'ALTER TABLE ' + '[' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + ']' + '.[' + OBJECT_NAME(fk.parent_object_id) + '] DROP CONSTRAINT '+fk.name COLLATE database_default as "sql_string"
	,		'DROP_FOREIGN_KEY_CONSTRAINT' as sql_type 
	FROM sys.foreign_keys fk
	WHERE fk.referenced_object_id = OBJECT_ID(@tableToRebuild) or fk.parent_object_id = OBJECT_ID(@tableToRebuild)
) mainquery
END TRY
BEGIN CATCH
	DECLARE @err_num INT = ERROR_NUMBER()
	DECLARE @err_msg NVARCHAR(4000) = ERROR_MESSAGE()
	PRINT 'Something gone wrong! the insert statement raised the following error:'
	PRINT 'Error Number:' + CONVERT( varchar(10), @err_num) + ' - '+ @err_msg 
	IF @err_num = 2627
		PRINT 'Maybe you''ve run this procedure in debug mode more than once without reset the environment between the first and the last execution'
		PRINT ''
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
SET @sql = 'EXEC {schema}.{procedure} @sql_key=''{table}'', @sql_type=''DROP_FOREIGN_KEY_CONSTRAINT'''
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
SET @sql = REPLACE(@sql, '{table}', OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
IF @Debugmode = 'false'
BEGIN
	-- try/catch handled by called procedure
	EXEC sp_sqlexec @sql
END
ELSE
	PRINT 'DROP FOREIGN KEYS (Debug mode enabled)'

-- < (1) DROP THE FOREIGN KEYS	*********************************************************************************************************************

-- > (2) DROP TABLE		*****************************************************************************************************************************
DECLARE @comm_drop_table varchar(max) = 'DROP TABLE {usp_table}'
SET @sql = @comm_drop_table
SET @sql = REPLACE(@sql, '{usp_table}', @tableToRebuild)
IF OBJECT_ID(@tableToRebuild) is not null
BEGIN
	IF @Debugmode = 'false'
	BEGIN
		BEGIN TRY
			EXEC sp_sqlexec @sql
			PRINT 'Table ' + @tableToRebuild + ' has been dropped successful!'
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
SET @sql = REPLACE(@sql, '{usp_table}', @tableToRebuild)
IF OBJECT_ID(@tableToRebuild) is null
BEGIN
	IF @Debugmode = 'false'
	BEGIN
		BEGIN TRY
			EXEC sp_sqlexec @sql
			PRINT 'Table ' + @tableToRebuild + ' has been created successful!'
		END TRY
		BEGIN CATCH
			PRINT 'SQLERROR-' + CONVERT( varchar(10), ERROR_NUMBER()) + ': ' + ERROR_MESSAGE()
		END CATCH
	END
	ELSE
		PRINT 'CREATE TABLE (Debug mode enabled)'
END
ELSE
	PRINT 'CREATE TABLE ignored, table already exists!'
-- < (3) CREATE TABLE	*****************************************************************************************************************************

-- > (4) RESTORE THE FOREIGN KEYS		*************************************************************************************************************
SET @sql = 'EXEC {schema}.{procedure} @sql_key=''{table}'', @sql_type=''ADD_FOREIGN_KEY_CONSTRAINT'''
SET @sql = REPLACE(@sql, '{schema}', @schema)
SET @sql = REPLACE(@sql, '{procedure}', @procedure)
SET @sql = REPLACE(@sql, '{table}', OBJECT_NAME(OBJECT_ID(@tableToRebuild)))
IF @Debugmode = 'false'
BEGIN
	-- try/catch handled by called procedure
	EXEC sp_sqlexec @sql
END
ELSE
	BEGIN
		PRINT 'RESTORE FOREIGN KEYS (Debug mode enabled)'
		SET @sql = 'SELECT * FROM [JakodevUtils].[SqlScript]'
		EXEC sp_sqlexec @sql
	END
-- < (4) RESTORE THE FOREIGN KEYS		*************************************************************************************************************


DECLARE @errors int
SELECT @errors = COUNT(*)
FROM [JakodevUtils].[SqlScript] 
WHERE sql_status < 0 AND sql_key=OBJECT_NAME(OBJECT_ID(@tableToRebuild)) AND sql_type IN ('ADD_FOREIGN_KEY_CONSTRAINT','DROP_FOREIGN_KEY_CONSTRAINT')

IF @errors > 0
	BEGIN
		PRINT 'ATTENTION: check for the tbl_scripts (or the ''Results'' panel), some errors was raised!'
		SET @sql = 'SELECT * FROM [JakodevUtils].[SqlScript] WHERE sql_status < 0'
		EXEC sp_sqlexec @sql
	END
	



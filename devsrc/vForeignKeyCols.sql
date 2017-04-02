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

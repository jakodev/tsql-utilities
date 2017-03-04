-- =============================================
-- Author:		Jakodev
-- Create date: JAN-2017
-- Description:	
-- Returns a concatenated list of Foreign Key''s column names.
-- if @tableIdType = ''C'' returns the constraint columns (fk child columns)
-- if @tableIdType = ''P'' returns the referenced columns (fk parent columns)
-- @tableIdRef, the table referenced by the foreign key identified by its object_id
-- @tableId, object_id of parent table or child table, the value passed here must be in according with arg @tableIdType

-- Note: 
-- in SQLSERVER the child table is identified by the field parent_object_id
-- in SQLSERVER the parent table is identified by the field referenced_object_id
-- =============================================

CREATE FUNCTION {schema}.{function}
(
	@tableIdRef int,	
	@tableId int,				
	@tableIdType char(1)				
)
RETURNS nvarchar(500)

AS

BEGIN
	
	DECLARE @ResultVar nvarchar(1000) = ''''
	DECLARE @Name nvarchar(50)
	DECLARE @index int = 1
	DECLARE @parentCol int		-- the constrained column (child table)
	DECLARE @referencedCol int	-- the referenced column (parent table)

	DECLARE c_cols CURSOR FOR SELECT parent_column_id, referenced_column_id FROM sys.foreign_key_columns WHERE constraint_object_id = @tableIdRef
	
	OPEN c_cols
	FETCH NEXT FROM c_cols INTO @parentCol, @referencedCol
	WHILE (@@FETCH_STATUS = 0)

	BEGIN
		IF @index > 1
			SET @ResultVar = CONCAT(@ResultVar, '', '');

		IF @tableIdType = ''C''
			SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableId and column_id = @parentCol
		ELSE
			IF @tableIdType = ''P''
				SELECT @Name = name FROM sys.all_columns WHERE object_id = @tableId and column_id = @referencedCol
			ELSE
				SET @Name = ''Undefined''

		SET @ResultVar = CONCAT(@ResultVar, @Name)
		SET @index = @index + 1

		FETCH NEXT FROM c_cols INTO @parentCol, @referencedCol
	
	END

	CLOSE c_cols
	DEALLOCATE c_cols

	RETURN @ResultVar

END
USE [DBUtility]
GO

/****** Object:  StoredProcedure [Inventory].[sp_Pull_SQLInventory]    Script Date: 5/26/2025 2:54:28 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [central].[sp_Pull_SQLInventory]
    @LinkedServerName NVARCHAR(128),
    @RemoteDBName NVARCHAR(128) = 'DBUtility',
	@RemoteSchema NVARCHAR(128) = 'local',
	@InventoryDBName NVARCHAR(128) = 'DBUtility',
    @InventorySchema NVARCHAR(128) = 'central',
    @InstanceFilter NVARCHAR(255)  -- comma-separated list like: 'SQLNODE1, SQLNODE2'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableList TABLE (TableName NVARCHAR(128), FilterColumn NVARCHAR(128));
    
    -- Add all tables and their respective filter columns
    INSERT INTO @TableList (TableName, FilterColumn)
    VALUES
        ('tbl_DatabaseBackupDetails', 'InstanceName'),
        ('tbl_DatabaseDetails', 'InstanceName'),
        ('tbl_DiskDetails', 'ServerName'),
        ('tbl_FailedSQLJobs', 'InstanceName'),
        ('tbl_ServerOSDetails', 'ServerName'),
        ('tbl_SQLServerConfigs', 'InstanceName'),
        ('tbl_SQLSvcAccounts', 'ServerName'),
        ('tbl_SQLVersion', 'InstanceName'),
		('tbl_DatabaseFileSpace', 'InstanceName'),
        ('tbl_SysAdmins', 'InstanceName');

    DECLARE @sql NVARCHAR(MAX), @TableName NVARCHAR(128), @FilterColumn NVARCHAR(128);
    DECLARE @filter NVARCHAR(MAX) = '';

    DECLARE table_cursor CURSOR FOR
    SELECT TableName, FilterColumn FROM @TableList;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName, @FilterColumn;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = '
IF EXISTS (
    SELECT 1 FROM [' + @LinkedServerName + '].[' + @RemoteDBName + '].['+ @RemoteSchema +'].[' + @TableName + ']
    WHERE ' + @FilterColumn + ' IN (SELECT value FROM STRING_SPLIT(@InstanceFilter, '','')) 
      AND [DataUpdatedOn] BETWEEN (GETDATE() -1) AND GETDATE()
)
BEGIN
    DELETE FROM [' + @InventoryDBName + '].[' + @InventorySchema + '].[' + @TableName + '] 
    WHERE ' + @FilterColumn + ' IN (SELECT value FROM STRING_SPLIT(@InstanceFilter, '',''))

    INSERT INTO [' + @InventoryDBName + '].[' + @InventorySchema + '].[' + @TableName + ']
    SELECT * FROM [' + @LinkedServerName + '].[' + @RemoteDBName + '].['+ @RemoteSchema +'].[' + @TableName + ']
    WHERE ' + @FilterColumn + ' IN (SELECT value FROM STRING_SPLIT(@InstanceFilter, '',''))
      AND [DataUpdatedOn] BETWEEN (GETDATE() -1) AND GETDATE()
END
';
        EXEC sp_executesql @sql, N'@InstanceFilter NVARCHAR(255)', @InstanceFilter;

        FETCH NEXT FROM table_cursor INTO @TableName, @FilterColumn;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;
END
GO



/*
.SYNOPSIS
    Collects SQL Server Database metadata and inserts into a table.

.DESCRIPTION
    This script queries sys.databases and sys.database_files.
    It retrieves SQL Server Database details(name, filename, size, freespace, Owner, etc.) details
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

--Calculating Overall Database Size Separately
IF OBJECT_ID('tempdb..#dbsize') is not null
DROP TABLE #dbsize

CREATE TABLE #dbsize(
[DatabaseName] NVARCHAR(50)
,[DatabaseSize] NVARCHAR(50)
)

DECLARE @db NVARCHAR(50)
DECLARE @sql NVARCHAR(max)

DECLARE dbsize CURSOR
FOR SELECT QUOTENAME(NAME) FROM sys.databases WHERE NAME NOT IN ('master','model','msdb','tempdb') AND STATE = 0

OPEN dbsize
FETCH NEXT FROM dbsize INTO @db

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = 'USE ' + @db + ' 
	SELECT 
		QUOTENAME(DB_NAME()),
		CASE 
			WHEN SUM(A.TotalSizeMB) < 1000 THEN CONCAT(SUM(A.TotalSizeMB),'' MB'') 
			WHEN (SUM(A.TotalSizeMB) >=1000 AND SUM(A.TotalSizeMB) <1000000) THEN CONCAT(CONVERT(DECIMAL(10,2),SUM(A.TotalSizeMB)/1024.0),'' GB'')
			WHEN SUM(A.TotalSizeMB) >= 1000000 THEN  CONCAT(CONVERT(DECIMAL(10,2),SUM(A.TotalSizeMB)/1024.0/1024.0),'' TB'') 
			END AS [DatabaseSize]
			FROM
		(SELECT DB_NAME() AS DbName,
		CONVERT(DECIMAL(10,2),size/128.0) AS TotalSizeMB
		FROM sys.database_files
		) AS A 
		GROUP BY A.DBNAME'
		--PRINT @sql
		INSERT INTO #dbsize EXEC sp_executesql @sql
		FETCH NEXT FROM dbsize INTO @db
END
CLOSE dbsize
DEALLOCATE dbsize

--Fetching Database Properties


INSERT INTO [DBUtility].[local].[tbl_DatabaseDetails]([InstanceName] ,[DatabaseName] ,[Owner] ,[Size] ,[CreatedOn],[State] ,[Type] ,[RecoveryModel] ,[Collation] ,[CompatabilityLevel] ,[UserAccessType] 
			,[Encryption] ,[QueryStore] ,[CDC] ,[AutoUpdateStats] )
			SELECT CONVERT(NVARCHAR(100),SERVERPROPERTY('ServerName')) AS [InstanceName]
			,a.name as [DatabaseName]
			,b.name as [Owner]
			,c.DatabaseSize as [Size] 
			,a.create_date as [CreateOn]
			,a.state_desc as [State]
			,CASE WHEN a.is_read_only = 0 THEN 'READ_WRITE' ELSE 'READ_ONLY' END AS [Type]
			,a.recovery_model_desc as [RecoveryModel]
			,a.collation_name as [Collation]
			,a.compatibility_level as [CompatibilityLevel]
			,a.user_access_desc as [UserAccessType]
			,CASE WHEN a.is_encrypted = 0 THEN 'Disabled' ELSE 'Enabled' END AS [Encryption]
			,CASE WHEN a.is_query_store_on = 0 THEN 'Disabled' ELSE 'Enabled' END AS [QueryStore]
			,CASE WHEN a.is_cdc_enabled = 0 THEN 'Disabled' ELSE 'Enabled' END AS [CDC]
			,CASE WHEN a.is_auto_update_stats_on = 0 THEN 'Disabled' ELSE 'Enabled' END AS [AutoUpdateStats]
			from sys.databases a,
			sys.server_principals b,
			tempdb..#dbsize c
			where a.owner_sid = b.sid and a.name = c.DatabaseName

DROP TABLE #dbsize

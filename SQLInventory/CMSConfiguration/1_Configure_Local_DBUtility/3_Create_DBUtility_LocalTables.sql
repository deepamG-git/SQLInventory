/*
.SYNOPSIS
    DBUtility Tables Creation Script
.DESCRIPTION
   Creates Below tables in DBUtility database to store DBA Related and other important logging information
   [tbl_DatabaseBackupDetails] 
   [tbl_DatabaseDetails]  
   [tbl_DatabaseFileSpace]
   [tbl_DiskDetails]
   [tbl_FailedSQLJobs]
   [tbl_ServerOSDetails] 
   [tbl_SQLServerConfigs]
   [tbl_SQLSvcAccounts]
   [tbl_SQLVersion]
   [tbl_SysAdmins] 
.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

-- === User Configurable Section ===
DECLARE @DatabaseName SYSNAME = 'DBUtility';
DECLARE @SchemaName SYSNAME = 'local';

-- Ensure the database exists
IF DB_ID(@DatabaseName) IS NULL
BEGIN
    RAISERROR('Database "%s" does not exist. Please create it first.', 16, 1, @DatabaseName);
    RETURN;
END


DECLARE @sql NVARCHAR(MAX);

-- Redirect context
--SET @sql = 'USE [' + @DatabaseName + '];'
--EXEC (@sql)

SET @sql = ' USE [' + @DatabaseName + '];
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.schemas WHERE name = ''' + @SchemaName + ''')
BEGIN
	EXEC(''CREATE SCHEMA [' + @SchemaName + ']'');
    PRINT ''Schema [' + @SchemaName + '] created in [' + @DatabaseName + '].''
END'
EXEC (@sql)

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM ' + @DatabaseName + '.sys.tables a 
				join ' + @DatabaseName + '.sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_DatabaseBackupDetails'' and b.name = ''' + @SchemaName + ''')
BEGIN
    CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].tbl_DatabaseBackupDetails (
        InstanceName NVARCHAR(50) NOT NULL,
        DatabaseName NVARCHAR(50) NOT NULL,
        RecentFullBackupDate DATETIME NULL,
        RecentDiffBackupDate DATETIME NULL,
        DataUpdatedOn DATETIME NOT NULL DEFAULT GETDATE()
    );
    PRINT ''Created: tbl_DatabaseBackupDetails'';
END';
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM ' + @DatabaseName + '.sys.tables a 
				join ' + @DatabaseName + '.sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_DatabaseDetails'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_DatabaseDetails](
		[InstanceName] [nvarchar](100) NOT NULL,
		[DatabaseName] [nvarchar](50) NOT NULL,
		[Owner] [nvarchar](50) NOT NULL,
		[Size] [nvarchar](50) NOT NULL,
		[CreatedOn] [datetime] NOT NULL,
		[State] [nvarchar](50) NOT NULL,
		[Type] [nvarchar](50) NOT NULL,
		[RecoveryModel] [nvarchar](50) NOT NULL,
		[Collation] [nvarchar](50) NOT NULL,
		[CompatabilityLevel] [int] NULL,
		[UserAccessType] [nvarchar](50) NOT NULL,
		[Encryption] [nvarchar](50) NOT NULL,
		[QueryStore] [nvarchar](50) NOT NULL,
		[CDC] [nvarchar](50) NOT NULL,
		[AutoUpdateStats] [nvarchar](50) NOT NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	) 
	PRINT ''Created: tbl_DatabaseDetails''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_DatabaseFileSpace'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_DatabaseFileSpace](
		[InstanceName] [nvarchar](50) NULL,
		[DatabaseName] [nvarchar](50) NULL,
		[FileName] [nvarchar](50) NULL,
		[FileType] [nvarchar](20) NULL,
		[TotalSizeMB] [decimal](10, 2) NULL,
		[FreeSpaceMB] [decimal](10, 2) NULL,
		[PercentFreeSpace] [decimal](10, 2) NULL,
		[AutoGrowthMB] [decimal](10, 2) NULL,
		[MaxSizeMB] [nvarchar](50) NULL,
		[DataUpdatedOn] [datetime] NULL DEFAULT GETDATE()
	) 
	Print ''Created: tbl_DatabaseFileSpace''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_DiskDetails'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_DiskDetails](
		[ServerName] [nvarchar](100) NOT NULL,
		[MountPoint] [nvarchar](10) NOT NULL,
		[DiskName] [nvarchar](50) NULL,
		[TotalSpace(GB)] [nvarchar](50) NOT NULL,
		[FreeSpace(GB)] [nvarchar](50) NOT NULL,
		[PercentFree] [nvarchar](50) NOT NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	) 
	Print ''Created: tbl_DiskDetails''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_FailedSQLJobs'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_FailedSQLJobs](
		[InstanceName] [nvarchar](50) NOT NULL,
		[JobName] [nvarchar](50) NOT NULL,
		[StepID] [int] NOT NULL,
		[StepName] [nvarchar](100) NULL,
		[Status] [nvarchar](50) NOT NULL,
		[ExecutionTime] [datetime] NULL,
		[ErrorMessage] [nvarchar](max) NOT NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	)  
	Print ''Created: tbl_FailedSQLJobs''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_ServerOSDetails'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_ServerOSDetails](
		[ServerName] [nvarchar](100) NOT NULL,
		[IPAddress] [nvarchar](50) NOT NULL,
		[Domain] [nvarchar](100) NOT NULL,
		[ServerType] [nvarchar](100) NOT NULL,
		[ClusterName] [nvarchar](100) NOT NULL,
		[OperatingSystem] [nvarchar](255) NOT NULL,
		[RAM] [nvarchar](50) NOT NULL,
		[Cores] [nvarchar](255) NOT NULL,
		[Processor] [nvarchar](MAX) NOT NULL,
		[LastBootDate] [datetime] NOT NULL,
		[TimeZone] [nvarchar](255) NOT NULL,
		[OSInstallDate] [datetime] NOT NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	) 
	PRINT ''Created: tbl_ServerOSDetails''
END
'

EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_SQLServerConfigs'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_SQLServerConfigs](
		[ServerName] [nvarchar](100) NOT NULL,
		[InstanceName] [nvarchar](100) NOT NULL,
		[SQLVersion] [nvarchar](100) NOT NULL,
		[Collation] [nvarchar](50) NOT NULL,
		[MinMemory(MB)] [nvarchar](50) NOT NULL,
		[MaxMemory(MB)] [nvarchar](50) NOT NULL,
		[MaxDOP] [int] NOT NULL,
		[CostThresholdParallelism] [int] NOT NULL,
		[AdhocWorkLoad] [nvarchar](50) NOT NULL,
		[LockPageinMemory] [nvarchar](50) NOT NULL,
		[InstantFileInitialization] [nvarchar](50) NOT NULL,
		[DBMailFeature] [nvarchar](50) NOT NULL,
		[XP_CMDShell] [nvarchar](50) NOT NULL,
		[HADRStatus] [nvarchar](50) NOT NULL,
		[ServerAuthentication] [nvarchar](50) NOT NULL,
		[TempDBOptimizedForInMemoryTables] [nvarchar](10) NOT NULL,
		[InMemoryOLTPSupported] [nvarchar](10) NOT NULL,
		[FileStream] [nvarchar](10) NOT NULL,
		[MasterDataFilePath] [nvarchar](255) NOT NULL,
		[MasterDataLogPath] [nvarchar](255) NOT NULL,
		[DefaultDataPath] [nvarchar](255) NULL,
		[DefaultLogPath] [nvarchar](255) NULL,
		[DefaultBackupPath] [nvarchar](255) NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	) 
	Print ''Created: tbl_SQLServerConfigs''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_SQLSvcAccounts'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_SQLSvcAccounts](
		[ServerName] [nvarchar](100) NOT NULL,
		[ServiceName] [nvarchar](100) NOT NULL,
		[ServiceAccount] [nvarchar](100) NOT NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	) 
	Print ''Created: tbl_SQLSvcAccounts''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_SQLVersion'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_SQLVersion](
		[ServerName] [nvarchar](100) NOT NULL,
		[InstanceName] [nvarchar](100) NOT NULL,
		[InstanceType] [nvarchar](50) NOT NULL,
		[Product] [nvarchar](100) NOT NULL,
		[ProductVersion] [nvarchar](100) NOT NULL,
		[ProductLevel] [nvarchar](50) NOT NULL,
		[DataUpdatedOn] [datetime] NOT NULL DEFAULT GETDATE()
	) 
	Print ''Created: tbl_SQLVersion''
END
'
EXEC (@sql);

SET @sql = '
IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].sys.tables a 
				join [' + @DatabaseName + '].sys.schemas b  
				on a.schema_id = b.schema_id
				where a.name = ''tbl_SysAdmins'' and b.name = ''' + @SchemaName + ''')
BEGIN
	CREATE TABLE [' + @DatabaseName + '].' + '[' + @SchemaName + '].[tbl_SysAdmins](
		[InstanceName] [sysname] NOT NULL,
		[LoginName] [sysname] NOT NULL,
		[LoginType] [sysname] NOT NULL,
		[GroupName] [nvarchar](200) NULL,
		[DataUpdatedOn] [datetime] NULL DEFAULT GETDATE()
	) 
	Print ''Created: tbl_SysAdmins''
END
'
EXEC (@sql);

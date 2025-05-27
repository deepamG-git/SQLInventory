USE [msdb]
GO

/****** Object:  Job [Collect_LocalSQLInventory_Job]    Script Date: 5/26/2025 1:00:55 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 5/26/2025 1:00:55 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Collect_LocalSQLInventory_Job', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [OS_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'OS_Details', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'<#
.SYNOPSIS
    Gathers system and cluster information and stores OS details in a SQL Server table.

.DESCRIPTION
    This script collects operating system details such as hostname, domain, RAM, CPU, OS name, last boot time, and IP address.
    It also detects whether the server is part of a Windows Failover Cluster and, if applicable, captures the cluster name and availability group information.
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
#>

 # 	=== User Configurable Section ===
$instance = "SERVERNAME"
$database = "DBUtility"

$systemInfo = Get-ComputerInfo | Select-Object -Property CsDNSHostname, CsDomain, OsName, WindowsInstallDateFromRegistry, OsTotalVisibleMemorySize, CsNumberOfLogicalProcessors, CsProcessors, OsLastBootUpTime, Timezone

$machineName = $systemInfo.CsDNSHostName
$domain = $systemInfo.CsDomain
$OSName = $systemInfo.OsName
$cores = $systemInfo.CsNumberOfLogicalProcessors
$processor = $systemInfo.CsProcessors.Name
$ram = $systemInfo.OsTotalVisibleMemorySize
$OSInstallDate = $systemInfo.WindowsInstallDateFromRegistry
$OSLastBootTime = $systemInfo.OsLastBootUpTime
$timezone = $systemInfo.Timezone

$ramGB = (-join([Math]::CEILING([Math]::Round($ram / 1024 / 1024, 2)), '' GB''))

$ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }

try {
    $cluster = Get-Cluster | Select-Object -Property Name
    $clusterAGRole = Get-ClusterResource | Where-Object { $_.ResourceType -like ''SQL Server Availability Group'' } | Select-Object -Property Name
    $clusterOwnerNode = Get-ClusterGroup | Where-Object { $_.Name -eq $clusterAGRole.Name } | Select-Object -Property OwnerNode
    $serverType = "Clustered"
    $clusterName = $cluster.Name
} catch {
    $serverType = "Standalone"
    $clusterName = "N/A"
}

if ($serverType -eq "Clustered") {
    if ($machineName -eq $clusterOwnerNode.OwnerNode.Name) {
        $ipAddress = $ipConfig.IPv4Address.IPAddress[0]
    } else {
        $ipAddress = $ipConfig.IPv4Address.IPAddress
    }
} else {
    $ipAddress = $ipConfig.IPv4Address.IPAddress
}

$query2 = @"
INSERT INTO [DBUtility].[local].[tbl_ServerOSDetails](
    [ServerName],
    [IPAddress],
    [Domain],
    [ServerType],
    [ClusterName],
    [OperatingSystem],
    [RAM],
    [Cores],
    [Processor],
    [LastBootDate],
    [TimeZone],
    [OSInstallDate]
)
VALUES (
    ''$machineName'',
    ''$ipAddress'',
    ''$domain'',
    ''$serverType'',
    ''$clusterName'',
    ''$OSName'',
    ''$ramGB'',
    ''$cores'',
    ''$processor'',
    ''$OSLastBootTime'',
    ''$timezone'',
    ''$OSInstallDate''
)
"@


try {
    Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query2 -QueryTimeout 60 -ErrorAction Stop
    Write-Host "OS Details Inserted into Table"
} catch {
    Write-Host "Insertion Failed: $_"
}
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DiskDetails]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DiskDetails', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'<#
.SYNOPSIS
    Collects disk usage information and inserts it into a SQL Server table.

.DESCRIPTION
    This script queries all logical disks of type "local disk" (DriveType = 3) on the server.
    It retrieves disk name, mount point, total size, free space, and percentage free.
    The collected data is then inserted into a SQL Server table for monitoring or auditing purposes.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
#>

$diskDetails = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } |
    Select-Object -Property DeviceID, VolumeName,
        @{Label = ''TotalSpace(GB)''; Expression = { ($_.Size / 1GB).ToString(''F2'') }},
        @{Label = ''FreeSpace(GB)''; Expression = { ($_.FreeSpace / 1GB).ToString(''F2'') }},
        @{Label = ''PercentFree''; Expression = { (($_.FreeSpace / $_.Size) * 100.0).ToString(''F2'') }}

# CHANGE THE BELOW INSTANCE NAME ACCORDINGLY
$instance = "SERVERNAME"
$database = "DBUtility"
$hostname = $env:COMPUTERNAME

foreach ($disk in $diskDetails) {
    $mountPoint = $disk.DeviceID
    $diskName = $disk.VolumeName
    $totalSpace = $disk.''TotalSpace(GB)''
    $freeSpace = $disk.''FreeSpace(GB)''
    $perctFree = $disk.PercentFree

    $query2 = @"
INSERT INTO [DBUtility].[local].[tbl_DiskDetails](
    [ServerName],
    [MountPoint],
    [DiskName],
    [TotalSpace(GB)],
    [FreeSpace(GB)],
    [PercentFree]
)
VALUES (
    ''$hostname'',
    ''$mountPoint'',
    ''$diskName'',
    ''$totalSpace'',
    ''$freeSpace'',
    ''$perctFree''
)
"@

    try {
        Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query2 -QueryTimeout 60 -ErrorAction Stop
        Write-Host "Inserted disk details for $mountPoint into the database."
    } catch {
        Write-Host "Failed to insert disk details information: $_"
    }
}
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [SvcAcctDetails]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SvcAcctDetails', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'<#
.SYNOPSIS
    Collects service account details for SQL Services and inserts it into a SQL Server table.

.DESCRIPTION
    This script queries all Windows Services having name like SQL Server.
    It retrieves Servcice Name, Serive Account Name.
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
#>

$services = Get-WmiObject Win32_Service | Where-Object {$_.DisplayName -like ''SQL Server*'' } | Select-Object DisplayName, StartName

$instance = "SERVERNAME"
$database = "DBUtility"
$hostname = $env:COMPUTERNAME

foreach ($service in $services) {
    $svcName = $service.DisplayName
    $svcAccount = $service.StartName

    $query2 = "INSERT INTO [DBUtility].[local].[tbl_SQLSvcAccounts] ([ServerName], [ServiceName], [ServiceAccount]) VALUES (''$hostname'', ''$svcName'', ''$svcAccount'')"
    
    try {
        Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query2 -QueryTimeout 60 -ErrorAction Stop
        Write-Host "Inserted service information into the database."
    } catch {
        Write-Host "Failed to insert service information: _$"
        # Log error here
    }
}
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [SQLVersion_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SQLVersion_Details', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
.SYNOPSIS
    Collects SQL Server Version Details and inserts into a table.

.DESCRIPTION
    This script queries SERVERPROPERTY() 
    It retrieves SQL Server Version details
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

INSERT INTO [DBUtility].[local].[tbl_SQLVersion] (
    [ServerName],
    [InstanceName],
    [InstanceType],
    [Product],
    [ProductVersion],
    [ProductLevel]
)
SELECT  
    CONVERT(NVARCHAR, SERVERPROPERTY(''MachineName'')) AS [ServerName],
    CONVERT(NVARCHAR, SERVERPROPERTY(''ServerName'')) AS [InstanceName],
    
    -- Determine instance type
    CASE
        WHEN SERVERPROPERTY(''InstanceName'') IS NULL THEN ''Default Instance''
        ELSE ''Named Instance''
    END AS [InstanceType],

    -- Identify SQL Server product based on version
    CASE
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''16'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2022 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''15'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2019 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''14'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2017 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''13'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2016 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''12'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2014 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''11'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2012 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''10'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''50''
            THEN CONCAT(''Microsoft SQL Server 2008 R2 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        WHEN SERVERPROPERTY(''ProductMajorVersion'') = ''10'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0''
            THEN CONCAT(''Microsoft SQL Server 2008 '', CONVERT(NVARCHAR, SERVERPROPERTY(''Edition'')))
        ELSE ''SQL Not Found''
    END AS [Product],

    -- Full product version and level (e.g., CU or SP)
    CONVERT(NVARCHAR, SERVERPROPERTY(''ProductVersion'')) AS [ProductVersion],
    CONVERT(NVARCHAR, SERVERPROPERTY(''ProductLevel'')) AS [ProductLevel];
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [SQLConfigs_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SQLConfigs_Details', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
.SYNOPSIS
    Collects SQL Server configurations and inserts into a table.

.DESCRIPTION
    This script queries SERVERPROPERTY(), Internal System tables and DMV''s.
    It retrieves SQL Server Cofigurations(memory,cpu, maxdop, Feature) details
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

DECLARE @server NVARCHAR(100) = (CONVERT(NVARCHAR,SERVERPROPERTY(''MachineName'')))
DECLARE @instance NVARCHAR(100) = (CONVERT(NVARCHAR,SERVERPROPERTY(''ServerName'')))
DECLARE @sqlVersion NVARCHAR(100) = (SELECT CASE	
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''16'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2022 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''15'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2019 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''14'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2017 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''13'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2016 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''12'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2014 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''11'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2012 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''10'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''50'') THEN CONCAT(''Microsoft SQL Server 2008 R2 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									WHEN (SERVERPROPERTY(''ProductMajorVersion'')  = ''10'' AND SERVERPROPERTY(''ProductMinorVersion'') = ''0'') THEN CONCAT(''Microsoft SQL Server 2008 '',CONVERT(NVARCHAR,SERVERPROPERTY(''Edition'')))
									ELSE ''SQL Not Found''
									END AS ''Product Version'')

DECLARE @minMemoryMB NVARCHAR(50) = (CONVERT(NVARCHAR,(SELECT VALUE FROM sys.configurations WHERE NAME = ''min server memory (MB)'')))
DECLARE @maxMemoryMB NVARCHAR(50) = (CONVERT(NVARCHAR,(SELECT VALUE FROM sys.configurations WHERE NAME = ''max server memory (MB)'')))
DECLARE @dbMail NVARCHAR(50) = (SELECT CASE WHEN VALUE = 1 THEN ''Enabled'' ELSE ''Disabled'' END AS ''DB MAIL Feature'' FROM sys.configurations WHERE NAME = ''Database Mail XPs'')
DECLARE @xpCMD NVARCHAR(50) = (SELECT CASE WHEN VALUE = 1 THEN ''Enabled'' ELSE ''Disabled'' END AS ''xpcmdShell'' FROM sys.configurations WHERE NAME = ''xp_cmdshell'')
DECLARE @ctparallel INT = (CONVERT(INT,(SELECT VALUE FROM sys.configurations WHERE NAME = ''cost threshold for parallelism'')))
DECLARE @maxdop INT = (CONVERT(INT,(SELECT VALUE FROM sys.configurations WHERE NAME = ''max degree of parallelism'')))
DECLARE @adhocWork NVARCHAR(50) = (SELECT  CASE WHEN VALUE = 1 THEN ''Enabled'' ELSE ''Disabled'' END AS''Adhoc Workload'' FROM sys.configurations WHERE NAME = ''optimize for ad hoc workloads'')
DECLARE @lockPage NVARCHAR(50) = (SELECT CASE  WHEN sql_memory_model <>  2 THEN ''Disabled'' ELSE ''Enabled'' END AS ''LockPagesInMemory'' FROM sys.dm_os_sys_info )
DECLARE @ifi NVARCHAR(50) = (SELECT CASE WHEN instant_file_initialization_enabled = ''Y'' THEN ''Enabled'' ELSE ''Disabled'' END AS ''IFI'' FROM sys.dm_server_services where servicename like ''SQL Server (%'')

DECLARE @masterDataFilePath NVARCHAR(255) = (SELECT [filename] FROM SYS.sysaltfiles WHERE NAME = ''master'')
DECLARE @masterLogFilePath NVARCHAR(255) = (SELECT [filename] FROM SYS.sysaltfiles WHERE NAME = ''mastlog'')
DECLARE @defaultBkpPath NVARCHAR(255) = (CONVERT(NVARCHAR,( SERVERPROPERTY(''InstanceDefaultBackupPath''))))
DECLARE @defaultDataPath NVARCHAR(255) = (CONVERT(NVARCHAR,( SERVERPROPERTY(''InstanceDefaultDataPath''))))
DECLARE @defaultLogPath NVARCHAR(255) = (CONVERT(NVARCHAR,( SERVERPROPERTY(''InstanceDefaultLogPath''))))

DECLARE @serverCollation NVARCHAR(50) = (CONVERT(NVARCHAR,(SELECT SERVERPROPERTY(''COLLATION''))))
DECLARE @tempDBMemoryOptm NVARCHAR(10) =  (SELECT CASE WHEN SERVERPROPERTY(''IsTempDbMetadataMemoryOptimized'') = 1 THEN ''Yes'' ELSE ''No'' END AS ''TempDB Enabled for Memory Optimized Tables'' )
DECLARE @inMemoryOLTPSupport NVARCHAR(10) =  (SELECT CASE WHEN SERVERPROPERTY(''IsXTPSupported'') = 1 THEN ''Yes'' ELSE ''Yes'' END AS ''IN Memory OLTP Supported'' )
DECLARE @fileStream NVARCHAR(10) =  (SELECT CASE WHEN SERVERPROPERTY(''FilestreamConfiguredLevel'') = 1 THEN ''Enabled'' ELSE ''Disabled'' END AS ''FilestreamConfiguredLevel'' )
DECLARE @HADR NVARCHAR(50) = (SELECT CASE WHEN SERVERPROPERTY(''IsHadrEnabled'') = 1 THEN ''AlwaysOn AG Enabled'' ELSE ''AlwaysOn AG Disabled'' END AS ''HADR'')
DECLARE @authType NVARCHAR(50) = (SELECT CASE WHEN SERVERPROPERTY(''IsIntegratedSecurityOnly'') = 1 THEN ''Integrated security (Windows Authentication)'' ELSE ''Both(Windows and SQL Server Authentication)'' END AS ''Authentication Type'')


INSERT INTO [DBUtility].[local].[tbl_SQLServerConfigs]([ServerName],[InstanceName],[SQLVersion],[Collation],[MinMemory(MB)],[MaxMemory(MB)],[MaxDOP],[CostThresholdParallelism],[AdhocWorkLoad],[LockPageinMemory],
[InstantFileInitialization],[DBMailFeature] ,[XP_CMDShell],[HADRStatus] ,[ServerAuthentication],[TempDBOptimizedForInMemoryTables] ,[InMemoryOLTPSupported] ,[FileStream] ,
[MasterDataFilePath],[MasterDataLogPath],[DefaultDataPath] ,[DefaultLogPath] ,[DefaultBackupPath]) 
VALUES (@server,@instance,@sqlVersion,@serverCollation,@minMemoryMB,@maxMemoryMB,@maxdop,@ctparallel,@adhocWork,@lockPage,@ifi,@dbMail,@xpCMD,@HADR,@authType,@tempDBMemoryOptm,@inMemoryOLTPSupport,@fileStream,
@masterDataFilePath,@masterLogFilePath,@defaultDataPath,@defaultLogPath,@defaultBkpPath)
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBDetails]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBDetails', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
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
IF OBJECT_ID(''tempdb..#dbsize'') is not null
DROP TABLE #dbsize

CREATE TABLE #dbsize(
[DatabaseName] NVARCHAR(50)
,[DatabaseSize] NVARCHAR(50)
)

DECLARE @db NVARCHAR(50)
DECLARE @sql NVARCHAR(max)

DECLARE dbsize CURSOR
FOR SELECT QUOTENAME(NAME) FROM sys.databases WHERE NAME NOT IN (''master'',''model'',''msdb'',''tempdb'')

OPEN dbsize
FETCH NEXT FROM dbsize INTO @db

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = ''USE '' + @db + '' 
	SELECT 
		DB_NAME(),
		CASE 
			WHEN SUM(A.TotalSizeMB) < 1000 THEN CONCAT(SUM(A.TotalSizeMB),'''' MB'''') 
			WHEN (SUM(A.TotalSizeMB) >=1000 AND SUM(A.TotalSizeMB) <1000000) THEN CONCAT(CONVERT(DECIMAL(10,2),SUM(A.TotalSizeMB)/1024.0),'''' GB'''')
			WHEN SUM(A.TotalSizeMB) >= 1000000 THEN  CONCAT(CONVERT(DECIMAL(10,2),SUM(A.TotalSizeMB)/1024.0/1024.0),'''' TB'''') 
			END AS [DatabaseSize]
			FROM
		(SELECT DB_NAME() AS DbName,
		CONVERT(DECIMAL(10,2),size/128.0) AS TotalSizeMB
		FROM sys.database_files
		) AS A 
		GROUP BY A.DBNAME''
		--PRINT @sql
		INSERT INTO #dbsize EXEC sp_executesql @sql
		FETCH NEXT FROM dbsize INTO @db
END
CLOSE dbsize
DEALLOCATE dbsize

--Fetching Database Properties


INSERT INTO [DBUtility].[local].[tbl_DatabaseDetails]([InstanceName] ,[DatabaseName] ,[Owner] ,[Size] ,[CreatedOn],[State] ,[Type] ,[RecoveryModel] ,[Collation] ,[CompatabilityLevel] ,[UserAccessType] 
		,[Encryption] ,[QueryStore] ,[CDC] ,[AutoUpdateStats] )
			SELECT CONVERT(NVARCHAR(100),SERVERPROPERTY(''ServerName'')) AS [InstanceName]
			,a.name as [DatabaseName]
			,b.name as [Owner]
			,c.DatabaseSize as [Size] 
			,a.create_date as [CreateOn]
			,a.state_desc as [State]
			,CASE WHEN a.is_read_only = 0 THEN ''READ_WRITE'' ELSE ''READ_ONLY'' END AS [Type]
			,a.recovery_model_desc as [RecoveryModel]
			,a.collation_name as [Collation]
			,a.compatibility_level as [CompatibilityLevel]
			,a.user_access_desc as [UserAccessType]
			,CASE WHEN a.is_encrypted = 0 THEN ''Disabled'' ELSE ''Enabled'' END AS [Encryption]
			,CASE WHEN a.is_query_store_on = 0 THEN ''Disabled'' ELSE ''Enabled'' END AS [QueryStore]
			,CASE WHEN a.is_cdc_enabled = 0 THEN ''Disabled'' ELSE ''Enabled'' END AS [CDC]
			,CASE WHEN a.is_auto_update_stats_on = 0 THEN ''Disabled'' ELSE ''Enabled'' END AS [AutoUpdateStats]
			from sys.databases a,
			sys.server_principals b,
			#dbsize c
			where a.owner_sid = b.sid and a.name = c.DatabaseName
SELECT * FROM #dbsize
DROP TABLE #dbsize', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBBackup_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBBackup_Details', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
.SYNOPSIS
    Collects SQL Server Database Backupdetails and inserts into a table.

.DESCRIPTION
    This script queries msdb.dbo.backupset system table.
    It retrieves  Database backup details(backupdate, backuptype, state) details
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

/* For the databases whose backup happened and record exists in msdb*/
if OBJECT_ID(''tempdb..#db_list'') is not null
drop table #db_list
select name into #db_list from  sys.databases where name not in(''tempdb'')

--select * from #db_list

declare @fullbkpdate datetime
declare @diffbkpdate datetime
declare @db nvarchar(50)

while exists (select * from #db_list)
begin	
	set @db = (select top 1 name from #db_list order by name asc)
	--Modify as per your organization''s Database backup policy and settings.
	set @fullbkpdate = (select top 1 backup_finish_date from msdb.dbo.backupset where database_name = @db and type = ''D''  
							--and user_name = N''NT AUTHORITY\SYSTEM''
							order by backup_finish_date desc )
	set @diffbkpdate = (select top 1 backup_finish_date from msdb.dbo.backupset where database_name = @db and type = ''I''
							--and user_name = N''NT AUTHORITY\SYSTEM''
							order by backup_finish_date desc )
	insert into [DBUtility].[local].[tbl_DatabaseBackupDetails]([InstanceName],[DatabaseName],[RecentFullBackupDate] ,[RecentDiffBackupDate]) 
				values(CONVERT(NVARCHAR(100),SERVERPROPERTY(''ServerName'')), @db, @fullbkpdate, @diffbkpdate)

	delete from #db_list where name = @db
end

drop table #db_list

--select * from [DBUtility].[local].[tbl_DatabaseBackupDetails]', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBMaintenanceJob_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBMaintenanceJob_Details', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
.SYNOPSIS
    Collects SQL Server Agent Job Status details and inserts into a table.

.DESCRIPTION
    This script queries msdb.dbo.sysjobs, msdb.dbo.sysjobhistory system tables.
    It retrieves only failed jobs which has category - ''DatabaseMaintenance''
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/




INSERT INTO [DBUtility].[local].[tbl_FailedSQLJobs]([InstanceName],[JobName],[StepID] ,[StepName] ,[Status] ,[ExecutionTime] ,[ErrorMessage] )
SELECT DISTINCT 
	@@SERVERNAME
	,z.jobname
	,z.step_id
	,z.StepName
	,z.status
	,
	CONCAT( STUFF(STUFF(z.rundate,7,0,''-''),5,0,''-'')
	,'' ''
	, STUFF(STUFF(Z.runtime,5,0,'':''),3,0,'':'')
	)
	 AS [ExecutionTime]
	,z.[message]
	
FROM
	(SELECT  a.name as [jobname] ,b.step_id, b.step_name as [StepName],
						 CASE
								WHEN b.run_status = 0 THEN ''Failed''
								WHEN b.run_status = 1 THEN ''Succeeded''
								WHEN b.run_status = 3 THEN ''Cancelled''
								ELSE NULL
						 END AS [status]
						 ,CONVERT(NVARCHAR(50),b.run_date) [rundate]
						 ,case
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 6 THEN CONVERT(NVARCHAR(50),b.run_time)
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 5 THEN CONCAT(''0'',CONVERT(NVARCHAR(50),b.run_time)) 
							ELSE ''000000''
							END AS [runtime]
						,b.message
						,b.run_status
						FROM [msdb].[dbo].[sysjobs] a, msdb.dbo.sysjobhistory b
						WHERE a.job_id = b.job_id 
						and a.category_id = 3 
						and a.enabled = 1 
						and b.run_status in (0,3)  --Failed/Cancelled Steps 
						and b.step_id <> 0  --Step which failed/cancelled are included
						and b.run_date = (SELECT REPLACE((SELECT CONVERT(DATE, GETDATE())),''-'',''''))
	) Z

UNION

SELECT DISTINCT 
	@@SERVERNAME
	,z.jobname
	,z.step_id
	,z.StepName
	,z.status
	,
	CONCAT( STUFF(STUFF(z.rundate,7,0,''-''),5,0,''-'')
	,'' ''
	, STUFF(STUFF(Z.runtime,5,0,'':''),3,0,'':'')
	)
	 AS [ExecutionTime]
	,z.[message]
	
FROM
	(SELECT  a.name as [jobname] , b.step_id, b.step_name as [StepName],
						 CASE
								WHEN b.run_status = 0 THEN ''Failed''
								WHEN b.run_status = 1 THEN ''Succeeded''
								WHEN b.run_status = 3 THEN ''Cancelled''
								ELSE NULL
						 END AS [status]
						 ,CONVERT(NVARCHAR(50),b.run_date) [rundate]
						 ,case
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 6 THEN CONVERT(NVARCHAR(50),b.run_time)
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 5 THEN CONCAT(''0'',CONVERT(NVARCHAR(50),b.run_time)) 
							ELSE ''000000''
							END AS [runtime]
						,b.message
						,b.run_status
						FROM [msdb].[dbo].[sysjobs] a, msdb.dbo.sysjobhistory b
						WHERE a.job_id = b.job_id 
						and a.category_id = 3 
						and a.enabled = 1 
						and b.run_status = 1 --Completed Successfully
						and b.step_id = 0   --Fetchning only Job Outcome step
						and b.run_date = (SELECT REPLACE((SELECT CONVERT(DATE, GETDATE())),''-'',''''))
	) Z





', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBFileSpace_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBFileSpace_Details', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
.SYNOPSIS
    Collects SQL Server Database File Space details and inserts into a table.

.DESCRIPTION
    This script queries sys.databases system table.
    It retrieves Database file space details(data file size, free space, auto growth settings, etc.)
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

declare @db nvarchar(50)
declare @sql nvarchar(max)

declare dbsize cursor
for select QUOTENAME(name) from sys.databases where name not in(''master'',''model'',''msdb'',''tempdb'') and state = 0

open dbsize
fetch next from dbsize into @db

while @@FETCH_STATUS = 0
begin
	set @sql = ''use '' + @db + '' 
	SELECT CONVERT(nvarchar,SERVERPROPERTY(''''servername'''')), DB_NAME() AS DbName, name AS FileName,type_desc AS FileType,
		cast(size/128.0 as decimal(10,2)) AS TotalSizeMB,
		cast((size/128.0 - CAST(FILEPROPERTY(name, ''''SpaceUsed'''') AS INT)/128.0) as decimal(10,2)) AS FreeSpaceMB,
		cast((cast((size/128.0 - CAST(FILEPROPERTY(name, ''''SpaceUsed'''') AS INT)/128.0) as decimal(10,2))/ cast(size/128.0 as decimal(10,2))) *100 as decimal(10,2))
		as PercentFreeSpace,
		cast(growth/128.0 as decimal(10,1)) as AutoGrowthMB,
		case
			when max_size = -1 then ''''Unlimited''''
			else cast(cast(max_size/128.0 as decimal(10,2)) as varchar)
			end as [MaximumSizeMB]
		FROM sys.database_files''
		--print @sql
		insert into [DBUtility].[local].[tbl_DatabaseFileSpace]([InstanceName],[DatabaseName],[FileName],[FileType],[TotalSizeMB],[FreeSpaceMB],[PercentFreeSpace],[AutoGrowthMB],
					[MaxSizeMB]) exec sp_executesql @sql
		fetch next from dbsize into @db
end
close dbsize
deallocate dbsize


', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [SysAdminUsers_Details]    Script Date: 5/26/2025 1:00:56 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SysAdminUsers_Details', 
		@step_id=10, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
.SYNOPSIS
    Collects SQL Server sysadmin logins details and inserts into a table.

.DESCRIPTION
    This script queries Windows SysAdmin AD groups,or sys.syslogins, sys.server_principals system table.
    It retrieves server principal names having sysadmin access on SQL Server.
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

--Windows Group Members(Windows Login Details)
-- Create a temp table to hold the results
CREATE TABLE #SysadminMembers (
    account_name NVARCHAR(100),
    type NVARCHAR(50),
    privilege NVARCHAR(50),
    mapped_login_name NVARCHAR(100),
    permission_path NVARCHAR(100)
)

-- Insert the output of xp_logininfo
INSERT INTO #SysadminMembers
EXEC xp_logininfo ''DomainName\SQLDBUtilitys'',''MEMBERS''

-- If Windows Group Based Login in not implement, use below script-
/*
	insert into DBUtility.dbo.tbl_SysAdmins(InstanceName,LoginName,LoginType,AccessLevel,AccessGrantedOn)
	select convert(nvarchar(50), SERVERPROPERTY(''''servername'''')),
	a.name as [LoginName],b.type_desc as [LoginType], ''''SysAdmin'''' as [AccessLevel],a.updatedate as [AccessGrantedOn]
	from sys.syslogins a,sys.server_principals b where 
	a.sid = b.sid
	and a.sysadmin = 1 
	and a.hasaccess = 1 
	order by AccessGrantedOn desc
*/

--SQL Login and ON WINDOWS GROUP MEMBERS Details
INSERT INTO DBUtility.local.tbl_SysAdmins(InstanceName,LoginName,LoginType,GroupName)
SELECT CONVERT(nvarchar(50), SERVERPROPERTY(''servername'')),a.name,b.type_desc,''N/A''
FROM sys.syslogins a,sys.server_principals b WHERE 
a.sid = b.sid and a.sysadmin = 1 and a.hasaccess = 1 and a.loginname not like ''%NT Service%'' and a.loginname not like ''%NT AUTHORITY%'' and b.type_desc NOT LIKE ''%GROUP%''

INSERT INTO DBUtility.local.tbl_SysAdmins(InstanceName,LoginName,LoginType,GroupName)
SELECT @@SERVERNAME,account_name,''WINDOWS_LOGIN'',permission_path  FROM #SysadminMembers;



DROP TABLE  #SysadminMembers;
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20250526, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'a580e952-cfa3-4b50-8ea5-abc509d1eea5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


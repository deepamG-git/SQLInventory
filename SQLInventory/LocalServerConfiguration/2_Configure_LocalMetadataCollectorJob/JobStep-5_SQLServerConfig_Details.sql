/*
.SYNOPSIS
    Collects SQL Server configurations and inserts into a table.

.DESCRIPTION
    This script queries SERVERPROPERTY(), Internal System tables and DMV's.
    It retrieves SQL Server Cofigurations(memory,cpu, maxdop, Feature) details
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

DECLARE @server NVARCHAR(100) = (CONVERT(NVARCHAR,SERVERPROPERTY('MachineName')))
DECLARE @instance NVARCHAR(100) = (CONVERT(NVARCHAR,SERVERPROPERTY('ServerName')))
DECLARE @sqlVersion NVARCHAR(100) = (SELECT CASE	
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '16' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2022 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '15' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2019 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '14' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2017 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '13' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2016 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '12' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2014 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '11' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2012 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '10' AND SERVERPROPERTY('ProductMinorVersion') = '50') THEN CONCAT('Microsoft SQL Server 2008 R2 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									WHEN (SERVERPROPERTY('ProductMajorVersion')  = '10' AND SERVERPROPERTY('ProductMinorVersion') = '0') THEN CONCAT('Microsoft SQL Server 2008 ',CONVERT(NVARCHAR,SERVERPROPERTY('Edition')))
									ELSE 'SQL Not Found'
									END AS 'Product Version')

DECLARE @minMemoryMB NVARCHAR(50) = (CONVERT(NVARCHAR,(SELECT VALUE FROM sys.configurations WHERE NAME = 'min server memory (MB)')))
DECLARE @maxMemoryMB NVARCHAR(50) = (CONVERT(NVARCHAR,(SELECT VALUE FROM sys.configurations WHERE NAME = 'max server memory (MB)')))
DECLARE @dbMail NVARCHAR(50) = (SELECT CASE WHEN VALUE = 1 THEN 'Enabled' ELSE 'Disabled' END AS 'DB MAIL Feature' FROM sys.configurations WHERE NAME = 'Database Mail XPs')
DECLARE @xpCMD NVARCHAR(50) = (SELECT CASE WHEN VALUE = 1 THEN 'Enabled' ELSE 'Disabled' END AS 'xpcmdShell' FROM sys.configurations WHERE NAME = 'xp_cmdshell')
DECLARE @ctparallel INT = (CONVERT(INT,(SELECT VALUE FROM sys.configurations WHERE NAME = 'cost threshold for parallelism')))
DECLARE @maxdop INT = (CONVERT(INT,(SELECT VALUE FROM sys.configurations WHERE NAME = 'max degree of parallelism')))
DECLARE @adhocWork NVARCHAR(50) = (SELECT  CASE WHEN VALUE = 1 THEN 'Enabled' ELSE 'Disabled' END AS'Adhoc Workload' FROM sys.configurations WHERE NAME = 'optimize for ad hoc workloads')
DECLARE @lockPage NVARCHAR(50) = (SELECT CASE  WHEN sql_memory_model <>  2 THEN 'Disabled' ELSE 'Enabled' END AS 'LockPagesInMemory' FROM sys.dm_os_sys_info )
DECLARE @ifi NVARCHAR(50) = (SELECT CASE WHEN instant_file_initialization_enabled = 'Y' THEN 'Enabled' ELSE 'Disabled' END AS 'IFI' FROM sys.dm_server_services where servicename like 'SQL Server (%')

DECLARE @masterDataFilePath NVARCHAR(255) = (SELECT [filename] FROM SYS.sysaltfiles WHERE NAME = 'master')
DECLARE @masterLogFilePath NVARCHAR(255) = (SELECT [filename] FROM SYS.sysaltfiles WHERE NAME = 'mastlog')
DECLARE @defaultBkpPath NVARCHAR(255) = (CONVERT(NVARCHAR,( SERVERPROPERTY('InstanceDefaultBackupPath'))))
DECLARE @defaultDataPath NVARCHAR(255) = (CONVERT(NVARCHAR,( SERVERPROPERTY('InstanceDefaultDataPath'))))
DECLARE @defaultLogPath NVARCHAR(255) = (CONVERT(NVARCHAR,( SERVERPROPERTY('InstanceDefaultLogPath'))))

DECLARE @serverCollation NVARCHAR(50) = (CONVERT(NVARCHAR,(SELECT SERVERPROPERTY('COLLATION'))))
DECLARE @tempDBMemoryOptm NVARCHAR(10) =  (SELECT CASE WHEN SERVERPROPERTY('IsTempDbMetadataMemoryOptimized') = 1 THEN 'Yes' ELSE 'No' END AS 'TempDB Enabled for Memory Optimized Tables' )
DECLARE @inMemoryOLTPSupport NVARCHAR(10) =  (SELECT CASE WHEN SERVERPROPERTY('IsXTPSupported') = 1 THEN 'Yes' ELSE 'Yes' END AS 'IN Memory OLTP Supported' )
DECLARE @fileStream NVARCHAR(10) =  (SELECT CASE WHEN SERVERPROPERTY('FilestreamConfiguredLevel') = 1 THEN 'Enabled' ELSE 'Disabled' END AS 'FilestreamConfiguredLevel' )
DECLARE @HADR NVARCHAR(50) = (SELECT CASE WHEN SERVERPROPERTY('IsHadrEnabled') = 1 THEN 'AlwaysOn AG Enabled' ELSE 'AlwaysOn AG Disabled' END AS 'HADR')
DECLARE @authType NVARCHAR(50) = (SELECT CASE WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 1 THEN 'Integrated security (Windows Authentication)' ELSE 'Both(Windows and SQL Server Authentication)' END AS 'Authentication Type')


INSERT INTO [DBUtility].[local].[tbl_SQLServerConfigs]([ServerName],[InstanceName],[SQLVersion],[Collation],[MinMemory(MB)],[MaxMemory(MB)],[MaxDOP],[CostThresholdParallelism],[AdhocWorkLoad],[LockPageinMemory],
[InstantFileInitialization],[DBMailFeature] ,[XP_CMDShell],[HADRStatus] ,[ServerAuthentication],[TempDBOptimizedForInMemoryTables] ,[InMemoryOLTPSupported] ,[FileStream] ,
[MasterDataFilePath],[MasterDataLogPath],[DefaultDataPath] ,[DefaultLogPath] ,[DefaultBackupPath]) 
VALUES (@server,@instance,@sqlVersion,@serverCollation,@minMemoryMB,@maxMemoryMB,@maxdop,@ctparallel,@adhocWork,@lockPage,@ifi,@dbMail,@xpCMD,@HADR,@authType,@tempDBMemoryOptm,@inMemoryOLTPSupport,@fileStream,
@masterDataFilePath,@masterLogFilePath,@defaultDataPath,@defaultLogPath,@defaultBkpPath)

/*
.SYNOPSIS
    DBUtility Database Creation Script
.DESCRIPTION
   Creates DBUtility Database to store tools for Database Administration and other Database Server related informations
   Creates DBUtility database on default data and log folder.
   Sets REcovery Model to SIMPLE
   Sets Database Owner to SA
.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/


-- === User Configurable Section ===
DECLARE @DatabaseName SYSNAME = 'DBUtility'
DECLARE @DataFileSize NVARCHAR(50) = '1024MB'
DECLARE @DataFileGrowth NVARCHAR(50) = '500MB'
DECLARE @LogFileSize NVARCHAR(50) = '500MB'
DECLARE @LogFileGrowth NVARCHAR(50) = '500MB'
DECLARE @Owner SYSNAME = 'sa'
-- ================================

IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
    RAISERROR('Database "%s" already exists.', 11, 1, @DatabaseName)
    RETURN
END

DECLARE @DataPath NVARCHAR(MAX) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(MAX))
DECLARE @LogPath NVARCHAR(MAX) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(MAX))

DECLARE @SQL NVARCHAR(MAX) = '
CREATE DATABASE [' + @DatabaseName + '] ON PRIMARY 
(
    NAME = [' + @DatabaseName + '_Data],
    FILENAME = ''' + @DataPath + @DatabaseName + '_Data.mdf'',
    SIZE = ' + @DataFileSize + ',
    FILEGROWTH = ' + @DataFileGrowth + '
)
LOG ON 
(
    NAME = [' + @DatabaseName + '_Log],
    FILENAME = ''' + @LogPath + @DatabaseName + '_Log.ldf'',
    SIZE = ' + @LogFileSize + ',
    FILEGROWTH = ' + @LogFileGrowth + '
);

ALTER DATABASE [' + @DatabaseName + '] SET RECOVERY SIMPLE;
ALTER AUTHORIZATION ON DATABASE::[' + @DatabaseName + '] TO [' + @Owner + '];
'

EXEC sp_executesql @SQL
PRINT 'Database [' + @DatabaseName + '] created successfully.'

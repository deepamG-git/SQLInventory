/*
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
    CONVERT(NVARCHAR, SERVERPROPERTY('MachineName')) AS [ServerName],
    CONVERT(NVARCHAR, SERVERPROPERTY('ServerName')) AS [InstanceName],
    
    -- Determine instance type
    CASE
        WHEN SERVERPROPERTY('InstanceName') IS NULL THEN 'Default Instance'
        ELSE 'Named Instance'
    END AS [InstanceType],

    -- Identify SQL Server product based on version
    CASE
        WHEN SERVERPROPERTY('ProductMajorVersion') = '16' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2022 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '15' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2019 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '14' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2017 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '13' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2016 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '12' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2014 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '11' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2012 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '10' AND SERVERPROPERTY('ProductMinorVersion') = '50'
            THEN CONCAT('Microsoft SQL Server 2008 R2 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        WHEN SERVERPROPERTY('ProductMajorVersion') = '10' AND SERVERPROPERTY('ProductMinorVersion') = '0'
            THEN CONCAT('Microsoft SQL Server 2008 ', CONVERT(NVARCHAR, SERVERPROPERTY('Edition')))
        ELSE 'SQL Not Found'
    END AS [Product],

    -- Full product version and level (e.g., CU or SP)
    CONVERT(NVARCHAR, SERVERPROPERTY('ProductVersion')) AS [ProductVersion],
    CONVERT(NVARCHAR, SERVERPROPERTY('ProductLevel')) AS [ProductLevel];

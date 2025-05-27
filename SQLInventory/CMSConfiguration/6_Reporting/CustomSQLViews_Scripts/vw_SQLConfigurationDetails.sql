USE [DBUtility]
GO

/****** Object:  View [central].[vw_SQLConfigurationDetails]    Script Date: 5/26/2025 5:32:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE view [central].[vw_SQLConfigurationDetails] as
--all the Servers whose details are fetch daily 
SELECT a.ServerName,b.InstanceName as [SQLInstanceName],c.IPAddress,a.Environment,b.SQLVersion,b.Collation,b.[MinMemory(MB)],b.[MaxMemory(MB)],b.MaxDOP,
b.CostThresholdParallelism,b.AdhocWorkLoad, b.LockPageinMemory,b.InstantFileInitialization as [IFI],B.DBMailFeature,B.XP_CMDShell,B.HADRStatus,B.ServerAuthentication
,B.FileStream,B.MasterDataFilePath,B.MasterDataLogPath,B.DefaultDataPath,b.DefaultLogPath,b.DefaultBackupPath,b.DataUpdatedOn
from master.tbl_ServerList a INNER JOIN central.tbl_SQLServerConfigs b
ON a.ServerName = b.ServerName
INNER JOIN central.tbl_ServerOSDetails c
ON a.ServerName = c.ServerName
where a.Status = 1
GO


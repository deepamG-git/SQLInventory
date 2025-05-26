USE [DBUtility]
GO

/****** Object:  View [central].[vw_OSDetails]    Script Date: 5/26/2025 5:31:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [central].[vw_OSDetails] as
SELECT a.ServerName, b.IPAddress,a.Environment,a.Description,b.Domain,b.OperatingSystem,b.ServerType,b.ClusterName,b.RAM,b.Cores,b.Processor,b.LastBootDate,b.TimeZone,b.OSInstallDate
,b.DataUpdatedOn 
FROM [master].tbl_ServerList a INNER JOIN [central].tbl_ServerOSDetails b 
ON a.ServerName = b.ServerName 
WHERE a.Status = 1
GO


USE [DBUtility]
GO

/****** Object:  View [central].[vw_SQLServerDetails]    Script Date: 5/26/2025 5:33:35 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE VIEW [central].[vw_SQLServerDetails] as
SELECT a.ServerName,b.IPAddress,a.Environment,a.Description as [ServerDescription],b.Domain,c.InstanceName as [SQLInstanceName],c.InstanceType as [SQLInstanceType]
,SUBSTRING(c.Product,0,26) as [SQLVersion], SUBSTRING(c.Product,26,LEN(c.Product)) as [SQLEdition] ,c.ProductVersion as [ProductBuild],c.ProductLevel,b.ServerType,b.ClusterName,b.DataUpdatedOn
FROM
[master].tbl_ServerList a INNER JOIN [central].[tbl_ServerOSDetails] b
ON a.ServerName = b.ServerName
INNER JOIN [central].tbl_SQLVersion c 
ON a.ServerName = c.ServerName 
WHERE a.Status = 1


GO


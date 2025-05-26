USE [DBUtility]
GO

/****** Object:  View [central].[vw_SQLLicense_PerServer]    Script Date: 5/26/2025 5:32:53 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE view [central].[vw_SQLLicense_PerServer] as
select a.ServerName , c.Product as [SQLVersion],b.Cores,b.Cores/2 as [SQLLicense]
from [master].tbl_ServerList a INNER JOIN [central].tbl_ServerOSDetails b
ON  a.ServerName = b.ServerName
INNER JOIN [central].tbl_SQLVersion c
ON a.ServerName = c.ServerName 
WHERE c.Product not like '%express%' and c.Product not like '%developer%' and a.Status = 1


GO


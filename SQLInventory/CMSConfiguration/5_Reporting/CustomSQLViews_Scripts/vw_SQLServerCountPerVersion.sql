USE [DBUtility]
GO

/****** Object:  View [central].[vw_SQLServerCountPerVersion]    Script Date: 5/26/2025 5:33:08 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create view [central].[vw_SQLServerCountPerVersion] as
  select SQLVersion,SQLEdition, count(servername) as [ServerCount]
  from [central].[vw_SQLServerDetails]
  group by sqlversion,sqledition
  union
  select 'Total SQL Servers','',count(*)
  from [central].[vw_SQLServerDetails]
GO


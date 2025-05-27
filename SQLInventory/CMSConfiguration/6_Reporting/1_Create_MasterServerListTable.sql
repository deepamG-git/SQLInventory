USE [DBUtility]
GO

/****** Object:  Schema [master]    Script Date: 5/26/2025 4:01:50 PM ******/
CREATE SCHEMA [master]
GO



USE [DBUtility]
GO

/****** Object:  Table [master].[ServerList]    Script Date: 5/26/2025 4:01:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [master].[tbl_ServerList](
	[ServerID] INT IDENTITY(1,1),
	[ServerName] [sysname] NOT NULL,
	[Description] [nvarchar](max) NULL,
	[Status] [bit] NULL,
	[Environment] [nvarchar](50) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

INSERT INTO [master].[tbl_ServerList](ServerName, Description, Status,Environment)
VALUES ('SQLCMS', 'Central Management Server',1,'Prod')

INSERT INTO [master].[tbl_ServerList](ServerName, Description, Status,Environment)
VALUES ('SQLNODE1', 'LMS Production Database Server',1,'Prod')

INSERT INTO [master].[tbl_ServerList](ServerName, Description, Status,Environment)
VALUES ('SQLNODE2', 'UAT Database Server',1,'UAT')

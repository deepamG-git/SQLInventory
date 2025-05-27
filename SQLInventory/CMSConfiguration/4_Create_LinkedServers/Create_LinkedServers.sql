USE [master]
GO
EXEC master.dbo.sp_addlinkedserver @server = N'SQLNODE1', @srvproduct=N'', @provider=N'SQLOLEDB', @datasrc=N'Hostname'

GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'collation compatible', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'data access', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'dist', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'pub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'rpc', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'rpc out', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'sub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'connect timeout', @optvalue=N'0'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'collation name', @optvalue=null
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'lazy schema validation', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'query timeout', @optvalue=N'0'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'use remote collation', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SQLNODE1', @optname=N'remote proc transaction promotion', @optvalue=N'true'
GO
USE [master]
GO
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'SQLNODE1', @locallogin = NULL , @useself = N'False', @rmtuser = N'SQLInventoryUser', @rmtpassword = N'DBAUser@1234'
GO

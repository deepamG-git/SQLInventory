/*
.SYNOPSIS
    Collects SQL Server sysadmin logins details and inserts into a table.

.DESCRIPTION
    This script queries Windows SysAdmin AD groups,or sys.syslogins, sys.server_principals system table.
    It retrieves server principal names having sysadmin access on SQL Server.
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

--Windows Group Members(Windows Login Details)
-- Create a temp table to hold the results
CREATE TABLE #SysadminMembers (
    account_name NVARCHAR(100),
    type NVARCHAR(50),
    privilege NVARCHAR(50),
    mapped_login_name NVARCHAR(100),
    permission_path NVARCHAR(100)
)

-- Insert the output of xp_logininfo
INSERT INTO #SysadminMembers
EXEC xp_logininfo 'DomainName\SQLDBUtilitys','MEMBERS'

-- If Windows Group Based Login in not implement, use below script-
/*
	insert into DBUtility.local.tbl_SysAdmins(InstanceName,LoginName,LoginType,AccessLevel,AccessGrantedOn)
	select convert(nvarchar(50), SERVERPROPERTY(''servername'')),
	a.name as [LoginName],b.type_desc as [LoginType], ''SysAdmin'' as [AccessLevel],a.updatedate as [AccessGrantedOn]
	from sys.syslogins a,sys.server_principals b where 
	a.sid = b.sid
	and a.sysadmin = 1 
	and a.hasaccess = 1 
	order by AccessGrantedOn desc
*/

--SQL Login and ON WINDOWS GROUP MEMBERS Details
INSERT INTO DBUtility.local.tbl_SysAdmins(InstanceName,LoginName,LoginType,GroupName)
SELECT CONVERT(nvarchar(50), SERVERPROPERTY('servername')),a.name,b.type_desc,'N/A'
FROM sys.syslogins a,sys.server_principals b WHERE 
a.sid = b.sid and a.sysadmin = 1 and a.hasaccess = 1 and a.loginname not like '%NT Service%' and a.loginname not like '%NT AUTHORITY%' and b.type_desc NOT LIKE '%GROUP%'

INSERT INTO DBUtility.local.tbl_SysAdmins(InstanceName,LoginName,LoginType,GroupName)
SELECT @@SERVERNAME,account_name,'WINDOWS_LOGIN',permission_path  FROM #SysadminMembers;



DROP TABLE  #SysadminMembers;

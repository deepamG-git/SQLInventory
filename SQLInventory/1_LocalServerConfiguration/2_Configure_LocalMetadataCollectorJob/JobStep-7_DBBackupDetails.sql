/*
.SYNOPSIS
    Collects SQL Server Database Backupdetails and inserts into a table.

.DESCRIPTION
    This script queries msdb.dbo.backupset system table.
    It retrieves  Database backup details(backupdate, backuptype, state) details
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

/* For the databases whose backup happened and record exists in msdb*/
if OBJECT_ID('tempdb..#db_list') is not null
drop table #db_list
select name into #db_list from  sys.databases where name not in('tempdb')

--select * from #db_list

declare @fullbkpdate datetime
declare @diffbkpdate datetime
declare @db nvarchar(50)

while exists (select * from #db_list)
begin	
	set @db = (select top 1 name from #db_list order by name asc)
	--Modify as per your organization's Database backup policy and settings.
	set @fullbkpdate = (select top 1 backup_finish_date from msdb.dbo.backupset where database_name = @db and type = 'D'  
							--and user_name = N'NT AUTHORITY\SYSTEM'
							order by backup_finish_date desc )
	set @diffbkpdate = (select top 1 backup_finish_date from msdb.dbo.backupset where database_name = @db and type = 'I'
							--and user_name = N'NT AUTHORITY\SYSTEM'
							order by backup_finish_date desc )
	insert into [DBUtility].[local].[tbl_DatabaseBackupDetails]([InstanceName],[DatabaseName],[RecentFullBackupDate] ,[RecentDiffBackupDate]) 
				values(CONVERT(NVARCHAR(100),SERVERPROPERTY('ServerName')), @db, @fullbkpdate, @diffbkpdate)

	delete from #db_list where name = @db
end

drop table #db_list

--select * from [DBUtility].[local].[tbl_DatabaseBackupDetails]
/*
.SYNOPSIS
    Collects SQL Server Database File Space details and inserts into a table.

.DESCRIPTION
    This script queries sys.databases system table.
    It retrieves Database file space details(data file size, free space, auto growth settings, etc.)
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/

declare @db nvarchar(50)
declare @sql nvarchar(max)

declare dbsize cursor
for select QUOTENAME(name) from sys.databases where name not in('master','model','msdb','tempdb') and state = 0

open dbsize
fetch next from dbsize into @db

while @@FETCH_STATUS = 0
begin
	set @sql = 'use ' + @db + ' 
	SELECT CONVERT(nvarchar,SERVERPROPERTY(''servername'')), DB_NAME() AS DbName, name AS FileName,type_desc AS FileType,
		cast(size/128.0 as decimal(10,2)) AS TotalSizeMB,
		cast((size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0) as decimal(10,2)) AS FreeSpaceMB,
		cast((cast((size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0) as decimal(10,2))/ cast(size/128.0 as decimal(10,2))) *100 as decimal(10,2))
		as PercentFreeSpace,
		cast(growth/128.0 as decimal(10,1)) as AutoGrowthMB,
		case
			when max_size = -1 then ''Unlimited''
			else cast(cast(max_size/128.0 as decimal(10,2)) as varchar)
			end as [MaximumSizeMB]
		FROM sys.database_files'
		--print @sql
		insert into [DBUtility].[local].[tbl_DatabaseFileSpace]([InstanceName],[DatabaseName],[FileName],[FileType],[TotalSizeMB],[FreeSpaceMB],[PercentFreeSpace],[AutoGrowthMB],
					[MaxSizeMB]) exec sp_executesql @sql
		fetch next from dbsize into @db
end
close dbsize
deallocate dbsize



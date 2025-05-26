/*
.SYNOPSIS
    Collects SQL Server Agent Job Status details and inserts into a table.

.DESCRIPTION
    This script queries msdb.dbo.sysjobs, msdb.dbo.sysjobhistory system tables.
    It retrieves only failed jobs which has category - 'DatabaseMaintenance'
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/




INSERT INTO [DBUtility].[local].[tbl_FailedSQLJobs]([InstanceName],[JobName],[StepID] ,[StepName] ,[Status] ,[ExecutionTime] ,[ErrorMessage] )
SELECT DISTINCT 
	@@SERVERNAME
	,z.jobname
	,z.step_id
	,z.StepName
	,z.status
	,
	CONCAT( STUFF(STUFF(z.rundate,7,0,'-'),5,0,'-')
	,' '
	, STUFF(STUFF(Z.runtime,5,0,':'),3,0,':')
	)
	 AS [ExecutionTime]
	,z.[message]
	
FROM
	(SELECT  a.name as [jobname] ,b.step_id, b.step_name as [StepName],
						 CASE
								WHEN b.run_status = 0 THEN 'Failed'
								WHEN b.run_status = 1 THEN 'Succeeded'
								WHEN b.run_status = 3 THEN 'Cancelled'
								ELSE NULL
						 END AS [status]
						 ,CONVERT(NVARCHAR(50),b.run_date) [rundate]
						 ,case
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 6 THEN CONVERT(NVARCHAR(50),b.run_time)
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 5 THEN CONCAT('0',CONVERT(NVARCHAR(50),b.run_time)) 
							ELSE '000000'
							END AS [runtime]
						,b.message
						,b.run_status
						FROM [msdb].[dbo].[sysjobs] a, msdb.dbo.sysjobhistory b
						WHERE a.job_id = b.job_id 
						and a.category_id = 3 
						and a.enabled = 1 
						and b.run_status in (0,3)  --Failed/Cancelled Steps 
						and b.step_id <> 0  --Step which failed/cancelled are included
						and b.run_date = (SELECT REPLACE((SELECT CONVERT(DATE, GETDATE())),'-',''))
	) Z

UNION

SELECT DISTINCT 
	@@SERVERNAME
	,z.jobname
	,z.step_id
	,z.StepName
	,z.status
	,
	CONCAT( STUFF(STUFF(z.rundate,7,0,'-'),5,0,'-')
	,' '
	, STUFF(STUFF(Z.runtime,5,0,':'),3,0,':')
	)
	 AS [ExecutionTime]
	,z.[message]
	
FROM
	(SELECT  a.name as [jobname] , b.step_id, b.step_name as [StepName],
						 CASE
								WHEN b.run_status = 0 THEN 'Failed'
								WHEN b.run_status = 1 THEN 'Succeeded'
								WHEN b.run_status = 3 THEN 'Cancelled'
								ELSE NULL
						 END AS [status]
						 ,CONVERT(NVARCHAR(50),b.run_date) [rundate]
						 ,case
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 6 THEN CONVERT(NVARCHAR(50),b.run_time)
							WHEN LEN(CONVERT(nvarchar(50),b.run_time)) = 5 THEN CONCAT('0',CONVERT(NVARCHAR(50),b.run_time)) 
							ELSE '000000'
							END AS [runtime]
						,b.message
						,b.run_status
						FROM [msdb].[dbo].[sysjobs] a, msdb.dbo.sysjobhistory b
						WHERE a.job_id = b.job_id 
						and a.category_id = 3 
						and a.enabled = 1 
						and b.run_status = 1 --Completed Successfully
						and b.step_id = 0   --Fetchning only Job Outcome step
						and b.run_date = (SELECT REPLACE((SELECT CONVERT(DATE, GETDATE())),'-',''))
	) Z






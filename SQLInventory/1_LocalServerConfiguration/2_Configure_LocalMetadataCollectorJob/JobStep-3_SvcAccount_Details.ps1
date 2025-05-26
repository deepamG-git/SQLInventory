<#
.SYNOPSIS
    Collects service account details for SQL Services and inserts it into a SQL Server table.

.DESCRIPTION
    This script queries all Windows Services having name like SQL Server.
    It retrieves Servcice Name, Serive Account Name.
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
#>

$services = Get-WmiObject Win32_Service | Where-Object {$_.DisplayName -like 'SQL Server*' } | Select-Object DisplayName, StartName

$instance = ""
$database = "DBUtility"
$hostname = $env:COMPUTERNAME

foreach ($service in $services) {
    $svcName = $service.DisplayName
    $svcAccount = $service.StartName

    $query2 = "INSERT INTO [DBUtility].[local].[tbl_SQLSvcAccounts] ([ServerName], [ServiceName], [ServiceAccount]) VALUES ('$hostname', '$svcName', '$svcAccount')"
    
    try {
        Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query2 -QueryTimeout 60 -ErrorAction Stop
        Write-Host "Inserted service information into the database."
    } catch {
        Write-Host "Failed to insert service information: _$"
        # Log error here
    }
}

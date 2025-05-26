<#
.SYNOPSIS
    Collects disk usage information and inserts it into a SQL Server table.

.DESCRIPTION
    This script queries all logical disks of type "local disk" (DriveType = 3) on the server.
    It retrieves disk name, mount point, total size, free space, and percentage free.
    The collected data is then inserted into a SQL Server table for monitoring or auditing purposes.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
#>

$diskDetails = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } |
    Select-Object -Property DeviceID, VolumeName,
        @{Label = 'TotalSpace(GB)'; Expression = { ($_.Size / 1GB).ToString('F2') }},
        @{Label = 'FreeSpace(GB)'; Expression = { ($_.FreeSpace / 1GB).ToString('F2') }},
        @{Label = 'PercentFree'; Expression = { (($_.FreeSpace / $_.Size) * 100.0).ToString('F2') }}

# CHANGE THE BELOW INSTANCE NAME ACCORDINGLY
$instance = ""
$database = "DBUtility"
$hostname = $env:COMPUTERNAME

foreach ($disk in $diskDetails) {
    $mountPoint = $disk.DeviceID
    $diskName = $disk.VolumeName
    $totalSpace = $disk.'TotalSpace(GB)'
    $freeSpace = $disk.'FreeSpace(GB)'
    $perctFree = $disk.PercentFree

    $query2 = @"
INSERT INTO [DBUtility].[local].[tbl_DiskDetails](
    [ServerName],
    [MountPoint],
    [DiskName],
    [TotalSpace(GB)],
    [FreeSpace(GB)],
    [PercentFree]
)
VALUES (
    '$hostname',
    '$mountPoint',
    '$diskName',
    '$totalSpace',
    '$freeSpace',
    '$perctFree'
)
"@

    try {
        Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query2 -QueryTimeout 60 -ErrorAction Stop
        Write-Host "Inserted disk details for $mountPoint into the database."
    } catch {
        Write-Host "Failed to insert disk details information: $_"
    }
}

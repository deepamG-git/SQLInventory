<#
.SYNOPSIS
    Gathers system and cluster information and stores OS details in a SQL Server table.

.DESCRIPTION
    This script collects operating system details such as hostname, domain, RAM, CPU, OS name, last boot time, and IP address.
    It also detects whether the server is part of a Windows Failover Cluster and, if applicable, captures the cluster name and availability group information.
    The collected data is then inserted into a SQL Server table.

.NOTES
    Author: Deepam Ghosh
    Version: 1.0
#>

 # 	=== User Configurable Section ===
$instance = ""
$database = "DBUtility"

$systemInfo = Get-ComputerInfo | Select-Object -Property CsDNSHostname, CsDomain, OsName, WindowsInstallDateFromRegistry, OsTotalVisibleMemorySize, CsNumberOfLogicalProcessors, CsProcessors, OsLastBootUpTime, Timezone

$machineName = $systemInfo.CsDNSHostName
$domain = $systemInfo.CsDomain
$OSName = $systemInfo.OsName
$cores = $systemInfo.CsNumberOfLogicalProcessors
$processor = $systemInfo.CsProcessors.Name
$ram = $systemInfo.OsTotalVisibleMemorySize
$OSInstallDate = $systemInfo.WindowsInstallDateFromRegistry
$OSLastBootTime = $systemInfo.OsLastBootUpTime
$timezone = $systemInfo.Timezone

$ramGB = (-join([Math]::CEILING([Math]::Round($ram / 1024 / 1024, 2)), ' GB'))

$ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }

try {
    $cluster = Get-Cluster | Select-Object -Property Name
    $clusterAGRole = Get-ClusterResource | Where-Object { $_.ResourceType -like 'SQL Server Availability Group' } | Select-Object -Property Name
    $clusterOwnerNode = Get-ClusterGroup | Where-Object { $_.Name -eq $clusterAGRole.Name } | Select-Object -Property OwnerNode
    $serverType = "Clustered"
    $clusterName = $cluster.Name
} catch {
    $serverType = "Standalone"
    $clusterName = "N/A"
}

if ($serverType -eq "Clustered") {
    if ($machineName -eq $clusterOwnerNode.OwnerNode.Name) {
        $ipAddress = $ipConfig.IPv4Address.IPAddress[0]
    } else {
        $ipAddress = $ipConfig.IPv4Address.IPAddress
    }
} else {
    $ipAddress = $ipConfig.IPv4Address.IPAddress
}

$query2 = @"
INSERT INTO [DBUtility].[local].[tbl_ServerOSDetails](
    [ServerName],
    [IPAddress],
    [Domain],
    [ServerType],
    [ClusterName],
    [OperatingSystem],
    [RAM],
    [Cores],
    [Processor],
    [LastBootDate],
    [TimeZone],
    [OSInstallDate]
)
VALUES (
    '$machineName',
    '$ipAddress',
    '$domain',
    '$serverType',
    '$clusterName',
    '$OSName',
    '$ramGB',
    '$cores',
    '$processor',
    '$OSLastBootTime',
    '$timezone',
    '$OSInstallDate'
)
"@


try {
    Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query2 -QueryTimeout 60 -ErrorAction Stop
    Write-Host "OS Details Inserted into Table"
} catch {
    Write-Host "Insertion Failed: $_"
}

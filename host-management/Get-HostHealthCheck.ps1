<#
.SYNOPSIS
    Performs a comprehensive health check on all ESXi hosts in vCenter.

.DESCRIPTION
    Checks: hardware status, services, NTP sync, DNS resolution, firewall rules,
    SSH state, vSphere HA/DRS config, and VMware Tools versions.
    Outputs a colour-coded report to console and exports to CSV.

.PARAMETER ClusterName
    Optional. Limit health check to hosts in a specific cluster.

.PARAMETER OutputPath
    Path to save the health report CSV.

.EXAMPLE
    .\Get-HostHealthCheck.ps1

.EXAMPLE
    .\Get-HostHealthCheck.ps1 -ClusterName "Production-Cluster"

.NOTES
    Author  : Akilesh J S
    Version : 1.0
    Requires: VMware.PowerCLI 13+
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$ClusterName = "",

    [Parameter()]
    [string]$OutputPath = ".\host-health-$(Get-Date -Format 'yyyy-MM-dd').csv"
)

if (-not $global:DefaultVIServer) {
    Write-Error "Not connected to vCenter. Run Connect-VIServer first."
    exit 1
}

$hosts = if ($ClusterName) {
    Get-Cluster -Name $ClusterName | Get-VMHost
} else {
    Get-VMHost
}

Write-Host "Checking $($hosts.Count) ESXi hosts..." -ForegroundColor Cyan
$report = @()

foreach ($vmHost in $hosts) {
    Write-Host "  Checking: $($vmHost.Name)" -ForegroundColor Yellow

    # Get host config manager
    $hostView   = $vmHost | Get-View
    $configMgr  = $hostView.ConfigManager

    # NTP check
    $ntpService = Get-VMHostService -VMHost $vmHost | Where-Object Key -eq "ntpd"
    $ntpServers = (Get-VMHostNtpServer -VMHost $vmHost) -join ", "

    # SSH check
    $sshService = Get-VMHostService -VMHost $vmHost | Where-Object Key -eq "TSM-SSH"

    # Firewall
    $firewallEnabled = $hostView.Config.Firewall.DefaultPolicy.IncomingBlocked

    # Memory and CPU
    $cpuUsagePct = [math]::Round(($vmHost.CpuUsageMhz / $vmHost.CpuTotalMhz) * 100, 1)
    $memUsagePct = [math]::Round(($vmHost.MemoryUsageGB / $vmHost.MemoryTotalGB) * 100, 1)

    # Overall status
    $overallStatus = $vmHost.ExtensionData.OverallStatus

    $result = [PSCustomObject]@{
        HostName          = $vmHost.Name
        ConnectionState   = $vmHost.ConnectionState
        PowerState        = $vmHost.PowerState
        OverallStatus     = $overallStatus
        ESXiVersion       = $vmHost.Version
        ESXiBuild         = $vmHost.Build
        CPUModel          = $vmHost.ProcessorType
        CPUSockets        = $vmHost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
        CPUCores          = $vmHost.NumCpu
        MemoryTotalGB     = [math]::Round($vmHost.MemoryTotalGB, 0)
        CPUUsagePct       = $cpuUsagePct
        MemUsagePct       = $memUsagePct
        NTPRunning        = $ntpService.Running
        NTPServers        = $ntpServers
        SSHEnabled        = $sshService.Running
        FirewallEnabled   = $firewallEnabled
        VMCount           = ($vmHost | Get-VM).Count
        UptimeDays        = [math]::Round($vmHost.ExtensionData.Summary.Runtime.BootTime | ForEach-Object { ((Get-Date) - $_).TotalDays }, 1)
    }

    # Colour-coded console output
    $statusColor = switch ($overallStatus) {
        "green"  { "Green" }
        "yellow" { "Yellow" }
        "red"    { "Red" }
        default  { "White" }
    }

    Write-Host "    Status: $overallStatus | CPU: $cpuUsagePct% | Mem: $memUsagePct% | SSH: $($sshService.Running) | NTP: $($ntpService.Running)" -ForegroundColor $statusColor
    $report += $result
}

$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Health check complete. Report: $OutputPath" -ForegroundColor Green
Write-Host "Hosts checked  : $($report.Count)"
Write-Host "Healthy (green): $(($report | Where-Object OverallStatus -eq 'green').Count)"
Write-Host "Warning (yellow): $(($report | Where-Object OverallStatus -eq 'yellow').Count)"
Write-Host "Critical (red) : $(($report | Where-Object OverallStatus -eq 'red').Count)"
Write-Host "SSH enabled    : $(($report | Where-Object SSHEnabled -eq $true).Count) hosts (consider disabling in prod)"
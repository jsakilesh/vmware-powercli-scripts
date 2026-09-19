<#
.SYNOPSIS
    Generates a cluster capacity report showing used vs available resources.

.DESCRIPTION
    Reports CPU, RAM, and storage capacity per cluster with colour-coded
    warnings when usage exceeds 70% (warning) or 85% (critical).

.EXAMPLE
    .\Get-CapacityReport.ps1

.NOTES
    Author  : Akilesh J S
    Version : 1.0
    Requires: VMware.PowerCLI 13+
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$OutputPath = ".\capacity-report-$(Get-Date -Format 'yyyy-MM-dd').csv"
)

if (-not $global:DefaultVIServer) {
    Write-Error "Not connected to vCenter. Run Connect-VIServer first."
    exit 1
}

Write-Host "Generating capacity report..." -ForegroundColor Cyan

$report = Get-Cluster | ForEach-Object {
    $cluster = $_
    $hosts   = $cluster | Get-VMHost | Where-Object ConnectionState -eq "Connected"

    # CPU
    $cpuTotalGHz  = [math]::Round(($hosts | Measure-Object CpuTotalMhz  -Sum).Sum / 1000, 1)
    $cpuUsedGHz   = [math]::Round(($hosts | Measure-Object CpuUsageMhz  -Sum).Sum / 1000, 1)
    $cpuFreePct   = [math]::Round((($cpuTotalGHz - $cpuUsedGHz) / $cpuTotalGHz) * 100, 1)

    # Memory
    $memTotalGB   = [math]::Round(($hosts | Measure-Object MemoryTotalGB  -Sum).Sum, 1)
    $memUsedGB    = [math]::Round(($hosts | Measure-Object MemoryUsageGB  -Sum).Sum, 1)
    $memFreePct   = [math]::Round((($memTotalGB - $memUsedGB) / $memTotalGB) * 100, 1)

    # Storage (per datastore accessible by cluster)
    $datastores   = $hosts | Get-Datastore | Sort-Object Name -Unique
    $storTotalGB  = [math]::Round(($datastores | Measure-Object CapacityGB  -Sum).Sum, 1)
    $storFreeGB   = [math]::Round(($datastores | Measure-Object FreeSpaceGB -Sum).Sum, 1)
    $storFreePct  = if ($storTotalGB -gt 0) { [math]::Round(($storFreeGB / $storTotalGB) * 100, 1) } else { 0 }

    $cpuStatus = if ((100 - $cpuFreePct) -gt 85) { "CRITICAL" } elseif ((100 - $cpuFreePct) -gt 70) { "WARNING" } else { "OK" }
    $memStatus = if ((100 - $memFreePct) -gt 85) { "CRITICAL" } elseif ((100 - $memFreePct) -gt 70) { "WARNING" } else { "OK" }
    $storStatus= if ((100 - $storFreePct)-gt 85) { "CRITICAL" } elseif ((100 - $storFreePct)-gt 70) { "WARNING" } else { "OK" }

    $color = if ($cpuStatus -eq "CRITICAL" -or $memStatus -eq "CRITICAL" -or $storStatus -eq "CRITICAL") { "Red" }
             elseif ($cpuStatus -eq "WARNING" -or $memStatus -eq "WARNING" -or $storStatus -eq "WARNING") { "Yellow" }
             else { "Green" }

    Write-Host "[$($cluster.Name)] CPU: $(100-$cpuFreePct)% used [$cpuStatus] | Mem: $(100-$memFreePct)% used [$memStatus] | Storage: $(100-$storFreePct)% used [$storStatus]" -ForegroundColor $color

    [PSCustomObject]@{
        ClusterName       = $cluster.Name
        HostCount         = $hosts.Count
        VMCount           = ($cluster | Get-VM).Count
        CPU_TotalGHz      = $cpuTotalGHz
        CPU_UsedGHz       = $cpuUsedGHz
        CPU_UsedPct       = [math]::Round(100 - $cpuFreePct, 1)
        CPU_Status        = $cpuStatus
        Mem_TotalGB       = $memTotalGB
        Mem_UsedGB        = $memUsedGB
        Mem_UsedPct       = [math]::Round(100 - $memFreePct, 1)
        Mem_Status        = $memStatus
        Storage_TotalGB   = $storTotalGB
        Storage_FreeGB    = $storFreeGB
        Storage_UsedPct   = [math]::Round(100 - $storFreePct, 1)
        Storage_Status    = $storStatus
    }
}

$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved: $OutputPath" -ForegroundColor Green
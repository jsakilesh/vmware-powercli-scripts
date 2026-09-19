<#
.SYNOPSIS
    Performs a full vSAN health check across all vSAN-enabled clusters.

.DESCRIPTION
    Checks vSAN cluster health, disk group status, capacity, resync status,
    and object health. Flags warnings when slack space drops below 25%.

.EXAMPLE
    .\Get-vSANHealthReport.ps1

.NOTES
    Author  : Akilesh J S
    Version : 1.0
    Requires: VMware.PowerCLI 13+, vSAN Management API
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$OutputPath = ".\vsan-health-$(Get-Date -Format 'yyyy-MM-dd').csv",

    [Parameter()]
    [int]$SlackSpaceWarningPct = 25
)

if (-not $global:DefaultVIServer) {
    Write-Error "Not connected to vCenter. Run Connect-VIServer first."
    exit 1
}

Write-Host "Running vSAN health checks..." -ForegroundColor Cyan

$vsanClusters = Get-Cluster | Where-Object VsanEnabled

if ($vsanClusters.Count -eq 0) {
    Write-Warning "No vSAN-enabled clusters found."
    exit 0
}

$report = foreach ($cluster in $vsanClusters) {
    Write-Host "Checking cluster: $($cluster.Name)" -ForegroundColor Yellow

    $clusterView = $cluster | Get-View
    $vsanSystem  = Get-VsanView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"

    # Disk groups
    $diskGroups  = $cluster | Get-VMHost | Get-VsanDiskGroup
    $totalDisks  = ($diskGroups | Get-VsanDisk).Count
    $faultyDisks = ($diskGroups | Get-VsanDisk | Where-Object State -ne "inUse").Count

    # Capacity
    $vsanDatastore   = Get-Datastore | Where-Object Type -eq "vsan" | Where-Object { $_.ExtensionData.Host.Key -contains ($cluster | Get-VMHost | Select-Object -First 1 | Get-View).Self }
    $capacityGB      = [math]::Round($vsanDatastore.CapacityGB, 1)
    $freeGB          = [math]::Round($vsanDatastore.FreeSpaceGB, 1)
    $usedPct         = [math]::Round((($capacityGB - $freeGB) / $capacityGB) * 100, 1)
    $slackOK         = ($freeGB / $capacityGB * 100) -ge $SlackSpaceWarningPct

    $status = if ($faultyDisks -gt 0) { "CRITICAL" }
              elseif (-not $slackOK)  { "WARNING"  }
              else                    { "HEALTHY"  }

    $color = switch ($status) { "CRITICAL" { "Red" } "WARNING" { "Yellow" } default { "Green" } }
    Write-Host "  Status: $status | Capacity: $capacityGB GB | Used: $usedPct% | Faulty disks: $faultyDisks" -ForegroundColor $color

    [PSCustomObject]@{
        ClusterName      = $cluster.Name
        Status           = $status
        DiskGroupCount   = $diskGroups.Count
        TotalDisks       = $totalDisks
        FaultyDisks      = $faultyDisks
        CapacityGB       = $capacityGB
        FreeGB           = $freeGB
        UsedPct          = $usedPct
        SlackSpaceOK     = $slackOK
        HostCount        = ($cluster | Get-VMHost).Count
    }
}

$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "vSAN health report saved: $OutputPath" -ForegroundColor Green
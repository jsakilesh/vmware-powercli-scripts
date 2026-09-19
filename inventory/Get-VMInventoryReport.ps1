<#
.SYNOPSIS
    Generates a full VM inventory report from vCenter.

.DESCRIPTION
    Exports a CSV report of all VMs with CPU, RAM, disk, IP address, OS,
    power state, datastore, and cluster details.

.PARAMETER OutputPath
    Path to save the CSV report. Defaults to current directory.

.PARAMETER ClusterName
    Optional. Filter by cluster name.

.EXAMPLE
    .\Get-VMInventoryReport.ps1 -OutputPath "C:\Reports\vms.csv"

.EXAMPLE
    .\Get-VMInventoryReport.ps1 -ClusterName "Cluster01" -OutputPath "C:\Reports\cluster01-vms.csv"

.NOTES
    Author  : Akilesh J S
    Version : 1.0
    Requires: VMware.PowerCLI 13+
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$OutputPath = ".\vm-inventory-$(Get-Date -Format 'yyyy-MM-dd').csv",

    [Parameter()]
    [string]$ClusterName = ""
)

# Verify connection to vCenter
if (-not $global:DefaultVIServer) {
    Write-Error "Not connected to vCenter. Run Connect-VIServer first."
    exit 1
}

Write-Host "Collecting VM inventory from: $($global:DefaultVIServer.Name)" -ForegroundColor Cyan

# Get VMs - filter by cluster if specified
$vms = if ($ClusterName) {
    Get-Cluster -Name $ClusterName -ErrorAction Stop | Get-VM
} else {
    Get-VM
}

Write-Host "Found $($vms.Count) VMs. Gathering details..." -ForegroundColor Yellow

$report = $vms | ForEach-Object {
    $vm     = $_
    $guest  = $vm.Guest
    $config = $vm | Get-VMResourceConfiguration

    # Get datastore info
    $datastore = ($vm | Get-Datastore | Select-Object -First 1).Name

    # Get cluster/host info
    $vmHost  = $vm.VMHost.Name
    $cluster = (Get-Cluster -VMHost $vm.VMHost -ErrorAction SilentlyContinue).Name

    # Get snapshot count
    $snapshotCount = ($vm | Get-Snapshot -ErrorAction SilentlyContinue).Count

    # Get NICs and IPs
    $ipAddresses = ($guest.IPAddress | Where-Object { $_ -notmatch ":" }) -join ", "
    $macAddresses = ($vm | Get-NetworkAdapter | Select-Object -ExpandProperty MacAddress) -join ", "

    [PSCustomObject]@{
        Name            = $vm.Name
        PowerState      = $vm.PowerState
        NumCPU          = $vm.NumCpu
        MemoryGB        = [math]::Round($vm.MemoryGB, 2)
        ProvisionedGB   = [math]::Round(($vm.ProvisionedSpaceGB), 2)
        UsedSpaceGB     = [math]::Round($vm.UsedSpaceGB, 2)
        GuestOS         = $vm.GuestId
        GuestOSFullName = $guest.OSFullName
        IPAddress       = $ipAddresses
        MACAddress      = $macAddresses
        Hostname        = $guest.HostName
        VMHost          = $vmHost
        Cluster         = $cluster
        Datastore       = $datastore
        HardwareVersion = $vm.HardwareVersion
        VMwareToolsStatus = $guest.ExtensionData.ToolsStatus
        SnapshotCount   = $snapshotCount
        Notes           = $vm.Notes
        Created         = $vm.CreateDate
    }
}

# Export to CSV
$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved to: $OutputPath" -ForegroundColor Green
Write-Host "Total VMs: $($report.Count)"
Write-Host "Powered On: $(($report | Where-Object PowerState -eq 'PoweredOn').Count)"
Write-Host "Powered Off: $(($report | Where-Object PowerState -eq 'PoweredOff').Count)"
Write-Host "VMs with Snapshots: $(($report | Where-Object SnapshotCount -gt 0).Count)"
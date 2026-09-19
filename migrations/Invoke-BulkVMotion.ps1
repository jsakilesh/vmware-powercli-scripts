<#
.SYNOPSIS
    Bulk vMotion VMs from one host/datastore to another.

.DESCRIPTION
    Migrates VMs matching a filter (by name, tag, or resource pool) to a
    target host and/or datastore. Supports parallel migrations and WhatIf.

.PARAMETER SourceHost
    Source ESXi hostname to migrate VMs from.

.PARAMETER TargetHost
    Target ESXi hostname.

.PARAMETER TargetDatastore
    Target datastore name (optional - for storage vMotion).

.PARAMETER VMNameFilter
    Wildcard filter on VM name. Default "*" (all VMs on source host).

.PARAMETER MaxParallel
    Number of concurrent vMotion operations. Default 2.

.EXAMPLE
    # Preview migration (WhatIf)
    .\Invoke-BulkVMotion.ps1 -SourceHost "esxi01.lab.local" -TargetHost "esxi02.lab.local" -WhatIf

.EXAMPLE
    # Migrate all VMs with max 3 concurrent operations
    .\Invoke-BulkVMotion.ps1 -SourceHost "esxi01.lab.local" -TargetHost "esxi02.lab.local" -MaxParallel 3

.NOTES
    Author  : Akilesh J S
    Version : 1.0
    Requires: VMware.PowerCLI 13+
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$SourceHost,

    [Parameter(Mandatory)]
    [string]$TargetHost,

    [Parameter()]
    [string]$TargetDatastore = "",

    [Parameter()]
    [string]$VMNameFilter = "*",

    [Parameter()]
    [int]$MaxParallel = 2
)

if (-not $global:DefaultVIServer) {
    Write-Error "Not connected to vCenter. Run Connect-VIServer first."
    exit 1
}

$source  = Get-VMHost -Name $SourceHost -ErrorAction Stop
$target  = Get-VMHost -Name $TargetHost -ErrorAction Stop
$vms     = $source | Get-VM | Where-Object { $_.Name -like $VMNameFilter -and $_.PowerState -eq "PoweredOn" }

if ($vms.Count -eq 0) {
    Write-Warning "No powered-on VMs matching filter '$VMNameFilter' found on $SourceHost"
    exit 0
}

Write-Host "VMs to migrate: $($vms.Count)" -ForegroundColor Cyan
Write-Host "Source : $SourceHost"
Write-Host "Target : $TargetHost"
if ($TargetDatastore) { Write-Host "Storage: $TargetDatastore" }
Write-Host "Parallel: $MaxParallel concurrent migrations"
Write-Host ""

$jobs   = [System.Collections.Generic.Queue[object]]::new()
$active = [System.Collections.Generic.List[object]]::new()

foreach ($vm in $vms) {
    if ($PSCmdlet.ShouldProcess($vm.Name, "vMotion to $TargetHost")) {
        $moveArgs = @{ VM = $vm; Destination = $target; RunAsync = $true }
        if ($TargetDatastore) {
            $ds = Get-Datastore -Name $TargetDatastore -ErrorAction Stop
            $moveArgs.Datastore = $ds
        }
        $jobs.Enqueue($moveArgs)
    }
}

Write-Host "Starting migrations..." -ForegroundColor Yellow
$completed = 0; $failed = 0

while ($jobs.Count -gt 0 -or $active.Count -gt 0) {
    # Start new jobs up to MaxParallel
    while ($active.Count -lt $MaxParallel -and $jobs.Count -gt 0) {
        $args = $jobs.Dequeue()
        $task = Move-VM @args
        $active.Add($task)
        Write-Host "  Started: $($args.VM.Name)" -ForegroundColor Yellow
    }

    # Check active tasks
    $stillActive = [System.Collections.Generic.List[object]]::new()
    foreach ($task in $active) {
        $task = Get-Task -Id $task.Id -ErrorAction SilentlyContinue
        if ($task.State -eq "Success") {
            Write-Host "  Done   : $($task.ObjectId) -> $TargetHost" -ForegroundColor Green
            $completed++
        } elseif ($task.State -eq "Error") {
            Write-Host "  Failed : $($task.ObjectId) - $($task.Description)" -ForegroundColor Red
            $failed++
        } else {
            $stillActive.Add($task)
        }
    }
    $active = $stillActive
    if ($active.Count -gt 0) { Start-Sleep -Seconds 10 }
}

Write-Host ""
Write-Host "Migration complete. Success: $completed | Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Yellow" } else { "Green" })
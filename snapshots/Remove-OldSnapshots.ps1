<#
.SYNOPSIS
    Audits all VM snapshots and optionally removes snapshots older than N days.

.DESCRIPTION
    Generates a full snapshot report (VM name, snapshot name, age, size, creator).
    With -Remove switch, deletes snapshots older than -OlderThanDays days.
    Always supports -WhatIf to preview before deletion.

.PARAMETER OlderThanDays
    Remove snapshots older than this many days. Default: 7.

.PARAMETER Remove
    Switch to enable snapshot deletion. Without this, script is read-only.

.PARAMETER OutputPath
    Path to save the snapshot report CSV.

.EXAMPLE
    # Report only
    .\Remove-OldSnapshots.ps1

.EXAMPLE
    # Preview what would be deleted (safe - uses WhatIf)
    .\Remove-OldSnapshots.ps1 -Remove -OlderThanDays 7 -WhatIf

.EXAMPLE
    # Actually delete snapshots older than 14 days
    .\Remove-OldSnapshots.ps1 -Remove -OlderThanDays 14

.NOTES
    Author  : Akilesh J S
    Version : 1.0
    Requires: VMware.PowerCLI 13+
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [int]$OlderThanDays = 7,

    [Parameter()]
    [switch]$Remove,

    [Parameter()]
    [string]$OutputPath = ".\snapshot-report-$(Get-Date -Format 'yyyy-MM-dd').csv"
)

if (-not $global:DefaultVIServer) {
    Write-Error "Not connected to vCenter. Run Connect-VIServer first."
    exit 1
}

Write-Host "Collecting snapshots from: $($global:DefaultVIServer.Name)" -ForegroundColor Cyan
$cutoffDate = (Get-Date).AddDays(-$OlderThanDays)

$allSnapshots = Get-VM | Get-Snapshot -ErrorAction SilentlyContinue
Write-Host "Total snapshots found: $($allSnapshots.Count)" -ForegroundColor Yellow

$report = $allSnapshots | ForEach-Object {
    $snap = $_
    $ageDays = [math]::Round(((Get-Date) - $snap.Created).TotalDays, 1)

    [PSCustomObject]@{
        VMName        = $snap.VM.Name
        SnapshotName  = $snap.Name
        Description   = $snap.Description
        Created       = $snap.Created
        AgeDays       = $ageDays
        SizeGB        = [math]::Round($snap.SizeGB, 2)
        IsOld         = ($snap.Created -lt $cutoffDate)
        PowerState    = $snap.VM.PowerState
        IsCurrent     = $snap.IsCurrent
    }
}

# Save report
$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved: $OutputPath" -ForegroundColor Green

# Summary
$oldSnaps = $report | Where-Object IsOld
Write-Host ""
Write-Host "=== Snapshot Summary ===" -ForegroundColor Cyan
Write-Host "Total snapshots : $($report.Count)"
Write-Host "Old (>$OlderThanDays days): $($oldSnaps.Count)"
Write-Host "Total size (all): $([math]::Round(($report | Measure-Object SizeGB -Sum).Sum, 2)) GB"
Write-Host "Old snap size   : $([math]::Round(($oldSnaps | Measure-Object SizeGB -Sum).Sum, 2)) GB"

if ($Remove -and $oldSnaps.Count -gt 0) {
    Write-Host ""
    Write-Host "Removing $($oldSnaps.Count) snapshots older than $OlderThanDays days..." -ForegroundColor Yellow

    foreach ($snapInfo in $oldSnaps) {
        $snap = Get-VM -Name $snapInfo.VMName | Get-Snapshot -Name $snapInfo.SnapshotName -ErrorAction SilentlyContinue
        if ($snap) {
            if ($PSCmdlet.ShouldProcess("$($snapInfo.VMName) / $($snapInfo.SnapshotName)", "Remove Snapshot")) {
                Remove-Snapshot -Snapshot $snap -Confirm:$false
                Write-Host "  Removed: $($snapInfo.VMName) / $($snapInfo.SnapshotName) (Age: $($snapInfo.AgeDays) days)" -ForegroundColor Green
            }
        }
    }
    Write-Host "Done." -ForegroundColor Green
} elseif ($Remove -and $oldSnaps.Count -eq 0) {
    Write-Host "No snapshots older than $OlderThanDays days found." -ForegroundColor Green
}
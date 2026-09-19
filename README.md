# ⚡ VMware PowerCLI Scripts

> A curated collection of production-ready PowerCLI scripts for automating VMware vSphere environments — built from real-world experience managing enterprise vSphere infrastructure.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![PowerCLI](https://img.shields.io/badge/PowerCLI-13%2B-607078?style=for-the-badge&logo=vmware&logoColor=white)](https://developer.vmware.com/powercli)
[![vSphere](https://img.shields.io/badge/vSphere-7.x%20%7C%208.x-607078?style=for-the-badge&logo=vmware&logoColor=white)](https://www.vmware.com/products/vsphere.html)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## 📁 Script Library

| Category | Scripts | Description |
|----------|---------|-------------|
| [VM Lifecycle](./vm-lifecycle/) | 4 scripts | Clone, deploy, snapshot, remove VMs |
| [Inventory & Reports](./inventory/) | 3 scripts | VM inventory, capacity, orphaned files |
| [Host Management](./host-management/) | 3 scripts | Maintenance mode, patching, health checks |
| [Snapshot Management](./snapshots/) | 2 scripts | Snapshot audit, bulk delete old snapshots |
| [vSAN](./vsan/) | 2 scripts | Health check, disk usage, rebalance |
| [Resource Management](./resources/) | 2 scripts | DRS rules, resource pool report |
| [Migrations](./migrations/) | 2 scripts | vMotion bulk, cross-cluster migration |

---

## 🚀 Quick Start

### Prerequisites
```powershell
# Install PowerCLI
Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force

# Configure PowerCLI (ignore self-signed certs in lab)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Connect to vCenter
Connect-VIServer -Server "vcenter.homelab.local" -User "administrator@vsphere.local" -Password "YourPassword"
```

### Run any script
```powershell
# Example: Generate full VM inventory report
.\inventory\Get-VMInventoryReport.ps1 -OutputPath "C:\Reports\vm-inventory.csv"

# Example: Find and delete snapshots older than 7 days
.\snapshots\Remove-OldSnapshots.ps1 -OlderThanDays 7 -WhatIf

# Example: Put all hosts in a cluster into maintenance mode
.\host-management\Set-ClusterMaintenanceMode.ps1 -ClusterName "Cluster01" -Enable
```

---

## 📋 Script Details

### VM Lifecycle
| Script | Description |
|--------|-------------|
| `Clone-VMFromTemplate.ps1` | Deploy VMs from a template with customisation spec |
| `New-BulkVMs.ps1` | Bulk deploy VMs from a CSV input file |
| `Remove-VMSafely.ps1` | Safely decommission VM (snapshot → power off → remove) |
| `Set-VMResourceConfig.ps1` | Update CPU/Memory reservations and limits in bulk |

### Inventory & Reports
| Script | Description |
|--------|-------------|
| `Get-VMInventoryReport.ps1` | Full VM inventory: CPU, RAM, disk, IP, OS, datastore |
| `Get-CapacityReport.ps1` | Cluster capacity report: used vs available CPU/RAM/storage |
| `Find-OrphanedFiles.ps1` | Find orphaned VMDKs and ISOs consuming datastore space |

### Snapshot Management
| Script | Description |
|--------|-------------|
| `Get-SnapshotReport.ps1` | Audit all snapshots: age, size, VM, creator |
| `Remove-OldSnapshots.ps1` | Delete snapshots older than N days with email notification |

### Host Management
| Script | Description |
|--------|-------------|
| `Set-ClusterMaintenanceMode.ps1` | Put/remove entire cluster from maintenance mode gracefully |
| `Get-HostHealthCheck.ps1` | ESXi host health: hardware, services, NTP, DNS, firewall |
| `Update-HostBaseline.ps1` | Remediate hosts against a VUM/LCM baseline |

### vSAN
| Script | Description |
|--------|-------------|
| `Get-vSANHealthReport.ps1` | Full vSAN health check: disk groups, objects, capacity |
| `Get-vSANCapacity.ps1` | Per-datastore capacity with slack space warnings |

---

## 💡 Tips & Best Practices

- Always use `-WhatIf` first to preview what a script will do before running it in production
- Store credentials using `New-VICredentialStoreItem` — never hardcode passwords
- Run inventory/report scripts in a **read-only service account** — no need for admin rights
- Schedule reports with Windows Task Scheduler or as a Kubernetes CronJob (via containerised PowerShell)

---

## 🤝 Contributing

PRs welcome! Please follow the [contribution guide](CONTRIBUTING.md):
1. One script per PR
2. Include comment-based help (`Get-Help .\script.ps1`)
3. Support `-WhatIf` on any destructive operations
4. Test on vSphere 7.x and 8.x

---

## 📜 License
MIT — free to use, modify, and distribute.

---

> Maintained by [Akilesh J S](https://github.com/jsakilesh) — Senior DevOps / Platform Engineer
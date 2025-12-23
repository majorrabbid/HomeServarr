# Proxmox Host Hardware Specifications

This document details the hardware configuration of the Proxmox VE host running the HomeServarr lab.

---

## System Information

| Component | Details |
|-----------|---------|
| **Manufacturer** | Beelink |
| **Model** | SER5 MAX |
| **Serial Number** | *(Redacted for privacy)* |

---

## CPU

| Specification | Value |
|---------------|-------|
| **Model** | AMD Ryzen 7 5800H with Radeon Graphics |
| **Architecture** | x86_64 |
| **Cores** | 8 physical cores |
| **Threads** | 16 threads (SMT enabled) |
| **Base Clock** | 3.2 GHz |
| **Max Boost** | 4.4 GHz |
| **Cache** | L1: 512 KiB, L2: 4 MiB, L3: 16 MiB |

**Current Usage**: Check via Proxmox UI or `htop` on the host.

---

## Memory (RAM)

| Specification | Value |
|---------------|-------|
| **Total** | 64 GB DDR4 |
| **Speed** | 3200 MHz |
| **Type** | SO-DIMM |

**Current Usage**:
- Use `free -h` on the host for real-time stats.
- Proxmox UI shows memory allocation across LXCs and VMs.

---

## Storage

### Primary System Disk
| Disk | Size | Type | Mount | Usage |
|------|------|------|-------|-------|
| **nvme0n1** | 1 TB | NVMe SSD | `/` (root), Proxmox system | System + LXC storage |

### Media Storage
| Disk | Size | Type | Mount | Usage |
|------|------|------|-------|-------|
| **sdb1** | 4 TB | SATA SSD | `/mnt/media` | Shared media library (Plex, Arr stack) |

**Current Disk Usage**:
```bash
# Check media disk usage
df -h /mnt/media

# Check Proxmox storage
pvesm status
```

**Typical Usage** (as of last check):
- `/mnt/media`: ~60-70% utilized
- Root filesystem: ~20-30% utilized

---

## Network

| Interface | Type | Speed |
|-----------|------|-------|
| **eth0** | Realtek RTL8125 2.5GbE | 2.5 Gbps |
| **wlan0** | Intel Wi-Fi 6 AX200 | 802.11ax (disabled, not used) |

**Network Configuration**:
- Static IP: `192.168.4.42`
- Connected via `vmbr0` bridge to LAN
- All LXCs use bridged networking through `vmbr0`

---

## Power & Cooling

- **TDP**: 35W (configurable, typically runs at 25-35W)
- **Cooling**: Active fan (quiet operation under normal load)
- **Power Supply**: 19V DC adapter (included)

---

## Notes

- This is a **mini PC** form factor, ideal for home lab use.
- Low power consumption (~25-40W typical) makes it cost-effective for 24/7 operation.
- The Ryzen 7 5800H provides excellent performance for virtualization workloads.
- 64GB RAM allows running 10+ LXCs comfortably with headroom for expansion.

---

## Monitoring Resources

To monitor current resource usage:

1. **Proxmox Web UI**: `https://192.168.4.42:8006`
   - Dashboard shows CPU, RAM, and storage at a glance
   - Per-LXC resource graphs available

2. **SSH Commands**:
   ```bash
   # CPU usage
   htop
   
   # Memory
   free -h
   
   # Disk
   df -h
   pvesm status
   
   # Network
   ip -s link
   ```

3. **Grafana Dashboard** (if configured via LXC 112):
   - Real-time metrics from Proxmox and LXCs

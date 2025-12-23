# Proxmox Host Hardware Specifications

This document details the hardware configuration of the Proxmox VE host running the HomeServarr lab.

---

## System Information

| Component | Details |
|-----------|---------|
| **Manufacturer** | BOSGAME |
| **Model** | Ecolite Series |
| **Serial Number** | *(Redacted for privacy)* |

---

## CPU

| Specification | Value |
|---------------|-------|
| **Model** | AMD Ryzen 5 3550H with Radeon Vega Mobile Gfx |
| **Architecture** | x86_64 |
| **Cores** | 4 physical cores |
| **Threads** | 8 threads (SMT enabled) |
| **Base Clock** | 1.4 GHz |
| **Max Boost** | 2.1 GHz |
| **Cache** | L1: 384 KiB, L2: 2 MiB, L3: 4 MiB |

**Current Usage**: Check via Proxmox UI or `htop` on the host.

---

## Memory (RAM)

| Specification | Value |
|---------------|-------|
| **Total** | 12 GB DDR4 |
| **Speed** | 2400-2667 MHz |
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
| **sda2** | 931 GB (879 GB usable) | USB 3.0 External Drive | `/mnt/media` | Shared media library (Plex, Arr stack) |

**Note**: The media drive is connected via USB-C/USB 3.0 to the host.

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
- Low power consumption (~15-25W typical) makes it cost-effective for 24/7 operation.
- The Ryzen 5 3550H provides solid performance for light virtualization workloads.
- 12GB RAM allows running 10+ lightweight LXCs comfortably.

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

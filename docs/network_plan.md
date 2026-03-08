# DNS & Subnet Migration Plan (.home)

This document outlines the transition from a `/22` network to a `/24` network and the implementation of a DNS-based service discovery system using the `.home` domain.

## 1. Goal: Subnet Consolidation (/22 → /24) - **COMPLETED**

The network is now consolidated into the **`192.168.4.0/24`** range.

### Network Inventory (Active as of 2026-02-20)

| LXC ID | Service Name | Current IP | DNS Name | Status |
| :--- | :--- | :--- | :--- | :--- |
| --- | **Proxmox Host** | `192.168.4.42` | `pve.home` | ✅ Active |
| 103 | **Pi-hole / DNS** | `192.168.4.122` (+alias `192.168.4.53`) | `pihole.home`, `dns.home` | ✅ Active |
| 101 | **Plex** | `192.168.4.132` | `plex.home` | ✅ Active (DHCP) |
| 102 | **Arr Stack** | `192.168.4.124` | `arr.home` | ✅ Active (DHCP) |
| 104 | **UniFi** | `192.168.4.131` | `unifi.home` | ✅ Active (DHCP) |
| 105 | **n8n** | `192.168.4.128` | `n8n.home` | ✅ Active (DHCP) |
| 106 | **Twingate** | `192.168.4.129` | `twingate.home` | ✅ Active (DHCP) |
| 107 | **PatchMon** | `192.168.4.130` | `patchmon.home` | ✅ Active (DHCP) |
| 108 | **Homepage** | `192.168.4.126` | `homepage.home`, `lab.home` | ✅ Active (DHCP) |
| 109 | **TeamSpeak** | `192.168.4.147` | `teamspeak.home` | ✅ Active (DHCP) |
| 110 | **Homebridge (old)** | — | — | ⛔ Stopped |
| 111 | **Homebridge** | `192.168.4.166` | `homebridge.home` | ✅ Active (DHCP) |
| 112 | **Grafana** | `192.168.4.125` | `grafana.home` | ✅ Active (DHCP) |

> **Note:** CT100 (Home Assistant) is no longer in inventory — confirm if decommissioned or migrated.

---

## 2. Infrastructure Setup (The "Bridge" Strategy)

The Pi-hole currently responds to both:
- **`192.168.4.53`** (Target DNS IP)
- **`192.168.5.83`** (Old legacy IP - still active if containers haven't refreshed)

**Persistent Alias**: Configured in `/etc/network/interfaces` on LXC 103.

---

## 3. Post-Migration Maintenance

### DHCP Reservations
To ensure these IPs don't change, **it is strongly recommended** to set "Static Lease" or "DHCP Reservation" in the Eero app for these MAC addresses using the `.4.x` IPs listed above.

### Application Updates
Update individual service configs (e.g., Homepage dashboard, Radarr/Sonarr internal links) to use the `.home` addresses.

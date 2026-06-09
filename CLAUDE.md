# HomeServarr — Claude Code Guide

## What this repo is

Single bare-metal Proxmox VE home lab at `192.168.4.42`. All services run as LXC containers or a VM. GitOps via FluxCD on k3s.

## Key addresses

| Service | Address | Notes |
|---------|---------|-------|
| Proxmox UI | `https://192.168.4.42:8006` | |
| Home Assistant | `http://192.168.4.136:8123` | Use IP — `.home` doesn't resolve from Mac |
| Pi-hole | `http://192.168.4.122/admin` | LXC 103; `.53` record is stale |
| Plex | `http://192.168.4.132:32400` | LXC 101 |
| Beszel | `http://beszel.home` | k3s, CT113 |
| Glance | `http://glance.home` | k3s, CT113 |
| Overseerr | `http://192.168.4.124:5055` | LXC 102 |

## Proxmox containers

| CT | Hostname | Role |
|----|----------|------|
| 100 (VM) | haos | Home Assistant OS |
| 101 | plex | Plex |
| 102 | arr | *arr stack (Docker) |
| 103 | pihole | Pi-hole + Unbound |
| 104 | unifi | UniFi Controller |
| 106 | twingate | Zero-trust connector |
| 111 | homebridge | Apple HomeKit bridge |
| 113 | k3s | k3s + Flux + Beszel + Glance |

## SSH

```bash
ssh root@192.168.4.42          # Proxmox host
ssh root@192.168.4.{IP}        # Most LXCs directly
# Pi-hole (CT103) — no direct SSH, use:
ssh root@192.168.4.42 'pct exec 103 -- bash -c "COMMAND"'
# k3s (CT113):
ssh root@192.168.4.42 'pct exec 113 -- bash -c "/usr/local/bin/k3s kubectl COMMAND"'
```

## Flux / GitOps

Flux watches branch `feat/network-dashboard` on this repo.

```
deploy/flux/
  clusters/k3s-home/          # Flux bootstrap kustomizations
  apps/
    dashboard/                # Glance configmap + Beszel deployment
    monitoring/               # Beszel hub
```

**Workflow:** edit → commit → push → Flux reconciles within ~1 min.

Secrets (Pi-hole password, HA token) are **not** in git. They live in the `dashboard-secrets` k8s Secret, created by `scripts/create-dashboard-secrets.sh`.

## Home Assistant

- Token: `~/.openclaw/secrets/ha_token`
- Key entity IDs: `sensor.tessie_outside_temperature`, `sensor.tessie_battery_level`
- Blinds automation: `automation.sunset_close_blinds` (triggers below 1° elevation or cloud cover >70% while sun <10°)

## Pi-hole

- Password: `~/.openclaw/secrets/pihole_password`
- Version: v6 (uses `/api/auth` session-based auth)
- DNS stats API: `http://192.168.4.122/api/stats/summary`

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/block_roblox.sh` | Block Roblox domains on Pi-hole |
| `scripts/unblock_roblox.sh` | Unblock Roblox |
| `scripts/update_pihole_hosts.sh` | Push custom DNS entries to Pi-hole |
| `scripts/create-dashboard-secrets.sh` | Create k8s dashboard-secrets Secret |

## Skills

Reusable skills in `skills/` — invoke from Claude Code with `/skill-name`.

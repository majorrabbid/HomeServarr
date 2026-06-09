# Home Network Dashboard — Rebuild Plan (GitOps)

Replace the current **Homepage** (LXC 108) + **Grafana/Prometheus** (LXC 112) stack with a
lighter, GitOps-managed set of apps, deployed via **FluxCD** to a dedicated k3s cluster.

Decisions (locked 2026-06-07):

| Area | Choice | Why |
|------|--------|-----|
| Runtime | **k3s** as the Flux target | Real always-on GitOps playground (replaces the laptop-only `kind` cluster) |
| Metrics | **Beszel** | Lightweight host + LXC + Docker health/stats. Tiny footprint vs Grafana/Prometheus |
| Dashboard | **Glance** | YAML-configured (fits GitOps), native Pi-hole widget, custom-API widgets for HA |
| Migration | **Side-by-side → decommission** | No downtime; retire LXC 108 + 112 only after the new stack is validated |

## ⚠️ Host constraint (drives the runtime sub-decision)

The Proxmox host (Ryzen 5 3550H, **12 GB RAM**) was measured at **7.8 GB used / ~300 MB free /
2.1 GB swap in use** with 11 LXCs + the HAOS VM running. There are **no VM cloud images** staged.

- A 3-4 GB k3s **VM** would reserve RAM up front and risk swapping/OOM on critical services
  (Plex, Home Assistant, Pi-hole DNS).
- **Recommendation: run k3s in a privileged LXC (CT 113)** instead of a VM. LXC shares the host
  kernel and only consumes what it actually uses (~1 GB idle for k3s + Beszel hub + Glance).
- Decommissioning LXC 108 + 112 at cutover **reclaims** ~1.5-2 GB, easing the squeeze.

**Open decision before compute is provisioned:** k3s-in-LXC (recommended, fits today) vs
free-RAM-first-then-VM vs add physical RAM. Everything below is runtime-agnostic except Phase 1.

## Target architecture

```
                 ┌─────────────────────── Proxmox host (192.168.4.42) ───────────────────────┐
                 │                                                                            │
   Browser ──────┼──▶ Glance  (dashboard front page)   ┐                                      │
                 │                                      │  k3s cluster (CT 113, FluxCD-managed)│
                 │    Beszel hub (metrics UI) ◀─────────┘                                      │
                 │        ▲                                                                    │
                 │        │ Beszel agents (system stats) on each guest:                        │
                 │        ├── pve host (192.168.4.42)                                           │
                 │        ├── arr/Docker host (CT102)                                           │
                 │        ├── Pi-hole (CT103), Plex (CT101), … (opt-in per LXC)                 │
                 └────────┼────────────────────────────────────────────────────────────────────┘
                          │
   Data sources Glance pulls:  Pi-hole v6 API · Home Assistant /api · service up/down checks
```

- **Glance** = the human-facing home page: service links, Pi-hole summary, selected HA entities
  (temps, energy, Tesla battery), site status, weather/calendar.
- **Beszel** = the health/metrics layer: per-host CPU/RAM/disk/network + Docker container stats,
  with history. Hub in k8s; agents are tiny binaries/systemd units on each monitored guest.

## Repo layout (added in this branch)

```
deploy/
  k3s/
    README.md                 # how to stand up the k3s LXC + bootstrap Flux
  flux/apps/
    kustomization.yaml        # + dashboard, + monitoring
    dashboard/                # Glance
      namespace.yaml
      configmap.yaml          # glance.yml (committed; secrets referenced, not inlined)
      deployment.yaml
      service.yaml
    monitoring/               # Beszel hub
      namespace.yaml
      pvc.yaml
      deployment.yaml
      service.yaml
scripts/
  create-dashboard-secrets.sh # creates k8s secrets (HA token, Pi-hole pw) out-of-band
  install-beszel-agents.sh    # installs Beszel agent on the host + chosen LXCs
```

Secrets (HA long-lived token, Pi-hole app password, Beszel agent key) are **never committed** —
created via `scripts/` into the cluster, mirroring the existing `regcred` / `create-k8s-secrets.sh`
pattern.

## How each requested stat gets wired

| Stat | Source | Mechanism |
|------|--------|-----------|
| Pi-hole (queries, blocked %, clients) | Pi-hole v6 API (`pihole.home`) | Glance native `pihole` widget (v6 + app password) |
| Home Assistant (temps, energy, Tesla, etc.) | HA REST `/api/states/<entity>` | Glance `custom-api` widgets (Bearer token) |
| LXC health (CPU/RAM/disk/net) | Beszel agent per LXC | Agent → hub over SSH key |
| Docker container stats | Beszel agent on CT102 (Docker host) | Agent reads Docker socket |
| Proxmox host health | Beszel agent on the pve host | Agent → hub |
| Service up/down | Glance `monitor` widget | HTTP/ping checks of each service URL |

## Phased build

- **Phase 0 — Plan + scaffold** *(this branch, no live impact)*: plan doc + all Flux manifests +
  helper scripts. Nothing reconciles until a cluster exists and the branch is merged. ✅ in progress.
- **Phase 1 — Compute** *(needs the runtime decision)*: create CT 113, install k3s, fetch kubeconfig.
- **Phase 2 — Flux bootstrap**: install Flux on the new cluster, point its GitRepository at this
  repo, retarget away from the dead `kind` cluster.
- **Phase 3 — Deploy apps**: merge branch → Flux reconciles Beszel hub + Glance. Create secrets.
- **Phase 4 — Agents + wiring**: install Beszel agents on host + chosen LXCs; fill in Glance
  widgets (Pi-hole, HA entities, service list).
- **Phase 5 — Validate side-by-side**: run new stack next to Homepage/Grafana; confirm parity.
- **Phase 6 — Decommission**: stop + back up + remove LXC 108 (Homepage) and LXC 112
  (Grafana/Prometheus), reclaiming RAM. Update `MEMORY.md` / `TOOLS.md`.

## Rollback

- Branch isolation means main/Flux is untouched until Phase 3 merge.
- LXC 108/112 are only stopped (not destroyed) until the new stack is proven; configs backed up
  first, so cutover is reversible.

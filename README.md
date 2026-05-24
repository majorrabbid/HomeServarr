

# 🧩 Proxmox Home Lab – Media, Networking & Automation Stack

> Proxmox VE + unprivileged LXCs + a single Docker host (`arr`) running the full *arr stack* (qBittorrent, Radarr, Sonarr, Prowlarr, Bazarr, Overseerr), alongside Plex, Pi-hole, UniFi, Twingate Connector, TeamSpeak and a Homepage dashboard.

_Last verified: Nov 2025 (Proxmox VE 9, Debian 12 host, Ubuntu 24.04 LXCs)._

---

## 1. High-Level Architecture

> 🎨 **Interactive Visualization**: View the [interactive architecture diagram](docs/architecture.html) for an explorable view of all LXCs, Docker containers, and scripts.

```mermaid
flowchart LR
    subgraph PVE["Proxmox VE Host"]
        direction TB

        subgraph L101["Plex (LXC 101)"]
            PLEX[Plex Media Server]
        end

        subgraph L102["Arr Stack (LXC 102)"]
            direction TB
            DKR[(Docker Engine)]
            QB[qBittorrent]
            RD[Radarr]
            SD[Sonarr]
            PR[Prowlarr]
            BZ[Bazarr]
            OS[Overseerr]
        end

        subgraph L103["Pi-hole (LXC 103)"]
            PH[Pi-hole]
            UB[Unbound DNS]
        end

        subgraph L104["UniFi (LXC 104)"]
            UF[UniFi Network App]
        end

        subgraph L106["Twingate (LXC 106)"]
            TG[Twingate Connector]
        end

        subgraph L108["Homepage (LXC 108)"]
            HP[Homepage dashboard]
        end

        subgraph L109["TeamSpeak (LXC 109)"]
            TS[TeamSpeak Server]
        end

        SSD[/"/mnt/media (ext4 SSD)"/]
    end

    QB --- SSD
    RD --- SSD
    SD --- SSD
    PLEX --- SSD
````

**Key ideas**

* Proxmox host mounts an **ext4 SSD at `/mnt/media`**.
* That mount is **shared into unprivileged LXCs** (Plex + Arr) as a bind mount.
* **Network**: Consolidated on **`192.168.4.0/24`** subnet.
* **DNS**: Pi-hole (`pihole.home`) provides local DNS resolution for `*.home` domains.
* Homepage (`homepage.home`) pulls everything together into a simple dashboard.

---

## 2. Jarvis AI Assistant

> 🤖 **Custom Agent**: This repository includes a specialized VS Code agent called "Jarvis" for managing your Proxmox home lab operations.

The Jarvis agent provides intelligent assistance for:

- **Media Disk Management**: Monitor `/mnt/media` usage and intelligently prune old content from Sonarr/Radarr
- **Container Patching**: Bulk security updates for all LXC containers with DNS validation
- **Host Maintenance**: Proxmox host patching with kernel management options
- **Health Monitoring**: Comprehensive system health reports and status checks
- **DNS Management**: Pi-hole custom DNS record updates and validation
- **Service Discovery**: LXC container inventory and network mapping

### Getting Started with Jarvis

1. **Agent Definition**: The agent is configured in `.agent.md`
2. **Skills**: Specialized capabilities are defined in `skills/` directory
3. **Configuration**: Common settings in `config/config.env` (copy to `/opt/homeservarr/config.env` on host)
4. **Scripts**: Automation scripts in `scripts/` provide the backend functionality

### Example Usage

- "Generate a health report for my home lab"
- "Check media disk usage and prune if over 90%"
- "Patch all LXC containers with latest updates"
- "Update Pi-hole DNS records for new services"

### Chat with Jarvis

Jarvis can also be used as a conversational assistant for your home lab. Ask natural-language questions, and Jarvis will recommend the right skill or script and help you take safe action.

Example chat prompts:
- "Jarvis, what is the current status of my Pi-hole container?"
- "How do I patch all LXCs safely?"
- "Show me the disk usage for /mnt/media."
- "What should I check if Pi-hole is not resolving DNS?"
- "List all running containers and their IP addresses."

For full chat guidance, see `skills/chat/SKILL.md` and use `scripts/jarvis_chat.sh` for quick prompt examples.

### Containerizing Jarvis with Flux CD

This repository now includes a lightweight container build for the Jarvis agent and a Flux CD GitOps deployment manifest.

- `docker/agent/Dockerfile` builds a minimal Jarvis agent container image.
- `docker/agent/homeservarr-agent` provides a simple entrypoint that runs `scripts/jarvis_chat.sh` by default.
- `deploy/flux/flux-agent` contains a Flux `Kustomization` for a namespaced deployment.
- `deploy/flux/flux-system` contains Flux `GitRepository` and `Kustomization` resources to sync the repo.

Build and push the agent image:

```bash
cd /Users/sunny/repos/HomeServarr/docker/agent
docker build -t ghcr.io/<your-org>/homeservarr-jarvis-agent:latest .
docker push ghcr.io/<your-org>/homeservarr-jarvis-agent:latest
```

Then apply the Flux manifests from the cluster bootstrap namespace:

```bash
kubectl apply -f deploy/flux/flux-system/gitrepository.yaml
kubectl apply -f deploy/flux/flux-system/kustomization.yaml
```

> 💡 Flux is a CNCF graduated GitOps operator, and this example uses the graduated `GitRepository` and `Kustomization` APIs for a simple application deployment.

### Run Jarvis locally with Docker

This repository also supports running the Jarvis agent locally on your Mac, independent of the Proxmox host.

1. Build and start the local container:

```bash
cd docker/agent
docker compose up --build -d
```

2. Run Jarvis interactively inside the container:

```bash
docker exec -it homeservarr-jarvis-agent /usr/local/bin/homeservarr-agent
```

3. Stop the local container:

```bash
docker compose down
```

A helper script is available at `docker/agent/run-local.sh` if you want a single command to start the local Jarvis container.

> ⚠️ This local Docker setup mounts only the repository source under `/opt/homeservarr` and does not require any Proxmox host mounts.

---

## 3. Proxmox Host Setup

> 📋 **Hardware Specs**: See [docs/hardware.md](docs/hardware.md) for detailed hardware specifications and resource monitoring guidance.

### 2.1. Base requirements

* Proxmox VE 9.x
* A dedicated SSD or HDD for media (e.g. `/dev/sdb1`)
* Templates for Ubuntu 24.04 LXC (for most containers)

### 2.2. Media SSD mount (`/mnt/media`)

On the Proxmox host:

```bash
# Create mountpoint
mkdir -p /mnt/media

# Identify the disk/partition
lsblk
blkid /dev/sdb1   # use your actual device

# Add to /etc/fstab (example)
echo "/dev/sdb1 /mnt/media ext4 defaults 0 2" >> /etc/fstab

# Mount it
mount -a

# For unprivileged LXCs we use UID/GID 100000 on the host
chown -R 100000:100000 /mnt/media
chmod -R 775 /mnt/media
```

> 💡 **Why 100000:** For unprivileged LXCs, UID `0` inside the container is mapped to UID `100000` on the host. Giving ownership to `100000:100000` lets “root inside the LXC” write to the share safely.

---

## 3. LXC Layout

Current key LXCs:

| VMID | Name | Purpose | DNS Name | IP Address |
| ---- | ---- | ------- | -------- | ---------- |
| 100 | `haos` | Home Assistant VM | `homeassistant.home` | `192.168.4.136` |
| 101 | `plex` | Plex Media Server | `plex.home` | `192.168.4.132` |
| 102 | `arr` | Docker host for *arr stack* | `arr.home` | `192.168.4.124` |
| 103 | `pihole` | Pi-hole DNS | `pihole.home` | `192.168.4.53` |
| 104 | `unifi` | UniFi Network App | `unifi.home` | `192.168.4.131` |
| 105 | `n8n` | n8n Workflow Automation | `n8n.home` | `192.168.4.128` |
| 106 | `twingate` | Twingate Connector | `twingate.home` | `192.168.4.129` |
| 107 | `patchmon` | PatchMon | `patchmon.home` | `192.168.4.130` |
| 108 | `homepage` | Homepage dashboard | `homepage.home` | `192.168.4.126` |
| 109 | `teamspeak`| TeamSpeak Server | `teamspeak.home` | `192.168.4.147` |
| 111 | `homebridge` | Homebridge | `homebridge.home` | `192.168.4.166` |
| 112 | `grafana` | Grafana | `grafana.home` | `192.168.4.125` |

(Additional “lab” LXCs are now documented above.)

---

## 4. Creating Unprivileged LXCs

All key LXCs in this build are **unprivileged**, which keeps the host safer.

Example Proxmox LXC options (GUI or CLI) for Ubuntu 24.04:

* **Unprivileged:** ✅
* **Features:** `nesting=1`, `keyctl=1`
* **Root disk:** `local-lvm`, 20–40GB depending on workload
* **CPU:** 2–4 cores
* **RAM:** 2–4GB for lightweight services; 4GB+ for Plex / Arr

### 4.1. Example `102.conf` (Arr)

`/etc/pve/lxc/102.conf`:

```ini
arch: amd64
cores: 2
memory: 4096
swap: 512
hostname: arr
net0: name=eth0,bridge=vmbr0,ip=dhcp,hwaddr=BC:24:11:75:CC:5E,type=veth
ostype: ubuntu
rootfs: local-lvm:vm-102-disk-0,size=20G
unprivileged: 1
onboot: 1
features: nesting=1,keyctl=1
mp0: /mnt/media,mp=/mnt/media

# Important for Docker inside an unprivileged LXC
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/fuse dev/fuse none bind,optional,create=file
```

> ⚠️ **AppArmor gotcha:**
> If you hit `AppArmor enabled on system but the docker-default profile could not be loaded`, switching the CT to `lxc.apparmor.profile: unconfined` (as above) fixes Docker inside the LXC.

Repeat similar configs for other LXCs, adjusting:

* `hostname`
* `rootfs` size
* `mp0` (only Plex and Arr need `/mnt/media`)

---

## 5. Arr LXC (Docker Host) – `/opt/arr`

This is the only LXC that runs Docker and Docker Compose.

### 5.1. Inside `arr`: base setup

```bash
# Update & basic tools
apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg git

# Docker Engine (official repo recommended)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu noble stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker
```

Create an `arr` directory:

```bash
mkdir -p /opt/arr/{qbittorrent,radarr,sonarr,prowlarr,bazarr,overseerr}
cd /opt/arr
```

### 5.2. Docker Compose – `/opt/arr/docker-compose.yml`

See [docker-compose.yml](docker-compose.yml) for the full configuration.

Bring everything up:

```bash
cd /opt/arr
docker compose pull
docker compose up -d
```

Services in `arr`:

* qBittorrent → `http://ARR_IP:8080`
* Radarr → `http://ARR_IP:7878`
* Sonarr → `http://ARR_IP:8989`
* Prowlarr → `http://ARR_IP:9696`
* Bazarr → `http://ARR_IP:6767`
* Overseerr → `http://ARR_IP:5055`

---

## 6. Plex LXC (101)

### 6.1. Bind mount media

`/etc/pve/lxc/101.conf` (key lines):

```ini
mp0: /mnt/media,mp=/mnt/media
unprivileged: 1
features: keyctl=1
```

### 6.2. Plex install (inside 101)

```bash
apt-get update
apt-get install -y curl

# Plex repo
curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor \
  | tee /usr/share/keyrings/plex.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/plex.gpg] https://downloads.plex.tv/repo/deb public main" \
  > /etc/apt/sources.list.d/plexmediaserver.list

apt-get update
apt-get install -y plexmediaserver
systemctl enable plexmediaserver
systemctl start plexmediaserver
```

Then browse to: `http://PLEX_LXC_IP:32400/web`.

In Plex, add libraries mapping to:

* `/mnt/media/movies`
* `/mnt/media/tv`

---

## 7. Pi-hole + Unbound (103)

Pi-hole provides network-wide ad-blocking, Unbound provides a local validating resolver.

### 7.1. Pi-hole install

Inside `pihole`:

```bash
apt-get update
apt-get install -y curl

curl -sSL https://install.pi-hole.net | bash
# follow prompts:
# - Static IP on your LAN
# - Upstream DNS: 127.0.0.1#5335 (Unbound, once configured)
```

### 7.2. Unbound basic config

```bash
apt-get install -y unbound

cat >/etc/unbound/unbound.conf.d/pi-hole.conf <<'EOF'
server:
  verbosity: 1
  interface: 127.0.0.1
  port: 5335
  do-ip4: yes
  do-udp: yes
  do-tcp: yes
  prefer-ip6: no
  root-hints: "/var/lib/unbound/root.hints"
  harden-glue: yes
  harden-dnssec-stripped: yes
  use-caps-for-id: yes
  edns-buffer-size: 1232
  prefetch: yes
  qname-minimisation: yes
EOF

wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
chown unbound:unbound /var/lib/unbound/root.hints

systemctl enable unbound
systemctl restart unbound
```

In Pi-hole’s **DNS settings**, set:

* Upstream DNS server → `127.0.0.1#5335`

Point your **LAN DHCP** (router) and **other LXCs** to use Pi-hole’s IP as DNS.

---

## 8. Homepage Dashboard (108)

Homepage is used as a simple central dashboard, showing:

* Links to Plex, *arr* services, Pi-hole, UniFi, TeamSpeak, etc.
* Patch status summary (see patch script in section 10).

Basic pattern inside `homepage` LXC:

```bash
apt-get update
apt-get install -y curl git nodejs npm

# Example layout (your actual config already exists)
mkdir -p /opt/homepage/config
cd /opt/homepage
# Use your preferred deployment method (container, Node, etc.)

# Example config files:
# /opt/homepage/config/settings.yaml
# /opt/homepage/config/widgets.yaml
```

Make sure Homepage can read any **log files** you expose from the host (e.g. patch summary) via a bind mount or network share.

---

## 9. UniFi Controller (104)

UniFi Network Application in its own LXC.

Inside `unifi`:

```bash
apt-get update
apt-get install -y ca-certificates apt-transport-https openjdk-17-jre-headless

# UniFi repo (check official docs for latest)
echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' \
  > /etc/apt/sources.list.d/ubnt.list

wget -O - https://dl.ui.com/unifi/unifi-repo.gpg | gpg --dearmor \
  | tee /usr/share/keyrings/unifi.gpg >/dev/null

apt-get update
apt-get install -y unifi
systemctl enable unifi
systemctl start unifi
```

Access: `https://UNIFI_LXC_IP:8443`.

---

## 10. Twingate Connector (106)

Zero-trust connector for remote access.

Inside `twingate-connector`:

```bash
apt-get update
apt-get install -y curl

# Twingate official install snippet
curl -s https://binaries.twingate.com/client/linux/install.sh | sudo bash

# Use your network's connector token / configuration
twingate setup
systemctl enable twingate-connector
systemctl start twingate-connector
```

(Replace with the exact command from your Twingate admin portal.)

---

## 11. TeamSpeak Server (109)

Basic outline for a native TeamSpeak server in its own LXC.

Inside `teamspeak-server`:

```bash
apt-get update
apt-get install -y wget tar

useradd -m -d /opt/teamspeak teamspeak
cd /opt/teamspeak

# Download latest server (check TeamSpeak site for URL)
wget https://files.teamspeak-services.com/releases/server/3.13.7/teamspeak3-server_linux_amd64-3.13.7.tar.bz2
tar xjf teamspeak3-server_linux_amd64-3.13.7.tar.bz2 --strip-components=1
chown -R teamspeak:teamspeak /opt/teamspeak
```

Create a systemd unit `/etc/systemd/system/teamspeak.service`:

```ini
[Unit]
Description=TeamSpeak 3 Server
After=network.target

[Service]
Type=forking
User=teamspeak
Group=teamspeak
WorkingDirectory=/opt/teamspeak
ExecStart=/opt/teamspeak/ts3server_startscript.sh start
ExecStop=/opt/teamspeak/ts3server_startscript.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Then:

```bash
systemctl daemon-reload
systemctl enable teamspeak
systemctl start teamspeak
```

Open/forward ports (default 9987/UDP, 10011/TCP, 30033/TCP) on your network firewall as needed.

---

## 12. Automated LXC Patching (Host-side)

To keep everything up to date, the Proxmox host runs a patch script that:

* Checks DNS via Pi-hole (with fallback to 1.1.1.1)
* Iterates over all LXCs with `pct list`
* Runs `apt-get update && upgrade` inside each CT
* **Does not stop on error** – logs failures per CT
* Writes a short summary that Homepage can show via a widget

### 12.1. `/usr/local/bin/patch_all_containers.sh`

See [scripts/patch_all_containers.sh](scripts/patch_all_containers.sh).

Make it executable:

```bash
chmod +x /usr/local/bin/patch_all_containers.sh
```

Example cron entry on the Proxmox host (weekly Sunday 2am):

```bash
crontab -e

0 2 * * SUN /usr/local/bin/patch_all_containers.sh >> /var/log/lxc_patch.cron.log 2>&1
```

You can then expose `/var/log/lxc_patch_summary.log` to your Homepage LXC (read-only bind mount or NFS) and show it via a simple *logs* widget.

---

### 12.2. Proxmox Host Patching (Monthly)
The PVE host itself is patched monthly via a separate script.

See [scripts/patch_pve_host.sh](scripts/patch_pve_host.sh).

Schedule (via `crontab -l` on host):
`0 3 1 * * /usr/local/bin/patch_pve_host.sh >> /var/log/pve_host_patch.cron.log 2>&1`

---

## 13. Disk Monitoring & Auto-Prune (LXC 102)

To prevent the disk from filling up, the `arr` LXC (102) runs a custom monitoring script:
[scripts/media_prune_and_alert.sh](scripts/media_prune_and_alert.sh).

**Logic:**
1.  Checks usage of `/mnt/media`.
2.  **> 85%**: Sends warning alert (ntfy).
3.  **> 90%**: Sends critical alert AND triggers **Auto-Prune**:
    *   **Sonarr**: Deletes seasons older than 60 days (ended series only).
    *   **Radarr**: Deletes unmonitored movies older than 120 days.

**Note on Setup**: The script in this repo has API keys redacted. You must configure them in `/usr/local/bin/media_prune_and_alert.sh` inside the LXC.

---

## 14. Grafana Monitoring (112)

Grafana provides real-time monitoring and visualization of the Proxmox VE host metrics using Prometheus and Node Exporter.

### 14.1. Architecture

* **Grafana LXC (112)**: Dashboard interface at `http://192.168.4.125:3000`
* **Prometheus (PVE Host)**: Time-series database running on port 9090
* **Node Exporter (PVE Host)**: System metrics exporter on port 9100

### 14.2. Installation on PVE Host

Inside the Proxmox host (192.168.4.42):

```bash
# Install Prometheus and Node Exporter
apt-get update
apt-get install -y prometheus prometheus-node-exporter

# Enable and start services
systemctl enable prometheus prometheus-node-exporter
systemctl start prometheus prometheus-node-exporter

# Verify services are running
systemctl status prometheus
systemctl status prometheus-node-exporter
```

### 14.3. Prometheus Configuration

The default Prometheus configuration at `/etc/prometheus/prometheus.yml` includes:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

### 14.4. Grafana Data Source Setup

1. Log into Grafana at `http://192.168.4.125:3000`
2. Navigate to **Connections** → **Data sources** → **Add new connection**
3. Select **Prometheus**
4. Configure:
   * **URL**: `http://192.168.4.42:9090`
   * **Access**: Server (default)
   * **Authentication**: None
5. Click **Save & Test** to verify connection

### 14.5. Import Node Exporter Dashboard

1. Go to **Dashboards** → **New** → **Import**
2. Enter dashboard ID: **1860** (Node Exporter Full)
3. Click **Load**
4. Select the Prometheus data source
5. Click **Import**

The dashboard will display:
* CPU usage and load
* Memory and SWAP usage
* Disk space and I/O
* Network traffic
* System uptime

### 14.6. Access URLs

* Grafana: `http://192.168.4.125:3000`
* Prometheus: `http://192.168.4.42:9090`
* Node Exporter Metrics: `http://192.168.4.42:9100/metrics`

---

## 15. Troubleshooting Notes

A few “war story” gotchas that are now encoded into this design:

* **Unprivileged LXC + immutable files**
  If an LXC refuses to start and logs show something like:
  `close (rename) atomic file '/etc/resolv.conf' failed: Operation not permitted`
  check for immutable flags from the host:

  ```bash
  pct mount 102
  lsattr /var/lib/lxc/102/rootfs/etc/resolv.conf
  chattr -i /var/lib/lxc/102/rootfs/etc/resolv.conf
  pct unmount 102
  ```
* **Don’t chown LXC rootfs to `root:root` on the host**
  For unprivileged LXCs, host paths should be owned by `100000:100000` (or higher ranges).
  Changing these to `root:root` can cause `Operation not permitted` during `apt` or `dpkg`.
* **Docker + AppArmor in an unprivileged LXC**
  If Docker can’t create or load the `docker-default` AppArmor profile, set
  `lxc.apparmor.profile: unconfined` in the CT config and restart the container.
* **Port checks**
  When in doubt, from the **arr** LXC:

  ```bash
  ss -tlnp | egrep '8080|7878|8989|9696|6767|5055'
  curl -I http://127.0.0.1:8989
  ```

  and from the host:

  ```bash
  curl -I http://ARR_IP:8989
  ```

---

## 15. Home Assistant (VMID 100)

Home Assistant OS runs as a VM (`haos`, `192.168.4.136`), exposed externally via Nabu Casa.

See [docs/home-assistant.md](docs/home-assistant.md) for full setup details.

**Tesla Fleet integration** — Model 3 *Tessie* connected via the native `tesla_fleet` integration with 88 entities (battery, charging, climate, locks, location, etc.). A custom component (`homeassistant/custom_components/tesla_public_key/`) serves the Tesla public key at the required `/.well-known/appspecific/com.tesla.3p.public-key.pem` path via Nabu Casa.

---

## 16. Future Ideas

Things you can easily extend from here:

* Add **n8n**, **Homebridge**, **Immich**, etc. as first-class documented services.
* Add a **Service Map** diagram and expose additional metrics to Homepage.
* Add **pve-exporter** to Prometheus for VM/CT-specific metrics and import Proxmox dashboard (ID 10048).
* Configure **Grafana alerts** for high CPU/RAM usage with notification channels.
* Integrate **Pi-hole and Docker** logs into Grafana using Loki.
* Back up key config paths (`/etc`, `/opt/arr`, `/var/lib/pihole`, `/mnt/media`) via Proxmox backups + restic / rclone.

---

Happy tinkering 🧪
This README reflects the current working state of the lab: Proxmox host, Plex + Arr on shared `/mnt/media`, Pi-hole/Unbound DNS, UniFi, Twingate, TeamSpeak, Grafana monitoring and a Homepage dashboard tying it all together.

```




**Disk Space Toolbox**

---

## 📌 1. Overall disk space (top-level)

**This is your first check, always.**

```bash
df -h /mnt/media
```

---

## 📌 2. What’s consuming space (top folders)

**Shows where the space is actually going.**

```bash
du -h --max-depth=1 /mnt/media | sort -h
```

---

## 📌 3. TV library breakdown (per series)

**Best command you ran today.**

```bash
du -h --max-depth=1 /mnt/media/tv | sort -h
```

---

## 📌 4. Largest series only (quick focus)

```bash
du -h --max-depth=1 /mnt/media/tv/* | sort -h | tail
```

---

## 📌 5. Downloads cleanup view

**See what’s safe to delete.**

```bash
du -h --max-depth=1 /mnt/media/downloads | sort -h
```

---

## 📌 6. Find large files anywhere (emergency)

```bash
find /mnt/media -type f -size +5G -exec ls -lh {} \; | sort -k5 -h
```

---

## 📌 7. Check incomplete downloads

```bash
ls -lah /mnt/media/downloads/incomplete
```

---

## 📌 8. Remove empty folders (safe housekeeping)

```bash
find /mnt/media -type d -empty -delete
```

---

## 📌 9. Check for deleted-but-still-open files

(When space doesn’t free after deletes)

```bash
lsof | grep /mnt/media | grep deleted
```

---

## 📌 10. Flush writes after heavy deletes (good practice)

```bash
sync
```

---

## 🧠 **One-line “health check” (bookmark this)**

```bash
df -h /mnt/media && du -h --max-depth=1 /mnt/media/tv | sort -h
```

This tells you in **one glance**:

* Are we safe?
* What’s growing?

---

## 🛡️ Suggested personal rules (based on today)

* ⚠️ **85%** → review
* 🚨 **90%** → delete / trim
* ❌ **100%** → emergency mode (what you just handled)

---

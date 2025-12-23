

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
* Only `LXC 102 (arr)` runs **Docker**; all other services run *natively* in their own LXCs.
* Pi-hole + Unbound provide DNS for the lab.
* Homepage pulls everything together into a simple dashboard.

---

## 2. Proxmox Host Setup

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

| VMID | Name                 | Purpose                                   | Notes                                 |
| ---- | -------------------- | ----------------------------------------- | ------------------------------------- |
| 101  | `plex`               | Plex Media Server                         | Reads from `/mnt/media`               |
| 102  | `arr`                | Docker host for qBittorrent + *arr stack* | Only LXC that runs Docker             |
| 103  | `pihole`             | Pi-hole + Unbound recursive DNS           | DNS for lab + blocking                |
| 104  | `unifi`              | UniFi Network Application                 | Manages network gear                  |
| 105  | `n8n`                | n8n Workflow Automation                   | Low-code automation                   |
| 106  | `twingate-connector` | Twingate zero-trust connector             | Remote access                         |
| 107  | `patchmon`           | Patch Monitor                             | Updates & Monitoring                  |
| 108  | `homepage`           | Homepage dashboard                        | Reads summary logs, links to services |
| 109  | `teamspeak-server`   | TeamSpeak voice server                    | Voice/chat for the family             |
| 110  | `homebridge`         | Homebridge                                | Apple HomeKit integration             |
| 111  | `immich`             | Immich                                    | Self-hosted photo backup              |
| 112  | `grafana`            | Grafana                                   | Metrics & Dashboards                  |

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

## 14. Troubleshooting Notes

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

## 14. Future Ideas

Things you can easily extend from here:

* Add **n8n**, **Homebridge**, **Immich**, etc. as first-class documented services.
* Add a **Service Map** diagram and expose additional metrics to Homepage.
* Integrate **Proxmox, Pi-hole and Docker** logs into a central observability stack (e.g. Loki + Grafana in another LXC).
* Back up key config paths (`/etc`, `/opt/arr`, `/var/lib/pihole`, `/mnt/media`) via Proxmox backups + restic / rclone.

---

Happy tinkering 🧪
This README reflects the current working state of the lab: Proxmox host, Plex + Arr on shared `/mnt/media`, Pi-hole/Unbound DNS, UniFi, Twingate, TeamSpeak and a Homepage dashboard tying it all together.

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

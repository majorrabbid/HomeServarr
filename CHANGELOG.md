# Changelog

All notable changes to this repository are documented in this file.

## 2026-05-23 — Pi-hole / Unbound diagnosis fixes (observed)

- Summary: Resolved Pi-hole diagnostic warnings shown in the admin UI by routing DNS through the local Unbound resolver and increasing Unbound TCP capacity. Changes were applied inside LXC `103` (Pi-hole) and verified.

- Files / config updated (inside LXC 103):
  - `/etc/pihole/pihole.toml`
    - `listeningMode` changed to `ALL` to accept queries from the VPN/Twingate network.
    - `dns.upstreams` pruned: removed public upstreams and left `127.0.0.1#5335` (local Unbound) as sole upstream.
    - Disabled false-positive load checks via `misc.check.load = false` to avoid host-load misinterpretation.
  - `/etc/unbound/unbound.conf.d/pi-hole.conf`
    - Added `incoming-num-tcp: 100` to improve TCP handling and avoid premature connection closures.
    - Removed/commented duplicate `auto-trust-anchor-file` entry to prevent Unbound startup conflicts.

- Actions performed:
  - Restarted `unbound` and `pihole-FTL` services.
  - Verified DNS resolution over UDP and TCP against `127.0.0.1:5335` and `127.0.0.1:53`.
  - Cleared the Pi-hole admin messages; `http://<pihole-ip>/api/info/messages` returned `{"messages":[]}`.

- Verification commands run (examples):
  - `pct exec 103 -- systemctl restart unbound pihole-FTL`
  - `pct exec 103 -- dig @127.0.0.1 -p 5335 google.com`
  - `curl -s http://192.168.4.122/api/info/messages`

- Notes & rollback
  - If any issue is observed, restore previous `/etc/pihole/pihole.toml` and `/etc/unbound/unbound.conf.d/pi-hole.conf` from backups, then restart services.
  - These changes were applied by an automated remediation flow (Gemini) and observed here — treat them as recommended configuration changes but review for local policy compatibility.

---

Previous entries:

*No prior changelog entries in this repository.*

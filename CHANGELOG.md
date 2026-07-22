# Changelog

All notable changes to this repository are documented in this file.

## 2026-07-22 — OpenClaw CT114 migrated to non-root user

- Summary: Migrated the OpenClaw gateway on LXC 114 from `root` to an unprivileged `openclaw` user. Fixes the dashboard chat which was crashing every turn with `--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons`. Adds defence in depth — a compromised Claude subprocess is bounded to the `openclaw` user, not container root.
- Files / config changed (inside LXC 114):
  - `/etc/systemd/system/openclaw-gateway.service` → `User=openclaw`, `HOME=/home/openclaw`, `WorkingDirectory=/home/openclaw`, logs under `/home/openclaw/.openclaw/logs/`.
  - New drop-ins under `/etc/systemd/system/openclaw-gateway.service.d/`:
    - `systemd-handoff.conf` — sets `OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service`.
    - `restart-always.conf` — `Restart=always` safety net for clean exits.
  - `/etc/profile.d/claude-oauth.sh` repointed to `/home/openclaw/.openclaw/secrets/`.
- State moved: `/root/.openclaw` → `/home/openclaw/.openclaw` and `/root/.claude` → `/home/openclaw/.claude`, then `chown -R openclaw:openclaw`. Also cleared leftover UID 502 ownership from the earlier Mac→CT114 rsync.
- Cached `/root/...` paths rewritten in gateway state:
  - JSON: `sessions.json`, `*.trajectory-path.json`, `openclaw.json`.
  - SQL: `agent_model_catalogs.agent_dir/raw_json`, `installed_plugin_index.*_json`, `agent_databases.path`, `config_health_entries.config_path` (deduplicated by removing stale `/Users/sunny/...` and `/root/...` rows).
- Claude Code auth: switched from `CLAUDE_CODE_OAUTH_TOKEN` env var (OpenClaw strips it before spawning Claude) to `~/.claude/.credentials.json` via interactive `claude auth login` under the `openclaw` user.
- Updated 2026.6.11 → 2026.7.1-2 via `openclaw update --yes` from the root shell after stopping the unit.
- New docs: `docs/openclaw-ct114.md`.
- Known limitation left in place: dashboard "Update" button fails (`managed-service-handoff-unavailable`) because the handoff assumes a systemd user unit (`systemctl --user`, `systemd-run --user`) and CT114 runs a system unit. Deferred; CLI updates work.

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

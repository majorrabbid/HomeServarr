# OpenClaw on CT114

OpenClaw (Jarvis) runs on **LXC 114 `openclaw`** at `192.168.4.135`. This is the single always-on gateway for chat surfaces (dashboard, Telegram, Signal) and skill orchestration.

| | |
|---|---|
| **LXC** | 114 · `openclaw` · Ubuntu 24.04 |
| **Address** | `openclaw.home` · `192.168.4.135` |
| **Runs as** | user `openclaw` (unprivileged) |
| **Gateway** | `openclaw-gateway.service` on port `18789` |
| **HTTPS front** | Caddy on `:443`, mkcert-signed cert |
| **Dashboard URL** | `https://192.168.4.135/#token=<gateway_token>` |

---

## Why non-root

Claude Code (the underlying CLI backend OpenClaw uses for chat) refuses to run with `--dangerously-skip-permissions` under root. OpenClaw launches Claude with that flag whenever the exec policy is set to YOLO (`security: full`, `ask: off`), so a root-owned gateway crashes every chat turn with:

```
--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons
```

Migrating to an unprivileged user fixes that and adds defence in depth — a compromised Claude subprocess is bounded to the `openclaw` user, not container root.

---

## Layout

```
/home/openclaw/
├── .openclaw/                          # gateway state (was /root/.openclaw)
│   ├── openclaw.json                   # gateway config
│   ├── workspace/                      # Jarvis workspace (AGENTS, MEMORY, SOUL, etc.)
│   ├── secrets/                        # ha_token, pihole_password, claude_oauth_token, …
│   ├── state/openclaw.sqlite           # gateway state store
│   ├── agents/main/agent/…             # per-agent runtime state
│   ├── logs/gateway.{log,error.log}    # append-only logs
│   └── identity/                       # device identity (see caveats)
└── .claude/                            # Claude Code state
    ├── .credentials.json               # OAuth creds (read by OpenClaw)
    └── projects/                       # per-workspace session transcripts
```

`/etc/systemd/system/openclaw-gateway.service` — main unit
`/etc/systemd/system/openclaw-gateway.service.d/` — drop-ins:
- `claude-auth.conf` — legacy env var (vestigial, kept for direct-CLI use)
- `systemd-handoff.conf` — sets `OPENCLAW_SYSTEMD_UNIT`
- `restart-always.conf` — `Restart=always` (safety net for clean exits)

`/etc/caddy/Caddyfile` — HTTPS front, reverse-proxies `127.0.0.1:18789`
`/etc/caddy/certs/openclaw.{crt,key}` — mkcert cert (valid to Oct 2028)
`/etc/profile.d/claude-oauth.sh` — exports `CLAUDE_CODE_OAUTH_TOKEN` in login shells (for manual `claude` runs; the gateway ignores it — see below)

---

## Auth model

### Dashboard / operator token

`gateway.auth.token` in `openclaw.json`. Read it with:

```bash
ssh root@192.168.4.42 pct exec 114 -- \
  python3 -c 'import json; print(json.load(open("/home/openclaw/.openclaw/openclaw.json"))["gateway"]["auth"]["token"])'
```

Bookmark: `https://192.168.4.135/#token=<token>`

### Claude Code (the LLM behind chat)

⚠️ **Gotcha:** OpenClaw's `claude-cli` backend explicitly strips `CLAUDE_CODE_OAUTH_TOKEN` (and all `ANTHROPIC_*` env vars) from Claude's environment. See `CLAUDE_CLI_CLEAR_ENV` in `openclaw/dist/cli-shared-*.js`. Instead, it reads OAuth credentials from **`~/.claude/.credentials.json`**, which is only created by interactive `claude auth login` — `claude setup-token` does not create it.

**To (re-)authenticate Claude:**

```bash
ssh -t root@192.168.4.42 pct exec 114 -- su - openclaw -c 'claude auth login'
```

You'll get a URL — open it in a browser, authorise, paste the code back. This writes `/home/openclaw/.claude/.credentials.json`. OpenClaw's `anthropic:claude-cli` profile auto-refreshes from it.

⚠️ The auth URL is long enough to wrap in most terminals. If your browser reports "Unknown scope: user:infe" (or similar), you copied a wrapped URL — grab it as a single line before opening.

Verify:

```bash
ssh root@192.168.4.42 pct exec 114 -- \
  sudo -u openclaw -i openclaw models auth list
# Expected: anthropic:claude-cli [anthropic/oauth; expires <future date>]
```

### Home Assistant (via MCP)

Long-lived access token in `/home/openclaw/.openclaw/secrets/ha_token`, wired into `openclaw.json` under `mcp.servers.homeassistant`:

```json
{
  "url": "http://192.168.4.136:8123/mcp_server/sse",
  "transport": "sse",
  "headers": { "Authorization": "Bearer <JWT>" }
}
```

Exposes `HassTurnOn/Off`, `HassLightSet`, `GetLiveContext`, etc. Only entities exposed to HA's Assist pipeline are visible to the MCP tools.

---

## Common operations

### Read logs (live)

```bash
ssh root@192.168.4.42 pct exec 114 -- \
  tail -f /home/openclaw/.openclaw/logs/gateway.log
```

### Restart the gateway

```bash
ssh root@192.168.4.42 pct exec 114 -- systemctl restart openclaw-gateway
```

### Update OpenClaw

The dashboard **Update** button currently doesn't work on this host (see limitations). Update from the CLI as root:

```bash
ssh root@192.168.4.42 'pct exec 114 -- bash -c "
  systemctl stop openclaw-gateway &&
  openclaw update --yes &&
  systemctl start openclaw-gateway
"'
```

The `openclaw update` output ends with `Gateway: restart skipped (no installed service found)` — that's normal; we restart manually via the surrounding systemctl calls because OpenClaw doesn't detect the system unit.

### Rotate the gateway operator token

```bash
ssh root@192.168.4.42 pct exec 114 -- \
  openclaw gateway auth rotate
# then update ~/.openclaw/secrets/openclaw_gateway_token on the Mac
```

### Rotate the Home Assistant token

Regenerate a long-lived token in HA UI → paste into `/home/openclaw/.openclaw/secrets/ha_token` and update `openclaw.json` MCP header → restart the gateway.

---

## Known limitations

### Dashboard "Update now" button doesn't work

Fails with `managed-service-handoff-unavailable` or exits cleanly without respawning. Root cause: OpenClaw's managed-service handoff was designed for **systemd user units** (`systemctl --user`, `systemd-run --user`) and CT114 runs a **system unit**. The two supervisor models are not interchangeable.

Fix would be to migrate to a user unit under `openclaw` with `loginctl enable-linger openclaw`. Deferred — updates via the CLI recipe above are fine for our cadence. `Restart=always` is set as a safety net so a clean-exit crash gets respawned.

### `dangerouslyDisableDeviceAuth: true` is on

The migrated device identity (`/home/openclaw/.openclaw/identity/device.json`) doesn't match what the gateway expects after the platform change (linux vs the original darwin issuance). Chicken-and-egg: the CLI approval path can't approve itself when the identity is rejected. Break-glass workaround: `gateway.controlUi.dangerouslyDisableDeviceAuth: true` in `openclaw.json`. Risk is contained (LAN-only, HTTPS, token-gated) but should be root-caused and turned off.

### Signal channel not registered

`signal-cli: User +61492194172 is not registered` in logs every ~30s. Signal was working on the Mac; the account state didn't migrate cleanly. Signal on CT114 needs re-linking or a fresh registration. Telegram is the primary phone channel now (working as of 2026-07-22).

---

## Rebuild from scratch

If CT114 needs to be rebuilt:

1. Provision LXC (Ubuntu 24.04, ≥1 GB RAM, static `192.168.4.135`).
2. `apt install -y nodejs npm sqlite3 caddy` (Node ≥20).
3. `npm install -g openclaw`.
4. `useradd -m -s /bin/bash openclaw`.
5. Restore `/home/openclaw/.openclaw/` and `/home/openclaw/.claude/` from backup (or start fresh and re-auth everything).
6. Install `openclaw-gateway.service` + drop-ins (see this doc's Layout section for what to put in each file).
7. `mkcert` certificate to `/etc/caddy/certs/openclaw.{crt,key}` (SANs: IP + `openclaw.home`).
8. Install the Caddyfile above.
9. `systemctl daemon-reload && systemctl enable --now openclaw-gateway caddy`.
10. `su - openclaw -c 'claude auth login'` to seed Claude credentials.
11. Add `openclaw.home → 192.168.4.135` to Pi-hole custom DNS.

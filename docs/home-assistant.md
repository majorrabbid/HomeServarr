# Home Assistant

Home Assistant OS runs as VM 100 (`haos`) on the Proxmox host.

| | |
|---|---|
| **Local address** | `homeassistant.home` · `192.168.4.136` |
| **Remote access** | Nabu Casa — `rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa` |
| **Integration** | Native `tesla_fleet` (not HACS) |

---

## Tesla Fleet Integration

### Overview

The native HA `tesla_fleet` integration connects a Tesla Model 3 named *Tessie* (VIN `LRW3F7EK8NC684538`). It provides 88 entities covering:

- **Battery & charging** — level, rate, limit, current, voltage, energy added, time to full
- **Climate** — HVAC on/off, temperature, cabin overheat protection, defrost, seat heaters
- **Location** — GPS tracker, active route, distance and time to arrival
- **Security** — door lock, charge cable lock, sentry mode, dashcam
- **Covers** — frunk, trunk, windows, charge port, sunroof
- **Controls** — wake, flash lights, honk, HomeLink, media player
- **Diagnostics** — odometer, tyre pressure, inside/outside temperature, shift state, speed

### How the Tesla Fleet API works

Three things are required before the integration can function:

1. **Developer application** — registered at `developer.tesla.com` with your Nabu Casa domain as the allowed origin
2. **Public key** — served at `/.well-known/appspecific/com.tesla.3p.public-key.pem` on that domain so Tesla can verify you control it
3. **OAuth token** — granted by the Tesla mobile app, authorising HA to read vehicle data
4. **Virtual key** — NFC-paired to the car, required before HA can *send* commands

Steps 1–3 are complete. Step 4 is the remaining TODO.

---

## Public Key Hosting

### The problem

HA has no built-in way to serve a file at an arbitrary HTTP path like `/.well-known/...`. The `www/` folder only serves content at `/local/`, and Nabu Casa proxies directly to HA's HTTP server — there is no intermediate Nginx to configure.

### The solution

A minimal custom component (`tesla_public_key`) registers an unauthenticated `aiohttp` view on HA's own HTTP server at exactly the path Tesla requires. Because Nabu Casa forwards every request to HA, the key is reachable publicly with no extra configuration.

**Component location in this repo:** `homeassistant/custom_components/tesla_public_key/`

**Deployed to HA at:** `/config/custom_components/tesla_public_key/`

**Activated by** adding to `/config/configuration.yaml`:
```yaml
tesla_public_key:
```

**Verify it's working:**
```bash
curl https://rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa/.well-known/appspecific/com.tesla.3p.public-key.pem
```

Expected response:
```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE4hEFAKOht9LwCipSmwRddTaiPKIW
x2BQVlbomVihteaArbU8coISxzRlA2YCkzPpYYmlB6HatiKRlcZmRCnf0w==
-----END PUBLIC KEY-----
```

### Tesla developer app details

| Field | Value |
|-------|-------|
| Client ID | `9098cd9a-96be-444b-9c81-3deb0481bb10` |
| Domain | `rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa` |

---

## Virtual Key Pairing ⚠️ TODO

### What it unlocks

Without the virtual key, HA can read all vehicle data and control charging, but **cannot send any other commands**. Commands that require the virtual key:

| Command | Entity |
|---------|--------|
| Lock / unlock doors | `lock.tessie_lock` |
| Climate on / off | `climate.tessie_climate` |
| Set temperature | `climate.tessie_climate` |
| Defrost | `switch.tessie_defrost` |
| Seat heaters | `select.tessie_seat_heater_*` |
| Open frunk | `cover.tessie_frunk` |
| Open / close trunk | `cover.tessie_trunk` |
| Vent / close windows | `cover.tessie_windows` |
| Flash lights | `button.tessie_flash_lights` |
| Honk horn | `button.tessie_honk_horn` |

### How to pair

> **Requires physical proximity to *Tessie*.**

1. In HA, go to **Settings → Devices & Services → Tesla Fleet**
2. Click **Configure** on the integration entry
3. Select **Add key to vehicle** — HA generates a pairing link
4. Open the link in the **Tesla mobile app** on your phone
5. The app will prompt you to hold your phone near the car
6. Tap your phone to the **NFC reader on the center console** (top of the armrest)
7. The car will confirm the key has been added

Once paired, all command entities will become controllable immediately — no HA restart required.

### Verify pairing worked

Try toggling `switch.tessie_charge` or calling `button.tessie_honk_horn` from the HA Developer Tools. If you no longer see the "key not set up" error, pairing is complete.

---

## SSH Add-on

The **Terminal & SSH** add-on (`core_ssh`) has port 22 exposed on the host with the following keys authorised:

| Key | Comment | Passphrase |
|-----|---------|------------|
| `id_ed25519.pub` | `psl@lakhiyan.com` | Yes (use ssh-agent) |
| `id_rsa` (ed25519 type) | `claude-code-proxmox` | No |

Connect from the Mac:
```bash
ssh root@homeassistant.local
```

If connecting from a fresh shell without the agent loaded, use the unencrypted key explicitly:
```bash
ssh -i ~/.ssh/id_rsa root@homeassistant.local
```

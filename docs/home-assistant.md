# Home Assistant (VMID 100 – `haos`)

Home Assistant OS running as a VM on Proxmox at `192.168.4.136`, accessible externally via Nabu Casa at `rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa`.

---

## Tesla Fleet Integration

### Overview

Uses the **native HA `tesla_fleet` integration** (not HACS) to connect a Tesla Model 3 named *Tessie* (VIN `LRW3F7EK8NC684538`). Provides 88 entities covering battery, charging, climate, locks, doors, location, seat heaters, media player, and more.

### How it works

Tesla Fleet API requires:
1. A **developer application** registered at developer.tesla.com with your Nabu Casa domain
2. A **public key** hosted at `/.well-known/appspecific/com.tesla.3p.public-key.pem` on that domain
3. **OAuth authentication** via the Tesla mobile app
4. A **virtual key** paired to the car (for sending commands)

### Public key hosting

HA has no native way to serve files at arbitrary HTTP paths. The solution is a tiny custom component (`tesla_public_key`) that registers an unauthenticated HTTP view directly with HA's aiohttp server. Since Nabu Casa transparently proxies all requests to HA's HTTP server, the key is reachable at the Nabu Casa URL.

The component lives at `homeassistant/custom_components/tesla_public_key/` in this repo and is deployed to `/config/custom_components/tesla_public_key/` on the HA instance.

To activate, `configuration.yaml` must include:

```yaml
tesla_public_key:
```

Verify the endpoint is live:

```bash
curl https://rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa/.well-known/appspecific/com.tesla.3p.public-key.pem
```

### Tesla developer app

- **Client ID:** `9098cd9a-96be-444b-9c81-3deb0481bb10`
- **Domain:** `rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa`
- **Public key URL:** `https://rn8i7mtiv83lqfhsmqb856s6wq86wgge.ui.nabu.casa/.well-known/appspecific/com.tesla.3p.public-key.pem`

### Key entities

| Entity | Description |
|--------|-------------|
| `sensor.tessie_battery_level` | Battery % |
| `sensor.tessie_charging` | Charging state |
| `number.tessie_charge_limit` | Charge limit (50–100%) |
| `switch.tessie_charge` | Start/stop charging |
| `climate.tessie_climate` | HVAC control |
| `lock.tessie_lock` | Door lock |
| `device_tracker.tessie_location` | GPS location |
| `cover.tessie_frunk` / `trunk` | Frunk and trunk |

### Command sending (virtual key)

Reading sensor data works with OAuth alone. Sending commands (climate, locks, etc.) requires a **virtual key** paired to the car via NFC:

1. In HA go to **Settings → Devices & Services → Tesla Fleet → Configure**
2. Follow the "Add key to vehicle" flow — it generates a pairing link
3. Open the link in the Tesla mobile app
4. Tap your phone to the car's NFC reader (center console) to complete pairing

> Charging controls (`switch.tessie_charge`, `number.tessie_charge_limit`) may work without the virtual key on some firmware versions — test first before doing the NFC pairing.

---

## SSH Add-on

The **Terminal & SSH** add-on (core_ssh) has port 22 mapped to the host and the following authorized keys configured:

- `psl@lakhiyan.com` (main Mac key — ed25519, passphrase-protected)
- `claude-code-proxmox` (Claude Code automation key — ed25519, no passphrase)

Connect from the Mac:

```bash
ssh root@homeassistant.local
```

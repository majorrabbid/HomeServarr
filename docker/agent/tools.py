"""
Jarvis tool implementations.
Each tool either SSHes into Proxmox or calls a local service API.
"""
import asyncio
import os
import httpx

PROXMOX_HOST = os.environ.get("PROXMOX_HOST", "192.168.4.42")
PROXMOX_USER = os.environ.get("PROXMOX_USER", "root")
SSH_KEY = os.environ.get("SSH_KEY_PATH", "/home/jarvis/.ssh/identity.rsa")

OVERSEERR_URL = os.environ.get("OVERSEERR_URL", "http://192.168.4.124:5055")
OVERSEERR_API_KEY = os.environ.get("OVERSEERR_API_KEY", "")

SONARR_URL = os.environ.get("SONARR_URL", "http://192.168.4.124:8989")
RADARR_URL = os.environ.get("RADARR_URL", "http://192.168.4.124:7878")

# Tool schemas passed to Claude
TOOLS = [
    {
        "name": "run_health_check",
        "description": (
            "Run the health_check.sh script on the Proxmox host. "
            "Returns status of all LXC containers, disk usage, and key services."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "patch_containers",
        "description": (
            "Run apt upgrades across all LXC containers on the Proxmox host. "
            "Always defaults to dry_run=true unless the user explicitly says to proceed."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "dry_run": {
                    "type": "boolean",
                    "description": "If true, show what would be upgraded without making changes. Default: true.",
                }
            },
            "required": [],
        },
    },
    {
        "name": "get_disk_usage",
        "description": "Get disk usage for /mnt/media on the Proxmox host.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "request_media",
        "description": "Search Overseerr and submit a request for a movie or TV show.",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Title of the movie or TV show.",
                },
                "media_type": {
                    "type": "string",
                    "enum": ["movie", "tv"],
                    "description": "Whether this is a movie or a TV show.",
                },
            },
            "required": ["title", "media_type"],
        },
    },
    {
        "name": "get_service_status",
        "description": (
            "Check HTTP reachability of key home lab services: "
            "Overseerr, Sonarr, Radarr, Plex, Prowlarr, Bazarr, Pi-hole, Grafana, Homepage."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "list_containers",
        "description": "List all LXC containers on the Proxmox host with their status and IP addresses.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
]


async def run_tool(name: str, inputs: dict) -> str:
    if name == "run_health_check":
        return await _ssh(
            "bash /opt/homeservarr/scripts/health_check.sh 2>&1 | tail -60"
        )
    if name == "patch_containers":
        dry_run = inputs.get("dry_run", True)
        env = "PATCH_DRY_RUN=1" if dry_run else "PATCH_DRY_RUN=0"
        return await _ssh(
            f"{env} bash /opt/homeservarr/scripts/patch_all_containers.sh 2>&1 | tail -60"
        )
    if name == "get_disk_usage":
        return await _ssh(
            "df -h /mnt/media; echo '---'; du -sh /mnt/media/* 2>/dev/null | sort -rh | head -15"
        )
    if name == "request_media":
        return await _overseerr_request(inputs["title"], inputs["media_type"])
    if name == "get_service_status":
        return await _check_services()
    if name == "list_containers":
        return await _ssh("pct list 2>&1")
    return f"Unknown tool: {name}"


async def _ssh(command: str, timeout: int = 60) -> str:
    cmd = [
        "ssh",
        "-i", SSH_KEY,
        "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes",
        "-o", f"ConnectTimeout=10",
        f"{PROXMOX_USER}@{PROXMOX_HOST}",
        command,
    ]
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        output = stdout.decode(errors="replace").strip()
        return output[:3000] if output else "(no output)"
    except asyncio.TimeoutError:
        return f"SSH command timed out after {timeout}s"
    except Exception as e:
        return f"SSH error: {e}"


async def _overseerr_request(title: str, media_type: str) -> str:
    if not OVERSEERR_API_KEY:
        return "OVERSEERR_API_KEY not configured."
    headers = {"X-Api-Key": OVERSEERR_API_KEY, "Content-Type": "application/json"}
    async with httpx.AsyncClient(timeout=15) as client:
        try:
            search = await client.get(
                f"{OVERSEERR_URL}/api/v1/search",
                params={"query": title, "page": 1},
                headers=headers,
            )
            search.raise_for_status()
            results = search.json().get("results", [])
            if not results:
                return f"No results found for '{title}'"

            # Prefer matching media type
            match = next(
                (r for r in results if r.get("mediaType") == media_type),
                results[0],
            )
            media_id = match["id"]
            found_type = match.get("mediaType", media_type)
            found_title = match.get("title") or match.get("name", title)

            # Check existing status (2=pending,3=processing,4=partial,5=available)
            existing_status = match.get("mediaInfo", {}).get("status")
            if existing_status in (2, 3, 4, 5):
                status_map = {2: "pending", 3: "processing", 4: "partially available", 5: "available"}
                return f"'{found_title}' is already {status_map.get(existing_status, 'requested')}."

            payload: dict = {"mediaType": found_type, "mediaId": media_id}
            if found_type == "tv":
                payload["seasons"] = "all"

            req = await client.post(
                f"{OVERSEERR_URL}/api/v1/request",
                json=payload,
                headers=headers,
            )
            req.raise_for_status()
            return f"Requested '{found_title}' successfully via Overseerr."
        except httpx.HTTPStatusError as e:
            return f"Overseerr error {e.response.status_code}: {e.response.text[:300]}"
        except Exception as e:
            return f"Request failed: {e}"


async def _check_services() -> str:
    services = {
        "Overseerr":  f"{OVERSEERR_URL}",
        "Sonarr":     f"{SONARR_URL}",
        "Radarr":     f"{RADARR_URL}",
        "Plex":       "http://192.168.4.101:32400/web",
        "Prowlarr":   "http://192.168.4.124:9696",
        "Bazarr":     "http://192.168.4.124:6767",
        "Pi-hole":    "http://192.168.4.53/admin",
        "Grafana":    "http://192.168.4.112:3000",
        "Homepage":   "http://192.168.4.108:3000",
        "n8n":        "http://192.168.4.105:5678",
        "UniFi":      "http://192.168.4.104:8443",
    }
    lines = []
    async with httpx.AsyncClient(timeout=5, verify=False) as client:
        for name, url in services.items():
            try:
                resp = await client.get(url, follow_redirects=True)
                ok = resp.status_code < 500
                lines.append(f"{'OK' if ok else 'WARN'} {name} ({resp.status_code})")
            except Exception:
                lines.append(f"DOWN {name}")
    return "\n".join(lines)

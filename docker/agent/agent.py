"""
Jarvis agentic loop — Claude API with tool use.
Maintains per-sender conversation history.
"""
import logging
import os
import anthropic
from tools import TOOLS, run_tool

log = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are Jarvis, the AI assistant for a Proxmox home lab.

The home lab runs on a single Proxmox VE host (192.168.4.42) with these LXC containers:
- 100: Home Assistant OS (haos)
- 101: Plex Media Server
- 102: arr stack (Radarr, Sonarr, Prowlarr, Bazarr, Overseerr, qBittorrent) via Docker
- 103: Pi-hole + Unbound DNS
- 104: UniFi network controller
- 105: n8n workflow automation
- 108: Homepage dashboard
- 112: Grafana + Prometheus

Your capabilities:
- Run health checks on the Proxmox host and containers
- Patch (update) all LXC containers — always dry-run first unless user confirms
- Check disk usage on /mnt/media
- Request movies and TV shows via Overseerr
- Check status of all home lab services
- List running containers

Rules:
- Keep responses short — this is Signal on a phone. Under 200 words.
- Plain text only, no markdown formatting.
- For patching: always confirm dry-run first. Never run live patch without explicit user approval.
- For media requests: confirm what you found before submitting if the match seems uncertain.
- If a tool fails, report the error clearly and suggest next steps.
"""

MAX_HISTORY = 20  # turns per sender before trimming


class JarvisAgent:
    def __init__(self):
        self.client = anthropic.AsyncAnthropic(
            api_key=os.environ["ANTHROPIC_API_KEY"]
        )
        self.model = os.environ.get("CLAUDE_MODEL", "claude-sonnet-4-6")
        self._history: dict[str, list] = {}

    async def chat(self, sender: str, user_message: str) -> str:
        history = self._history.setdefault(sender, [])
        history.append({"role": "user", "content": user_message})

        # Trim to keep context manageable
        if len(history) > MAX_HISTORY:
            self._history[sender] = history[-MAX_HISTORY:]
            history = self._history[sender]

        messages = list(history)

        while True:
            resp = await self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                system=SYSTEM_PROMPT,
                tools=TOOLS,
                messages=messages,
            )

            if resp.stop_reason == "end_turn":
                text = next(
                    (b.text for b in resp.content if hasattr(b, "text")), ""
                )
                history.append({"role": "assistant", "content": resp.content})
                return text or "(no response)"

            if resp.stop_reason == "tool_use":
                messages.append({"role": "assistant", "content": resp.content})
                tool_results = []
                for block in resp.content:
                    if block.type == "tool_use":
                        log.info("Tool call: %s %s", block.name, block.input)
                        result = await run_tool(block.name, block.input)
                        log.info("Tool result (%d chars): %s", len(result), result[:120])
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": result,
                        })
                messages.append({"role": "user", "content": tool_results})
                continue

            # Unexpected stop reason
            break

        return "Could not complete the request."

    def clear_history(self, sender: str) -> None:
        self._history.pop(sender, None)

#!/bin/sh
cat <<'EOF'
Jarvis Chat Helper

Use Jarvis as a conversational assistant for your Proxmox home lab.

Example prompts:
  - "Jarvis, generate a health report for my home lab"
  - "How do I patch all LXC containers safely?"
  - "Check Pi-hole status and DNS health"
  - "Show me current disk usage on /mnt/media"
  - "List all running containers and their IP addresses"

Use this repository's built-in Jarvis agent by opening the VS Code chat or selecting the custom agent if available.
Refer to:
  - skills/chat/SKILL.md
  - skills/health-monitoring/SKILL.md
  - skills/container-patching/SKILL.md
  - skills/dns-management/SKILL.md
EOF

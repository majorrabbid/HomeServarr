#!/usr/bin/env bash
# ------------------------------------------------------------------
# Remove Roblox regex deny rules from Pi-hole.
# This deletes the same Roblox patterns added by block_roblox.sh.
# ------------------------------------------------------------------
set -uo pipefail

RULES=(
  '(^|\.)roblox\.com$'
  '(^|\.)roblox\.net$'
  '(^|\.)rbxcdn\.com$'
  '(^|\.)robloxstatic\.com$'
  '(^|\.)robloxgames\.com$'
  '(^|\.)robloxcloud\.com$'
)

if [[ $(id -u) -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

for rule in "${RULES[@]}"; do
  if /usr/local/bin/pihole --regex -l | grep -Fxq "$rule" 2>/dev/null; then
    echo "Removing Roblox regex block: $rule"
    /usr/local/bin/pihole --regex -d "$rule"
  else
    echo "Not present: $rule"
  fi
  echo
 done

# Refresh gravity and DNS cache.
/usr/local/bin/pihole -g
/usr/local/bin/pihole reloaddns

echo "Roblox regex block rules have been removed."

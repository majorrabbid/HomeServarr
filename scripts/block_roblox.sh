#!/usr/bin/env bash
# ------------------------------------------------------------------
# Block Roblox domains globally in Pi-hole using regex deny rules.
# This adds common Roblox domain patterns and refreshes Pi-hole gravity.
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
  if ! /usr/local/bin/pihole --regex -l | grep -Fxq "$rule" 2>/dev/null; then
    echo "Blocking Roblox regex: $rule"
    /usr/local/bin/pihole --regex "$rule"
  else
    echo "Already blocked: $rule"
  fi
  echo
 done

# Refresh gravity and DNS cache.
/usr/local/bin/pihole -g
/usr/local/bin/pihole reloaddns

echo "Roblox regex block rules have been applied."

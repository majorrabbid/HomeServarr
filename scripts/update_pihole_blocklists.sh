#!/usr/bin/env bash
# ------------------------------------------------------------------
# Add curated Pi-hole blocklists and refresh gravity.
# Run this inside the Pi-hole container as root.
# Usage: ./update_pihole_blocklists.sh
# ------------------------------------------------------------------
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

if ! command -v /usr/local/bin/pihole >/dev/null 2>&1; then
  echo "ERROR: Pi-hole CLI not found at /usr/local/bin/pihole."
  exit 1
fi

ADLISTS=(
  "https://v.firebog.net/hosts/AdguardDNS.txt"
  "https://v.firebog.net/hosts/Easylist.txt"
  "https://v.firebog.net/hosts/Easyprivacy.txt"
  "https://v.firebog.net/hosts/Prigent-Ads.txt"
  "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
  "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt"
)

existing_lists=$(/usr/local/bin/pihole -a adlist -l 2>/dev/null || true)

for url in "${ADLISTS[@]}"; do
  if grep -Fxq "$url" <<< "$existing_lists"; then
    echo "Skipped existing blocklist: $url"
  else
    echo "Adding blocklist: $url"
    /usr/local/bin/pihole -a adlist -a "$url"
  fi
  echo
done

echo "Updating gravity..."
/usr/local/bin/pihole -g

echo "Reloading Pi-hole DNS cache..."
/usr/local/bin/pihole reloaddns

echo "Pi-hole blocklists have been updated."

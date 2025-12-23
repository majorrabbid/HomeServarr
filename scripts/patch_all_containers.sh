#!/usr/bin/env bash
#
# Patch all LXC containers + DNS health check + summary for Homepage widget

set -uo pipefail

LOG_FILE="/var/log/lxc_patch.log"
SUMMARY_FILE="/var/log/lxc_patch_summary.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

mkdir -p /var/log

CHECK_DOMAIN="deb.debian.org"

echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
echo "LXC patch run started: ${TIMESTAMP}" | tee -a "$LOG_FILE"
echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

echo "🔎 DNS + Repo Health Check..." | tee -a "$LOG_FILE"

if dig +short "$CHECK_DOMAIN" @127.0.0.1 >/dev/null 2>&1; then
  echo "DNS OK → Pi-hole responding" | tee -a "$LOG_FILE"
else
  echo "❌ DNS failed via Pi-hole (127.0.0.1) — falling back to 1.1.1.1" | tee -a "$LOG_FILE"
  if ! dig +short "$CHECK_DOMAIN" @1.1.1.1 >/dev/null 2>&1; then
    echo "❌ DNS lookup FAILED even with fallback resolver" | tee -a "$LOG_FILE"
    echo "Last LXC patch: FAILED (DNS error) at ${TIMESTAMP}" > "$SUMMARY_FILE"
    exit 1
  fi
  echo "DNS fallback OK but Pi-hole DNS is failing" | tee -a "$LOG_FILE"
fi

echo | tee -a "$LOG_FILE"
echo "🧮 Listing containers..." | tee -a "$LOG_FILE"

CT_LIST=$(pct list | awk 'NR>1 {print $1}')
if [[ -z "$CT_LIST" ]]; then
  echo "❌ No LXC containers found." | tee -a "$LOG_FILE"
  echo "Last LXC patch: FAILED (no containers) at ${TIMESTAMP}" > "$SUMMARY_FILE"
  exit 1
fi

echo "$CT_LIST" | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

OK_LIST=()
FAIL_LIST=()

for CTID in $CT_LIST; do
  echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
  echo "📦 Patching container $CTID" | tee -a "$LOG_FILE"
  echo "------------------------------------------------------------" | tee -a "$LOG_FILE"

  if pct exec "$CTID" -- bash -c '
      apt-get update &&
      apt-get upgrade -y &&
      apt-get autoremove -y &&
      apt-get autoclean -y
    '; then
    echo "✔ Done: $CTID" | tee -a "$LOG_FILE"
    OK_LIST+=("$CTID")
  else
    echo "❌ Patching failed in container $CTID (exit code $?)" | tee -a "$LOG_FILE"
    FAIL_LIST+=("$CTID")
  fi

  echo | tee -a "$LOG_FILE"
done

echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
if ((${#FAIL_LIST[@]} == 0)); then
  echo "🎉 All containers patched successfully." | tee -a "$LOG_FILE"
  echo "Last LXC patch: SUCCESS at ${TIMESTAMP}" > "$SUMMARY_FILE"
else
  echo "⚠️ Some containers failed to patch." | tee -a "$LOG_FILE"
  echo "OK:    ${OK_LIST[*]}" | tee -a "$LOG_FILE"
  echo "FAILED:${FAIL_LIST[*]}" | tee -a "$LOG_FILE"
  echo "Last LXC patch: PARTIAL SUCCESS at ${TIMESTAMP}" > "$SUMMARY_FILE"
  {
    echo "Successful: ${OK_LIST[*]}"
    echo "Failed:     ${FAIL_LIST[*]}"
  } >> "$SUMMARY_FILE"
fi
echo "------------------------------------------------------------" | tee -a "$LOG_FILE"

#!/usr/bin/env bash
#
# Simple Proxmox host patch script
# - Holds proxmox-ve & kernel meta if you want to avoid auto-kernel upgrades
# - Logs full output to /var/log/pve_host_patch.log
# - Writes a one-line summary to /var/log/pve_host_patch_summary.log

set -euo pipefail

LOG_FILE="/var/log/pve_host_patch.log"
SUMMARY_FILE="/var/log/pve_host_patch_summary.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

mkdir -p /var/log

{
  echo "------------------------------------------------------------"
  echo "PVE host patch run started: ${TIMESTAMP}"
  echo "------------------------------------------------------------"
  echo

  # If you want to *avoid* automatic kernel upgrades, uncomment this block:
  # echo "âœ” Holding kernel and proxmox meta-package (no auto-kernel upgrades)..."
  # apt-mark hold proxmox-ve 'pve-kernel-*' || true
  # echo "Currently held packages:"
  # apt-mark showhold || true
  # echo

  echo "ðŸ“¦ Running apt-get update..."
  apt-get update
  echo

  echo "ðŸ” Upgradable packages (simulation):"
  apt-get -s dist-upgrade || apt-get -s upgrade
  echo

  echo "ðŸš€ Applying upgrades..."
  # Prefer dist-upgrade; fall back to upgrade if needed
  if apt-get dist-upgrade -y; then
    echo
    echo "âœ… Host patching complete."
    echo "------------------------------------------------------------"
    echo "PVE host patch run finished successfully at: ${TIMESTAMP}"
    echo "------------------------------------------------------------"
    echo "Last host patch: SUCCESS at ${TIMESTAMP}" > "${SUMMARY_FILE}"
  else
    RC=$?
    echo
    echo "âŒ Host patching FAILED with exit code ${RC}."
    echo "------------------------------------------------------------"
    echo "Last host patch: FAILED at ${TIMESTAMP} (exit code ${RC})" > "${SUMMARY_FILE}"
    exit "${RC}"
  fi
} | tee -a "${LOG_FILE}"

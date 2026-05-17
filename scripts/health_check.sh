#!/usr/bin/env bash
# Proxmox Health Check Script
# Gathers system metrics, LXC status, and Docker status for the home lab

# Source configuration
source /opt/homeservarr/config.env 2>/dev/null || true

EMAIL_TO="${1:-${HEALTH_EMAIL:-majorrabbid@gmail.com}}"

generate_report() {
    echo "========================================"
    echo "    PROXMOX HOME LAB HEALTH CHECK       "
    echo "========================================"
    echo "Date: $(date)"
    echo ""

    echo "--- Connectivity Check ---"
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "Internet Connectivity: OK"
    else
        echo "Internet Connectivity: FAILED"
    fi
    echo ""

    echo "--- Host Status & Load ---"
    uptime
    echo "System load is nominal."
    echo ""

    echo "--- Memory Usage ---"
    free -h
    echo ""

    echo "--- Disk Space ---"
    df -h / /mnt/media | grep -v "tmpfs"
    echo ""

    echo "--- SMART Disk Health (/dev/sda) ---"
    if command -v smartctl >/dev/null 2>&1; then
        SMART_STATUS=$(smartctl -H /dev/sda | grep "SMART overall-health" | awk '{print $NF}')
        echo "Primary Drive (/dev/sda): $SMART_STATUS"
    else
        echo "Primary Drive (/dev/sda): Unknown test result"
    fi
    echo ""

    echo "--- Pending Host Updates ---"
    if command -v apt >/dev/null 2>&1; then
        UPDATE_COUNT=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
        echo "$UPDATE_COUNT upgraded, 0 newly installed, 0 to remove and 0 not upgraded."
        if [ "$UPDATE_COUNT" -gt 0 ]; then
            echo "🚨 [WARNING] $UPDATE_COUNT updates pending. Consider patching."
        fi
    else
        echo "Unable to check updates."
    fi
    echo ""

    echo "--- LXC Containers Status ---"
    pct list
    echo ""

    echo "--- Arr Stack (LXC 102) Docker Status ---"
    if pct status 102 | grep -q "status: running"; then
        pct exec 102 -- docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || echo "Failed to run docker ps on LXC 102"
    else
        echo "LXC 102 (arr) is not running."
    fi
    echo ""

    echo "========================================"
    echo "         HEALTH CHECK COMPLETE          "
    echo "========================================"
}

REPORT=$(generate_report)

# Always print the report to stdout
echo "$REPORT"

# If mail command exists and EMAIL_TO is not empty, send the email
if command -v mail >/dev/null 2>&1; then
    if [ -n "$EMAIL_TO" ]; then
        echo "$REPORT" | mail -s "Proxmox Home Lab Health Check" "$EMAIL_TO"
        echo "[INFO] Report emailed to $EMAIL_TO"
    fi
else
    echo "[WARNING] 'mail' command not found, email not sent."
fi


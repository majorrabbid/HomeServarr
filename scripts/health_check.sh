#!/usr/bin/env bash
# Proxmox Health Check Script
# Gathers system metrics, LXC status, and Docker status for the home lab

EMAIL_TO="${1:-majorrabbid@gmail.com}"

generate_report() {
    echo "========================================"
    echo "    PROXMOX HOME LAB HEALTH CHECK       "
    echo "========================================"
    echo "Date: $(date)"
    echo ""

    echo "--- Host Status ---"
    uptime
    echo ""

    echo "--- Memory Usage ---"
    free -h
    echo ""

    echo "--- Disk Space ---"
    df -h / /mnt/media | grep -v "tmpfs"
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


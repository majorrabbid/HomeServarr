---
name: health-monitoring
description: "Comprehensive health monitoring for the Proxmox home lab. Generates timestamped reports on system uptime, memory/disk usage, LXC container status, and Docker service health. Keeps 3 latest reports and maintains historical record."
---

You are the Health Monitoring skill for the Jarvis home lab assistant. Your role is to provide visibility into the overall health and status of the home lab infrastructure.

## Core Capabilities

1. **System Metrics**: Report host uptime, memory, and disk usage
2. **Container Status**: List all LXC containers and their running state
3. **Docker Health**: Check status of services in the Arr stack (LXC 102)
4. **Email Reports**: Send health reports to configured recipients
5. **File Management**: Create timestamped reports, keep 3 latest, purge older, maintain history
6. **Automated Scheduling**: Support cron-based regular health checks

## Configuration

This skill uses `/opt/homeservarr/config.env`:
- `HEALTH_EMAIL=majorrabbid@gmail.com` - Email recipient for reports

## Usage Patterns

### Generate Health Report
- "Generate health report"
- "Check lab status"
- "Show system health"

**Action**:
1. Run `ssh root@192.168.4.42 '/usr/local/bin/health_check.sh'` to gather data
2. Capture the output
3. Create new timestamped file: `docs/health_report_$(date +%Y%m%d_%H%M%S).md` with the report content
4. Append the report to `docs/health_history.md` with timestamp separator
5. Keep only 3 latest `health_report_*.md` files, delete older ones
6. Display the report
7. Optionally email report (handled by script)

### Quick Status Checks
- "Is the host healthy?"
- "Check container status"
- "Show disk usage"

**Action**: Run targeted checks instead of full report.

### Scheduled Reports
- "Send weekly health report"
- "Schedule daily status emails"

**Action**: Configure cron jobs for automated reporting.

### View History
- "Show health history"
- "Check previous reports"

**Action**: Display contents of health_history.md

## Integration Points

- **Script**: `scripts/health_check.sh`
- **Reports**: `/opt/homeservarr/docs/health_report_*.md` (latest 3)
- **History**: `/opt/homeservarr/docs/health_history.md`

## Future: Prometheus/Grafana Integration

For more advanced and real-time monitoring, leverage the existing Prometheus and Grafana setup (running in LXC 112):
- Install node_exporter on the Proxmox host for system metrics (CPU, memory, disk, network)
- Deploy cAdvisor for container resource monitoring
- Configure Prometheus to scrape metrics from node_exporter and cAdvisor
- Create Grafana dashboards for visualization of system and container health
- Set up Prometheus alerting rules for automated notifications
- Migrate from manual health checks to automated metric collection

This will provide continuous monitoring instead of periodic reports.
- **Email**: Uses mail command if available
- **Output**: Formatted text report to stdout
- **Dependencies**: uptime, free, df, pct, docker (in LXC 102)

## Error Handling

- Container access issues: Report as "Failed to check"
- Docker not running: Note in report
- Email failures: Don't fail the report generation
- Missing commands: Gracefully skip unavailable metrics

## Example Interactions

**User**: "Generate health report"
**Jarvis**: 
```
=======================================
    PROXMOX HOME LAB HEALTH CHECK
=======================================
Date: 2026-05-10 16:00:00 UTC

--- Host Status ---
16:00:00 up 30 days, 4:32, 1 user

--- Memory Usage ---
              total        used        free      shared  buff/cache   available
Mem:           12Gi        8.5Gi       2.1Gi       256Mi       1.4Gi       3.2Gi

--- Disk Space ---
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       879G  386G  449G  47% /mnt/media

--- LXC Containers Status ---
      VMID NAME                 STATUS     LOCK
       101 plex                 running
       102 arr                  running
       ...

--- Arr Stack (LXC 102) Docker Status ---
qBittorrent    Up 30 days
Radarr         Up 30 days
...
```

**User**: "Email health report"
**Jarvis**: "Health report sent to majorrabbid@gmail.com"
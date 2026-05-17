========================================
    PROXMOX HOME LAB HEALTH CHECK       
========================================
Date: Sun May 10 11:52:04 AM AEST 2026

--- Connectivity Check ---
Internet Connectivity: OK

--- Host Status & Load ---
 11:52:04 up 102 days, 15:33,  5 users,  load average: 1.23, 1.94, 2.57
System load is nominal.

--- Memory Usage ---
               total        used        free      shared  buff/cache   available
Mem:            12Gi       7.0Gi       568Mi       157Mi       5.5Gi       5.6Gi
Swap:          8.0Gi       3.0Gi       5.0Gi

--- Disk Space ---
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/pve-root   94G   22G   68G  25% /
/dev/sda2             879G  560G  276G  68% /mnt/media


--- SMART Disk Health (/dev/sda) ---
Primary Drive (/dev/sda): Unknown test result

--- Pending Host Updates ---
1 upgraded, 0 newly installed, 0 to remove and 3 not upgraded.
🚨 [WARNING] 1 updates pending. Consider patching.

--- LXC Containers Status ---
VMID       Status     Lock         Name
101        running                 plex
102        running                 arr
103        running                 pihole
104        running                 unifi
105        running                 n8n
106        running                 twingate-connector
107        running                 patchmon
108        running                 homepage
109        running                 teamspeak-server
110        stopped                 homebridge
111        running                 homebridge
112        running                 grafana

--- Arr Stack (LXC 102) Docker Status ---
NAMES         STATUS
qbittorrent   Up 13 minutes
sonarr        Up 13 minutes
bazarr        Up 13 minutes
prowlarr      Up 13 minutes
overseerr     Up 13 minutes
radarr        Up 13 minutes

========================================
         HEALTH CHECK COMPLETE
========================================
[INFO] Report emailed to majorrabbid@gmail.com

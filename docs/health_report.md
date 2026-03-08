========================================
    PROXMOX HOME LAB HEALTH CHECK       
========================================
Date: Sun Mar  8 03:46:35 PM AEDT 2026

--- Host Status ---
 15:46:35 up 39 days, 18:28,  3 users,  load average: 1.30, 1.34, 1.31

--- Memory Usage ---
               total        used        free      shared  buff/cache   available
Mem:            12Gi       7.3Gi       556Mi       110Mi       5.2Gi       5.3Gi
Swap:          8.0Gi       2.7Gi       5.3Gi

--- Disk Space ---
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/pve-root   94G   16G   74G  18% /
/dev/sda2             879G  386G  450G  47% /mnt/media

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
sonarr        Up 2 weeks
bazarr        Up 2 weeks
prowlarr      Up 2 weeks
overseerr     Up 2 weeks
qbittorrent   Up 2 weeks
radarr        Up 2 weeks

========================================
         HEALTH CHECK COMPLETE          
========================================

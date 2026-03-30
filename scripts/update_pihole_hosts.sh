#!/bin/bash
# ------------------------------------------------------------------
# Script to update Pi-hole v6 custom DNS records via 'pct push'.
# Usage: ./update_pihole_hosts.sh
# ------------------------------------------------------------------
cat > /etc/pihole/hosts/custom.list <<EOM
192.168.4.42 pve.home
192.168.4.136 homeassistant.home
192.168.4.132 plex.home
192.168.4.124 arr.home
192.168.4.53 pihole.home
192.168.4.53 dns.home
192.168.4.131 unifi.home
192.168.4.128 n8n.home
192.168.4.129 twingate.home
192.168.4.126 homepage.home
192.168.4.126 lab.home
192.168.4.166 homebridge.home
192.168.4.125 grafana.home
192.168.4.130 patchmon.home
192.168.4.147 teamspeak.home
EOM
/usr/local/bin/pihole restartdns

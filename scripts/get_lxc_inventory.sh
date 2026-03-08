#!/bin/bash
# ------------------------------------------------------------------
# Helper script to list LXC/VM IDs and their IPs on the network.
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# Helper script to list LXC/VM IDs and their IPs on the network.
# ------------------------------------------------------------------
for id in $(pct list | awk 'NR>1 {print $1}'); do
  hostname=$(pct exec $id -- hostname)
  ip=$(pct exec $id -- ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)
  echo "| $id | $hostname | $ip |"
done

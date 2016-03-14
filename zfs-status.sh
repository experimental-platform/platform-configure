#!/usr/bin/env bash
#
# Queries the status of zpool named by first argument and writes online or failed into
# the status file at /etc/protonet/system/zfs-status
#
zpool list $1 | tail -n +2 | grep ONLINE

if [ $? -eq 0 ]; then
   echo 'online' > /etc/protonet/system/zfs-status
else
   echo 'failed' > /etc/protonet/system/zfs-status
fi

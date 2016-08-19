#!/usr/bin/env bash
#
# Queries the status of zpool named by first argument and writes online or failed into
# the status file at /etc/protonet/system/zfs-status
#
zpool list $1 | tail -n +2 | grep ONLINE

if [ $? -eq 0 ]; then
	skvs_cli set system/zfs-status online
else
	skvs_cli set system/zfs-status failed
fi

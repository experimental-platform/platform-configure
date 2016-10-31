#!/usr/bin/env bash

set -e

keyhash=$(md5sum /data/pgp/public.key)
label=${keyhash:0:10}

echo 'creating zfs snapshots'
/opt/bin/zfs-snapshots -dir /backup -send -label ${label} create \
  protonet_storage/data \
  protonet_storage/home

echo 'backing up /etc protonet'
/usr/bin/tar -czPf /backup/etc-protonet-$(date +%Y-%m-%d-%H-%M-%S).tgz /etc/protonet

#!/bin/bash
set -e

# new systems need sometimes dont have systemd/system/
mkdir -p /data/systemd/system/
# First remove broken links, this should avoid confusing error messages
find -L /data/systemd/system/ -type l -exec rm -f {} +
grep -Hlr '# ExperimentalPlatform' /data/systemd/system/ | xargs rm -rf
# do it again to remove garbage
find -L /data/systemd/system/ -type l -exec rm -f {} +

cp /services/* /data/systemd/system/
cp /config/docker.conf /data/systemd/system/

mkdir -p /data/systemd/system/scripts/
cp /platform-configure.sh /data/systemd/system/scripts/platform-configure.sh
chmod +x /data/systemd/system/scripts/platform-configure.sh

rm -f /host-bin/systemd-docker || true
cp /systemd-docker /host-bin/
chmod +x /host-bin/systemd-docker

if [ -d /host-bin/ ]; then
  # this needs to be the full path on host, not in container
  ln -sf /etc/systemd/system/scripts/platform-configure.sh /host-bin/platform-configure
fi

mkdir -p /data/systemd/journald.conf.d && cp /config/journald_protonet.conf /data/systemd/journald.conf.d/journald_protonet.conf

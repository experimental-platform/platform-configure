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

mkdir -p /data/systemd/system/docker.service.d
cp /config/50-log-warn.conf /data/systemd/system/docker.service.d/50-log-warn.conf

# Network configuration
cp /config/*.network  /data/systemd/network

mkdir -p /data/udev/rules.d
cp /config/sound-permissions.rules /data/udev/rules.d/sound-permissions.rules
cp /config/video-permissions.rules /data/udev/rules.d/video-permissions.rules
cp /config/tty-permissions.rules   /data/udev/rules.d/tty-permissions.rules
cp /config/80-protonet.rules       /data/udev/rules.d/80-protonet.rules

mkdir -p /data/systemd/system/scripts/
cp /platform-configure.sh /data/systemd/system/scripts/platform-configure.sh
cp /platform-passwd.sh /data/systemd/system/scripts/platform-passwd.sh
chmod +x /data/systemd/system/scripts/platform-configure.sh /data/systemd/system/scripts/platform-passwd.sh

rm -f /host-bin/systemd-docker || true
cp /systemd-docker /host-bin/
chmod +x /host-bin/systemd-docker

cp /button /host-bin/

if [ -d /host-bin/ ]; then
  # this needs to be the full path on host, not in container
  ln -sf /etc/systemd/system/scripts/platform-configure.sh /host-bin/platform-configure
  ln -sf /etc/systemd/system/scripts/platform-passwd.sh /host-bin/platform-passwd
fi

mkdir -p /data/systemd/journald.conf.d && cp /config/journald_protonet.conf /data/systemd/journald.conf.d/journald_protonet.conf

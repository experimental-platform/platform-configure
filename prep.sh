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
grep -Hlr '# ExperimentalPlatform' /data/systemd/network | xargs rm -rf
cp /config/*.network  /data/systemd/network

mkdir -p /data/udev/rules.d
cp /config/sound-permissions.rules /data/udev/rules.d/sound-permissions.rules
cp /config/video-permissions.rules /data/udev/rules.d/video-permissions.rules
cp /config/tty-permissions.rules   /data/udev/rules.d/tty-permissions.rules
cp /config/80-protonet.rules       /data/udev/rules.d/80-protonet.rules

# Automates installation of utility scripts and services from scripts/* into
# $PATH on target systems.
mkdir -p /data/systemd/system/scripts/
for f in scripts/*.sh
do
  name=$(basename $f .sh)
  dest=/data/systemd/system/scripts/$name.sh
  echo "Installing $name to $dest"

  cp /scripts/$name.sh $dest
  chmod +x $dest
  if [ -d /host-bin/ ]; then
    # this needs to be the full path on host, not in container
    ln -sf /etc/systemd/system/scripts/$name.sh /host-bin/$name
  fi
done

cp /button /host-bin/

mkdir -p /data/systemd/journald.conf.d && cp /config/journald_protonet.conf /data/systemd/journald.conf.d/journald_protonet.conf

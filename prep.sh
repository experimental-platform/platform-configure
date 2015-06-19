#!/bin/bash
# new systems need sometimes dont have systemd/system/
mkdir -p /data/systemd/system/
# First remove broken links, this should avoid confusing error messages
find -L /data/systemd/system/ -type l -exec rm -f {} +
grep -Hlr --exclude="update-protonet.service" '# ExperimentalPlatform' /data/systemd/system/ | xargs rm -rf
# do it again to remove garbage
find -L /data/systemd/system/ -type l -exec rm -f {} +

# Set single service to special version
if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  SERVICE_FILE=/services/${SERVICE_NAME#platform-}-protonet.service

  if [ -e $SERVICE_FILE ]; then
    echo "{\"tag\":\"$SERVICE_TAG\"}" | mustache - $SERVICE_FILE > $SERVICE_FILE.new
    mv $SERVICE_FILE.new $SERVICE_FILE
  fi
fi

# all other files get VERSION as tag
for SERVICE_FILE in /services/*
do
  echo "{\"tag\":\"$VERSION\"}" | mustache - $SERVICE_FILE > $SERVICE_FILE.new
  mv $SERVICE_FILE.new $SERVICE_FILE
done

cp /services/* /data/systemd/system/

mkdir -p /data/systemd/system/scripts/
cp /stuff/update-images-protonet.sh /data/systemd/system/scripts/update-images-protonet.sh
cp /stuff/update-protonet.sh /data/systemd/system/scripts/update-protonet.sh
mkdir -p /data/systemd/journald.conf.d && cp /stuff/journald_protonet.conf /data/systemd/journald.conf.d/journald_protonet.conf

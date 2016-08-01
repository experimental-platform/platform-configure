#!/usr/bin/env bash
# Write out gitlab-network ip to SKVS if it has changed
if [ "$(/opt/bin/gitlab-network show | md5sum)" != "$(cat /etc/protonet/gitlab/ip | md5sum)" ]; then
  /opt/bin/gitlab-network show > /etc/protonet/gitlab/ip
  echo "Wrote gitlab-network ip to SKVS since it changed"
fi

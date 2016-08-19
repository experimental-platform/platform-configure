#!/usr/bin/env bash
# Write out gitlab-network ip to SKVS if it has changed
if [ "$(/opt/bin/gitlab-network show | md5sum)" != "$(skvs_cli get gitlab/ip | md5sum)" ]; then
	skvs_cli set gitlab/ip $(/opt/bin/gitlab-network show)
  echo "Wrote gitlab-network ip to SKVS since it changed"
fi

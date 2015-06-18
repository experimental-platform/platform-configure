#!/bin/bash
set -x
find /etc/systemd/system -maxdepth 1 ! -name "update-protonet.service" ! -name "*.sh" -type f -exec systemctl enable {} +
# this should reload everything
systemctl restart init-protonet

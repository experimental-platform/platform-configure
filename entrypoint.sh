#!/usr/bin/env bash

set -eu
set -o pipefail

function get_configure_tag() {
    local CHANNEL="$1"
    curl --fail "https://raw.githubusercontent.com/protonet/builds/master/$CHANNEL.json" | jq '.[0].images["quay.io/experimentalplatform/configure"]' --raw-output
}

echo " *** This is the configure tag update rescue script"
echo " *** Updating your platform-configure-script"

NEW_CONFIGURE_IMAGE="quay.io/experimentalplatform/configure:$(get_configure_tag $CHANNEL)"
NEW_PLATFORM_CONFIGURE=$(/docker run -i --rm "$NEW_CONFIGURE_IMAGE" cat /scripts/platform-configure.sh)

echo "$NEW_PLATFORM_CONFIGURE" > /mnt/etc/systemd/system/scripts/platform-configure.sh
chmod +x /mnt/etc/systemd/system/scripts/platform-configure.sh

echo " *** Restarting the update process"
busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager RestartUnit 'ss' trigger-update-protonet.service replace
/docker rm -f configure
exit 1

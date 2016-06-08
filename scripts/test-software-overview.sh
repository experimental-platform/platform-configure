#!/usr/bin/env bash

set -eu

echo -n "Test the number of running services... "

EP="# ExperimentalPlatform"
DR="docker run"
TO="Type=oneshot"
WHERE="/etc/systemd/system/"

SHOULD=$(grep -Hlr "${EP}" "${WHERE}" | xargs grep -Hlr "${DR}" "${WHERE}" | xargs grep -Hlr "${TO}" "${WHERE}" | wc -l)
ACTUALLY=$(docker ps | grep -P "quay.io/(experimentalplatform|protonetinc)" | wc -l)

if [[ "${SHOULD}" -eq "${ACTUALLY}" ]]; then
    echo "SUCCESS, (${SHOULD}) running."
    exit 0
fi

echo "ERROR: Expected ${SHOULD} services but ${ACTUALLY} are running."
exit 23
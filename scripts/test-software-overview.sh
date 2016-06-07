#!/usr/bin/env bash

set -eu

echo "Test the number of running services."

EP="# ExperimentalPlatform"
DR="docker run"
TO="Type=oneshot"
WHERE="/etc/systemd/system/"

SHOULD=$(grep -Hlr "${EP}" "${WHERE}" | xargs grep -Hlr "${DR}" "${WHERE}" | xargs grep -Hlr "${TO}" "${WHERE}" | wc -l)
ACTUALLY=$(docker ps | grep -P "quay.io/(experimentalplatform|protonetinc)")

if [[ "${SHOULD}" -eq "${ACTUALLY}" ]]; then
    echo "The correct number of services (${SHOULD}) is running."
    exit 0
fi

echo "Expected ${SHOULD} services but ${ACTUALLY} are running."
exit 23
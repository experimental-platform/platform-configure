#!/usr/bin/env bash

set -eu

ERROR_CODE=0
ERROR="\x1b[93;41mERROR\x1b[0m"


echo -n "Test the number of running services... "

EP="# ExperimentalPlatform"
DR="docker run"
TO="Type=oneshot"
WHERE="/etc/systemd/system/"

SHOULD=$(grep -Hlr "${EP}" "${WHERE}" | xargs grep -Hlr "${DR}" "${WHERE}" | xargs grep -Hlr "${TO}" "${WHERE}" | wc -l)
ACTUALLY=$(docker ps | grep -P "quay.io/(experimentalplatform|protonetinc)" | wc -l)

if [[ "${SHOULD}" -eq "${ACTUALLY}" ]]; then
    echo "OKAY, (${SHOULD}) running."
else
    echo -e "${ERROR}: Expected ${SHOULD} services but ${ACTUALLY} are running."
    ERROR_CODE=23
fi


echo -n "Test for identical version... "
TAGS=$(docker ps | awk '/^[0-9a-z]+/ { split($2, a, ":"); print a[2]}' | uniq)
NUM_TAGS=$(wc -l <<< ${TAGS})
if [[ "${NUM_TAGS}" -eq "1" ]]; then
    echo "OKAY"
else
    echo -e "${ERROR}: Mix up found: $TAGS."
    ERROR_CODE=23
fi


exit ${ERROR_CODE}

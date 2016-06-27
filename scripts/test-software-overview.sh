#!/usr/bin/env bash

set -eu

ERROR_CODE=0
ERROR="\x1b[93;41mERROR\x1b[0m"

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

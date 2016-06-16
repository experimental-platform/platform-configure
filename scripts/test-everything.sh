#!/usr/bin/env bash

set -eu

trap "button error >/dev/null 2>&1 || true" SIGINT SIGTERM EXIT
button rainbow

for testname in test-disks test-ipmi-disabled test-software-overview; do
    if [[ -x "/etc/systemd/system/scripts/${testname}.sh" ]]; then
        # this will exit on error because of set -e
        /etc/systemd/system/scripts/${testname}.sh
        echo -e "\n\n"
    else
        echo "ERROR: Test \"${testname}\" not found!"
        exit 23
    fi
done

# TODO: GET HARDWARE OVERVIEW
# TODO: RUN INTEGRATION TESTS

trap - SIGINT SIGTERM EXIT
button hdd

echo -e "OKAY\nOKAY\OKAY\n\tALL TESTS SUCCESSFUL"
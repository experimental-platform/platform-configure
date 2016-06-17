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

echo -e "\n\nOKAY -- OKAY -- OKAY\nALL TESTS SUCCESSFUL\n\n"

echo -e "HARDWARE INFO\n"
HWINFO=$(sudo /etc/systemd/system/scripts/test-hwinfo.sh)
echo -e "MAINBOARD:"
jq ' .motherboard | "Vendor: \(.vendor)    Name: \(.name)    Version: \(.version)    Serial: \(.serial)"' <<< ${HWINFO}
echo -e "\nRAM:"
jq ' .ram | map("Vendor: \(.vendor)    Slot: \(.slot)    Size: \(.size)    Product: \(.product)    Serial: \(.serial)")' <<< ${HWINFO}
echo -e "\nHARD DISKS (and USB Sticks):"
jq ' .drives | map("Vendor: \(.vendor)    Model: \(.model)    Size: \(.size)    Serial: \(.serial)")' <<< ${HWINFO}

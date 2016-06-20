#!/usr/bin/env bash

set -eu

test_soul() {
    # SOUL_URL=http://172.17.0.1 # Note: We should set this automatically to DOCKERHOST ip
    SOUL_USERNAME=${SOUL_USERNAME:="admin.admin"}
    SOUL_PASSWORD=${SOUL_PASSWORD:="Changeme!123"}
    SOUL_GROUP_NAME=${SOUL_GROUP_NAME:="CHANGEME"}
    SOUL_HOSTNAME=${SOUL_HOSTNAME:-} # Note: This is one is an optional parameter, and is newly added. Needed for connecting via IP
    SOUL_URL=${SOUL_URL:="http://10.42.0.1"}
    SOUL_SSH_PASSWORD=${SOUL_SSH_PASSWORD:-}
    if [[ -z ${SOUL_SSH_PASSWORD} ]]; then
        if [[ -f "/etc/protonet/system/ssh/password" ]]; then
            # if masterpassword was used
            SOUL_SSH_PASSWORD=$(cat "/etc/protonet/system/ssh/password")
        else
            # default installation password - gets disabled on setup
            SOUL_SSH_PASSWORD="1nsta!lMe"
        fi
    fi

    if docker pull quay.io/experimentalplatform/soul-integration &>/dev/null; then
        docker run -ti --rm \
            -e "SOUL_USERNAME=${SOUL_USERNAME}" \
            -e "SOUL_PASSWORD=${SOUL_PASSWORD}" \
            -e "SOUL_GROUP_NAME=${SOUL_GROUP_NAME}" \
            -e "SOUL_HOSTNAME=${SOUL_HOSTNAME}" \
            -e "SOUL_URL=${SOUL_URL}" \
            -e "SOUL_SSH_PASSWORD=${SOUL_SSH_PASSWORD}" \
            quay.io/experimentalplatform/soul-integration bundle exec rspec --tag readonly
    else
        echo "ERROR DOWNLOADING THE SOUL INTEGRATION TESTS."
    fi
}


run_tests() {
    # TODO: Reenable test-software-overview
    for testname in test-disks test-ipmi-disabled; do
        if [[ -x "/etc/systemd/system/scripts/${testname}.sh" ]]; then
            # this will exit on error because of set -e
            /etc/systemd/system/scripts/${testname}.sh
            echo -e "\n\n"
        else
            echo "ERROR: Test \"${testname}\" not found!"
            exit 23
        fi
    done
}


trap "button error >/dev/null 2>&1 || true" SIGINT SIGTERM EXIT
button rainbow

run_tests
# test_soul

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

echo -e "\nSOFTWARE CHANNEL AND BOOT STICK BUILD:"
jq ' "Channel: \(.channel)"' <<< ${HWINFO}
jq ' "BOOTSTICK BUILD: \(.bootstick.BUILD)"' <<< ${HWINFO}

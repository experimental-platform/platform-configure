#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SUPPORT_FILE="/etc/protonet/support_identifier"

get_mac() {
    local interfaces=$(ip link show | awk '/^[0-9]+:\s+[ew][a-z0-9]+/ { gsub(/:/, "", $2); print $2 }')
    local mac
    local result=""
    local iface
    for iface in ${interfaces}; do
        mac=$(ip link show ${iface} | awk '/link/ { gsub(/:/, "", $2); print toupper($2)}')
        result=$(echo ${result}-${mac})
    done
    echo -n "${result}"
}


get_hw() {
    local INTERFACE_COUNT=$(ip link show | grep -P '^\d+:\s+[ew][a-z0-9]+'| wc -l)
    if [[ "${INTERFACE_COUNT}" -eq 2 ]]; then
        echo -n "MAYA"
    else
        echo -n "CARLA"
    fi
}


main () {
    if [ "$(id -u)" != "0" ]; then
        echo "You must run this as root"
        exit 1
    fi

    if [[ ! -f "${SUPPORT_FILE}" ]]; then
        echo -n "Writing support identifier to ${SUPPORT_FILE}... "
        mkdir -p $(dirname "${SUPPORT_FILE}")
        get_hw > ${SUPPORT_FILE}
        get_mac >> ${SUPPORT_FILE}
        echo "DONE"
    else
        echo "Support identifier ${SUPPORT_FILE} already exists."
    fi
}

main
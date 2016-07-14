#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SUPPORT_FILE="/etc/protonet/system/support_identifier"
BOX_NAME_FILE="/etc/protonet/box_name"


get_macs() {
    local interfaces=$(ip link show | awk '/^[0-9]+:\s+[ew][a-z0-9]+/ { gsub(/:/, "", $2); print $2 }')
    local mac
    local result=""
    local iface
    for iface in ${interfaces}; do
        mac=$(ip link show ${iface} | awk '/link/ { gsub(/:/, "", $2); print toupper($2)}')
        if [[ -z "$result" ]]; then
            result="$mac"
        else
            result="${result}\\n${mac}"
        fi
    done
    echo -e "$result"
}


get_default_mac() {
    echo -n $(get_macs | sort | head -n 1)
}


get_hw() {
    local INTERFACE_COUNT=$(ip link show | grep -P '^\d+:\s+[ew][a-z0-9]+'| wc -l)
    if [[ "${INTERFACE_COUNT}" -eq 2 ]]; then
        echo -n "M"
    else
        echo -n "C"
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
        get_default_mac >> ${SUPPORT_FILE}
        echo >> ${SUPPORT_FILE}
        echo "DONE"
    else
        echo "Support identifier ${SUPPORT_FILE} already exists."
    fi

    if [[ ! -f "${BOX_NAME_FILE}" ]]; then
        echo -n "Writing individual box name to ${BOX_NAME_FILE}... "
        echo "Protonet-$(get_default_mac)" > ${BOX_NAME_FILE}
        echo "DONE"
    else
        echo "Box name file ${BOX_NAME_FILE} already exists."
    fi
}

main
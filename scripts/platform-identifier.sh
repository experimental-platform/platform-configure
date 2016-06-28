#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SUPPORT_FILE="/etc/protonet/support_identifier"

get_mac() {
    local INTERFACE=$(netstat -nr | awk '/^0\.0\.0\.0/ { print $8 }')
    local MAC=$(ip link show ${INTERFACE} | awk '/link/ { gsub(/:/, "", $2); print toupper($2)}')
    echo -n "${MAC}"
}

get_hw() {
    echo -n "U"
}


if [[ ! -f "${SUPPORT_FILE}" ]]; then
    mkdir -p $(dirname "${SUPPORT_FILE}")
    get_hw > ${SUPPORT_FILE}
    get_mac > ${SUPPORT_FILE}
fi

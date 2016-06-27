#!/usr/bin/env bash

set -eu

ERROR="\x1b[93;41mERROR\x1b[0m"
echo -n "RUNNING IPMI SECURITY TEST... "

if [[ -e /dev/ipmi0 ]] || [[ -e /dev/ipmi/0 ]] || [[ -e /dev/ipmidev/0 ]]; then
    enabled_user_count=$(ipmitool user summary | grep 'Enabled User Count' | grep --only-matching '[0-9]*$')

    if [ $enabled_user_count -eq 0 ]; then
        echo "OKAY, IPMI users are disabled"
    else
        echo -e "${ERROR}: There are $enabled_user_count IPMI users enabled"
        exit 1
    fi
else
    echo "OKAY, IPMI NOT AVAILABLE."
fi
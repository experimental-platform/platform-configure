#!/usr/bin/env bash

set -eu
echo -n "RUNNING IPMI SECURITY TEST... "

if [[ -e /dev/ipmi0 ]] || [[ -e /dev/ipmi/0 ]] || [[ -e /dev/ipmidev/0 ]]; then
    enabled_user_count=$(ipmitool user summary | grep 'Enabled User Count' | grep --only-matching '[0-9]*$')

    if [ $enabled_user_count -eq 0 ]; then
        echo "OKAY, IPMI users are disabled"
    else
        echo "ERROR: There are $enabled_user_count IPMI users enabled"
        exit 1
    fi
else
    echo "OKAY, IPMI NOT AVAILABLE."
fi
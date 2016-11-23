#!/usr/bin/env bash

set -eu

ERROR="\x1b[93;41mERROR\x1b[0m"
echo "RUNNING IPMI SDR TEST... "

if [[ -e /dev/ipmi0 ]] || [[ -e /dev/ipmi/0 ]] || [[ -e /dev/ipmidev/0 ]]; then
	ipmitool sdr
	echo "OKAY"
else
	echo "OKAY, IPMI NOT AVAILABLE."
fi

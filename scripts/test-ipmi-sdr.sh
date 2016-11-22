#!/usr/bin/env bash

set -eu

ERROR="\x1b[93;41mERROR\x1b[0m"
echo "RUNNING IPMI SDR TEST... "

ipmitool sdr
echo "OKAY"

#!/usr/bin/env bash

set -eu

ERROR="\x1b[93;41mERROR\x1b[0m"
echo "RUNNING STRESS TEST... "

CPU_AMMOUNT=$(cat /proc/cpuinfo | grep 'processor' | wc -l)

toolbox --bind=/dev:/dev bash -c "((rpm -qa | grep -q '^stress-') || (rpm --import /etc/pki/rpm-gpg/RPM* && dnf install -q -y stress)) && cd /media/root/tmp && stress --timeout 10 --hdd 5 --io 5 --cpu $CPU_AMMOUNT --vm 5"

echo "OKAY"

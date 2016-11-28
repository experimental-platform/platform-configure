#!/usr/bin/env bash

set -eu

ERROR="\x1b[93;41mERROR\x1b[0m"
echo "RUNNING STRESS TEST... "

toolbox --bind=/dev:/dev bash -c '((rpm -qa | grep -q '^stress-') || (rpm --import /etc/pki/rpm-gpg/RPM* && dnf install -q -y stress)) && stress -t 10 -d 20 -i 20 -c 20 --vm 20'

echo "OKAY"

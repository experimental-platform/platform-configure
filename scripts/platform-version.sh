#!/usr/bin/env bash
#
# A simple utilty for quickly seeing at a glance what channel/version a
# platform system is on.
#

echo "CHANNEL=$(skvs_cli get system/channel)"
echo "RELEASE_NUMBER=$(skvs_cli get system/release_number)"
echo "COREOS_CHANNEL=$(cat /etc/coreos/update.conf | grep GROUP= | cut -d\= -f2)"
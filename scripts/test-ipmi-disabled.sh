#!/usr/bin/env bash

set -eu

enabled_user_count=$(ipmitool user summary | grep 'Enabled User Count' | grep --only-matching '[0-9]*$')

if [ $enabled_user_count -eq 0 ]; then
	echo IPMI users are disabled
	exit 0
else
	echo There are $enabled_user_count IPMI users enabled
	exit 1
fi

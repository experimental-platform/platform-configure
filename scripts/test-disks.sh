#!/usr/bin/env bash

set -eu

echo -n "Checking for docker backend... "
driver=$(docker info | grep '^Storage Driver: ' | sed -r 's/^Storage Driver: (.*)/\1/')
if [[ "${driver}" != "zfs" ]]; then
    echo "ERROR wrong backend ${driver}"
    exit 23
else
    echo "OKAY."
fi


for filesystem in /home /data /var/lib/docker /var/log/journal; do
    echo -n "Checking if ${filesystem} is on ZFS... "
    if ! (mount | grep -P "on ${filesystem}.*type zfs" > /dev/null); then
        echo "ERROR: ${filesystem} is fucked"
        exit 23
    else
        echo "OKAY."
    fi
done


echo -n "Checking number of zpools... "
NUM_ZPOOLS=$(sudo zpool list -H | wc -l)
if [[ "${NUM_ZPOOLS}" -eq "1" ]]; then
    echo "OKAY"
else
    echo "ERROR: one expected but got ${NUM_ZPOOLS}"
    exit 23
fi


echo -n "Checking zpool health... "
ZPOOL_HEALTH=$(sudo zpool status -x protonet_storage)
if [[ "${ZPOOL_HEALTH}" == "pool 'protonet_storage' is healthy" ]]; then
    echo "OKAY"
else
    echo "ERROR: ${ZPOOL_HEALTH}"
    exit 23
fi

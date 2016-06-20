#!/usr/bin/env bash

set -eu

ERROR=false

list_subsystems() {
	local DEVPATH
	DEVPATH="$1"

	while [ "$DEVPATH" != "/" ]; do
		if [ -h "$DEVPATH/subsystem" ]; then
			echo "$(basename "$(realpath "$DEVPATH/subsystem")")"
		fi

		DEVPATH="$(dirname "$DEVPATH")"
	done

	return
}


is_hotpluggable() {
	local DEVICE
	DEVICE="$(realpath /sys/block/$1)"

	for subsys in $(list_subsystems "$DEVICE"); do
		case $subsys in
			usb|ieee1394|pcmcia|mmc|ccw)
				return 0;;
		esac
	done

	return 1
}


enable_ignition() {
    local IGNITION_UUID="00000000-0000-0000-0000-000000000001"
    local ROOTDEV=$(blkid -L ROOT | grep -oP "[/a-zA-Z]*")
    # TODO: replace gdisk as it has no usable exit code (returns always 1)
    (echo x; echo g; echo ${IGNITION_UUID}; echo w; echo y;) | gdisk ${ROOTDEV} > /dev/null || true
}


remove_config() {
    grep -Hlr '# ExperimentalPlatform' /etc/systemd/system/ | xargs --no-run-if-empty rm -rf
    find -L /etc/systemd/system/ -type l -exec rm -f {} +
    rm -rf /etc/protonet
    rm -f /etc/ssh/ssh_host_*
    userdel -f -r platform &> /dev/null || true
}


unlabel_drives() {
	ROOTDEV=$(lsblk --noheadings --output PKNAME $(blkid -L ROOT))

	for d in /sys/block/*; do
		DEVNAME="$(basename "$d")"

		if [ "$DEVNAME" == "$ROOTDEV" ]; then
			echo -e "\t* Drive '$DEVNAME' is the boot device - skipping it"
			continue
		fi

		if [ "$(</sys/block/$DEVNAME/removable)" -eq 1 ]; then
			echo -e "\t* Drive '$DEVNAME' is removable - skipping it"
			continue
		fi

		if is_hotpluggable $DEVNAME; then
			echo -e "\t* Drive '$DEVNAME' is hot-pluggable - skipping it"
			continue
		fi

		echo -ne "\t* Clearing ZFS labels and GPT on drive '$DEVNAME'... "
		zpool labelclear -f "$DEVNAME" &>/dev/null || true
		if dd if=/dev/zero "of=$DEVNAME" bs=512 count=20 &>/dev/null; then
		    echo "OKAY"
		else
		    echo "ERROR!"
		    ERROR=true
		fi
	done
}


remove_zfs() {
    rm -f /etc/zfs/zpool.cache
    systemctl stop docker.service
    systemctl stop systemd-journald-audit.socket
    systemctl stop systemd-journald-dev-log.socket
    systemctl stop systemd-journald.socket
    systemctl stop systemd-journald.service && zfs umount -f protonet_storage/journal || true

    # try to destroy the zpool only if it actually exists
    if zpool list -H | grep -qE ^protonet_storage; then
        zpool destroy -f protonet_storage
    fi
}


remove_mountpoints() {
    local CURRENT_MOUNTPOINTS=$(mount)
    local MOUNTPOINT
    for MOUNTPOINT in  /home /data /var/lib/docker /var/log/journal; do
        # only remove it if it's not mounted any more
        echo -ne "\t* REMOVING '${MOUNTPOINT}'... "
        if  [[ ! "${CURRENT_MOUNTPOINTS}" =~ "${MOUNTPOINT}" ]] && rm -rf $MOUNTPOINT; then
            echo "OKAY"
        else
            echo "ERROR: PLEASE FIX ${MOUNTPOINT} MANUALLY"
            ERROR=true
        fi
    done
}


echo -n "REMOVING ZFS POOL... "
remove_zfs && echo "OKAY."

echo "UNLABELING DRIVES... "
unlabel_drives && echo "OKAY"
sync; sync; sync

# remove the config only after the ZFS pool was destroyed successfully.
echo -n "REMOVING CUSTOM SYSTEM CONFIG... "
remove_config && echo "OKAY"

echo "REMOVING ZFS MOINTPOINTS..."
remove_mountpoints && echo "OKAY"

# ignition useradd is not idempotent, so let's wait until after the user has been deleted
echo -n "ENABLING IGNITION... "
enable_ignition && echo "OKAY"


if [[ "${ERROR}"==true ]]; then
    echo "ERRORS detected, please fix manually!"
    exit 23
else
    echo "Destruction successful"
fi



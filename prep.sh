#!/bin/bash
set -e
set -o pipefail

MOUNTROOT=${MOUNTROOT:="/mnt"}
CHANNEL=${CHANNEL:="development"}
PLATFORM_REMOVE_OLD_IMAGES=${PLATFORM_REMOVE_OLD_IMAGES:="true"}
MANIFEST_URL=${MANIFEST_URL:='https://raw.githubusercontent.com/protonet/builds/master/$CHANNEL.json'}
DOCKER="/docker"
declare -A IMGTAGLIST

function fetch_module_images() {
  local CHANNEL JSON JQSCRIPT
  CHANNEL="$1"
  JQSCRIPT='max_by(.build) | .images | keys[] as $k | $k + ":" + .[$k]'
  curl --fail --silent "$(eval echo "$MANIFEST_URL")" | jq "$JQSCRIPT" --raw-output
}

function fetch_module_image_data() {
  local JSONIMGLIST

  JSONIMGLIST="$(fetch_module_images "$CHANNEL")"

  for img in ${JSONIMGLIST}; do
    # this splits a line in the format 'A:B' and assigns IMGTAGLIST[A]=B
    IFS=':' read -ra I <<< "$img"
    IMGTAGLIST[${I[0]}]=${I[1]}
  done
}

function pull_all_images() {
  for i in ${!IMGTAGLIST[@]}; do
    download_and_verify_image "$i:${IMGTAGLIST[$i]}"
  done
}

function set_status() {
  mkdir -p ${MOUNTROOT}/etc/protonet/system
  echo "$@" > ${MOUNTROOT}/etc/protonet/system/configure-script-status
}


function setup_paths() {
    echo -n "Creating paths in ${MOUNTROOT}/etc/systemd in case they don't exist yet... "
    mkdir -p ${MOUNTROOT}/etc/systemd/journald.conf.d
    mkdir -p ${MOUNTROOT}/etc/systemd/system/
    mkdir -p ${MOUNTROOT}/etc/systemd/system/docker.service.d
    mkdir -p ${MOUNTROOT}/etc/systemd/system/scripts/
    mkdir -p ${MOUNTROOT}/etc/udev/rules.d
    mkdir -p ${MOUNTROOT}/opt/bin
    echo "DONE."
}


function cleanup_systemd() {
    echo -n "Cleaning up ${MOUNTROOT}/etc/systemd/system/... "
    # First remove broken links, this should avoid confusing error messages
    find -L ${MOUNTROOT}/etc/systemd/system/ -type l -exec rm -f {} +
    ( grep -Hlr '# ExperimentalPlatform' ${MOUNTROOT}/etc/systemd/system/ || true ) | xargs --no-run-if-empty rm -rf
    # do it again to remove garbage
    find -L ${MOUNTROOT}/etc/systemd/system/ -type l -exec rm -f {} +
    ( grep -Hlr '# ExperimentalPlatform' ${MOUNTROOT}/etc/systemd/network || true ) | xargs --no-run-if-empty rm -rf
    echo "DONE."
}


function setup_systemd() {
    echo -n "Setting up systemd services... "
    cp /services/* ${MOUNTROOT}/etc/systemd/system/
    cp /config/50-log-warn.conf ${MOUNTROOT}/etc/systemd/system/docker.service.d/50-log-warn.conf
    cp /config/journald_protonet.conf ${MOUNTROOT}/etc/systemd/journald.conf.d/journald_protonet.conf
    cp /config/sysctl-klog.conf ${MOUNTROOT}/etc/sysctl.d/sysctl-klog.conf
    # Network configuration
    cp /config/*.network  ${MOUNTROOT}/etc/systemd/network
    echo "Reloading the config files."
    systemctl daemon-reload
    # Make sure we're actually waiting for the network if it's required.
    systemctl --root=${MOUNTROOT} enable systemd-networkd-wait-online.service
    echo "ENABLing all config files."
    find ${MOUNTROOT}/etc/systemd/system -maxdepth 1 ! -name "*.sh" -type f | \
        xargs --no-run-if-empty basename -a | \
        xargs --no-run-if-empty systemctl --root=${MOUNTROOT} enable
    echo "RESTARTing all .path files."
    find ${MOUNTROOT}/etc/systemd/system -maxdepth 1 -name "*.path" -type f | \
        xargs --no-run-if-empty basename -a | \
        xargs --no-run-if-empty systemctl restart
    echo "DONE."
}


function setup_channel_file() {
    # update the channel file in case there's none or if we're changing channels.
    # TODO: Bail if either CHANNEL or CHANNEL_FILE are not set
    echo -n "Detecting channel... "
    if [[ ! -f ${CHANNEL_FILE} ]] || [[ ! $(cat ${CHANNEL_FILE}) = "${CHANNEL}" ]]; then
        echo -n "using NEW '${CHANNEL}'... "
        systemctl stop trigger-update-protonet.path
        mkdir -p $(dirname ${CHANNEL_FILE})
        echo ${CHANNEL} > ${CHANNEL_FILE}
        systemctl start trigger-update-protonet.path
    else
        echo -n "using OLD '${CHANNEL}'... "
    fi
    echo "DONE."
}


function download_and_verify_image() {
    # TODO: DUPLICATED CODE MARK
    # TODO: Bail if IMAGE_STATE_DIR or REGISTRY is not set
    local image
    image=$1
    echo -ne "\t Image ${image}..."
    RETRIES=0
    MAXRETRIES=10
    while ( ! $DOCKER pull $image &>/dev/null ) && [ $RETRIES -ne $MAXRETRIES ]; do
        sleep 1
        echo " Pull failed, retrying."
        RETRIES=$(($RETRIES+1))
    done

    if [ $RETRIES -eq $MAXRETRIES ]; then
      echo " Failed to retrieve $image"
      exit 1
    fi

    local driver=$(${DOCKER} info | grep '^Storage Driver: ' | sed -r 's/^Storage Driver: (.*)/\1/')
    # if using OverlayFS then verify layers
    if [ "${driver}" == "overlay" ]; then
        # TODO: this basically works with ZFS too, it just has slightly different path names
        for layer in $(${DOCKER} history --no-trunc ${image} | tail -n +2 | awk '{ print $1 }'); do
            # This is the most stupid way to check if all layer were downloaded correctly.
            # But it is the fastest one. The docker save command takes about 30 Minutes for all images,
            # even with output piped to /dev/null.
            if [[ ! -e ${MOUNTROOT}/var/lib/docker/overlay/${layer} || ! -e ${MOUNTROOT}/var/lib/docker/graph/${layer} ]]; then
                echo "Image '${image}' arrived broken"
                exit 1
            fi
        done
    fi

    # TODO: Might wanna add --type=image for good measure once Docker 1.8 hits the CoreOS stable.
    local image_id=$(${DOCKER} inspect --format '{{.Id}}' ${image})
    image=${image#$REGISTRY/} # remove Registry prefix

    mkdir -p $(dirname ${IMAGE_STATE_DIR}/${image})
    echo $image_id > ${IMAGE_STATE_DIR}/${image}
    echo "DONE."
}


function finalize() {
    # prefetch buildstep. so the first deployment doesn't have to fetch it.
    download_and_verify_image experimentalplatform/buildstep:herokuish
    set_status "finalizing"
    if [ "$PLATFORM_INSTALL_RELOAD" = true ]; then
        echo "Reloading systemctl after update."
        systemctl restart init-protonet.service
        exit 0
    fi

    if [ "$PLATFORM_REMOVE_OLD_IMAGES" == "true" ]; then
      remove_old_images
    fi

    echo "===================================================================="
    echo "After the reboot your experimental platform will be reachable via:"
    echo "http://$(cat $HOSTNAME_FILE).local"
    echo "(don't worry, you can change this later)"
    echo "===================================================================="

}

function remove_old_images() {
  local ALL_PLATFORM_IMAGES SORTED_NEW_IMAGES

  ALL_PLATFORM_IMAGES=$($DOCKER images | awk '{print $1 ":" $2 }' | grep -e '^quay.io/experimentalplatform/.*' -e '^quay.io/protonetinc/.*' | sort)
  SORTED_NEW_IMAGES="$(
    for i in ${!IMGTAGLIST[@]}; do
      echo ""$i:${IMGTAGLIST[$i]}""
    done | sort
  )"

  comm -23 <(echo "$ALL_PLATFORM_IMAGES") <(echo "$SORTED_NEW_IMAGES") | xargs --no-run-if-empty ${DOCKER} rmi || true
}


function setup_udev() {
    echo -n "Setting up UDEV rules..."
    cp /config/sound-permissions.rules ${MOUNTROOT}/etc/udev/rules.d/sound-permissions.rules
    cp /config/video-permissions.rules ${MOUNTROOT}/etc/udev/rules.d/video-permissions.rules
    cp /config/tty-permissions.rules   ${MOUNTROOT}/etc/udev/rules.d/tty-permissions.rules
    cp /config/80-protonet.rules   ${MOUNTROOT}/etc/udev/rules.d/80-protonet.rules
    udevadm control --reload-rules || true
    echo "DONE."
}


function setup_utility_scripts () {
    # Automates installation of utility scripts and services from scripts/* into
    # $PATH on target systems.
    echo "Installing scripts:"
    ETC_PATH=${ETC_PATH:=${MOUNTROOT}/etc/}
    BIN_PATH=${BIN_PATH:=${MOUNTROOT}/opt/bin/}
    for f in scripts/*.sh; do
        name=$(basename ${f} .sh)
        dest=${ETC_PATH}systemd/system/scripts/${name}.sh
        echo -ne "\t * '${name}' to ${dest}... "
        cp /scripts/${name}.sh ${dest}
        chmod +x ${dest}
        if [ -d ${BIN_PATH} ]; then
        # this needs to be the full path on host, not in container
        ln -sf /etc/systemd/system/scripts/${name}.sh ${BIN_PATH}${name}
        fi
        echo "DONE."
    done
    cp /button ${BIN_PATH}
    cp /tcpdump "${BIN_PATH}"
    cp /speedtest "${BIN_PATH}"
    cp /masterpassword "${BIN_PATH}"
    cp /ipmitool "${BIN_PATH}"
    cp /self_destruct "${MOUNTROOT}/opt/"
    echo "ALL DONE"
}


function rescue_legacy_script () {
    if [[ -d "/host-bin" ]]; then
        echo "Legacy script detected... "
        ETC_PATH="/data/"
        BIN_PATH="/host-bin/"
        setup_utility_scripts
        set_status "Legacy script detected... RUN UPDATE AGAIN TO FIX THIS."
        echo -e "\n\nRUN UPDATE AGAIN TO FIX THIS.\n\n"
        exit 42
    else
        setup_utility_scripts
    fi
}

parse_template() {
  local SERVICE_FILE IMAGE TAG
  SERVICE_FILE="$1"

  IMAGE=$((grep -oe 'quay.io/[a-z]*/[a-z0-9\-]*' "$SERVICE_FILE" || true) | head -n1)
  if [ -z "$IMAGE" ]; then return; fi
  TAG="${IMGTAGLIST[$IMAGE]}"
  echo -e "Building '${SERVICE_FILE}' with IMAGE '$IMAGE' and TAG '$TAG':"
  pystache "$(<$SERVICE_FILE)" "{\"tag\":\"$TAG\"}" > ${SERVICE_FILE}.new
  mv ${SERVICE_FILE}.new ${SERVICE_FILE}
}

parse_all_templates() {
  for SERVICE_FILE in services/*
  do
    parse_template "$SERVICE_FILE"
  done
}

trap "/button error >/dev/null 2>&1 || true" SIGINT SIGTERM EXIT

/button "rainbow" >/dev/null 2>&1 || true
setup_paths
# FIRST: Update the platform-configure.script itself!
rescue_legacy_script
# Now the stuff that may break...
fetch_module_image_data

if [ "${TEMPLATES_ONLY:-"false"}" == "true" ]; then
  /button "hdd" >/dev/null 2>&1 || true
  parse_all_templates
  exit 0
fi

pull_all_images
parse_all_templates

if grep -qE '^#?DefaultTimeoutStopSec=.*' /mnt/etc/systemd/system.conf; then
  sed -E 's/^#?DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=150s/' -i /mnt/etc/systemd/system.conf
else
  echo 'DefaultTimeoutStopSec=150s' >> /mnt/etc/systemd/system.conf
fi

cleanup_systemd
setup_udev
/button "rainbow" >/dev/null 2>&1 || true
setup_systemd
setup_channel_file
finalize
trap - SIGINT SIGTERM EXIT
/button "shimmer" >/dev/null 2>&1 || true

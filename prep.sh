#!/bin/bash
set -e
set -o pipefail

MOUNTROOT=${MOUNTROOT:="/mnt"}
CHANNEL=${CHANNEL:="development"}
PLATFORM_REMOVE_OLD_IMAGES=${PLATFORM_REMOVE_OLD_IMAGES:="true"}
MANIFEST_URL=${MANIFEST_URL:='https://raw.githubusercontent.com/protonet/builds/master/$CHANNEL.json'}
DOCKER="/docker"
NEWBUILDNUMBER=
declare -A IMGTAGLIST

function is_float() {
  [ -z "$@" ] && return 1
  grep -q -P '^\d*(\.\d+)?$' <<< "$@"
}


function build_status_json() {
  local STATUS PROGRESS WHAT JSON

  # status
  JSON="$(jq --arg status "$1" '.status = $status' -n)"

  # progress
  if [ $# -gt 1 ]; then
    if is_float "$2"; then
      JSON="$(jq --argjson progress "$2" '.progress = $progress' <<< "$JSON")"
    else
      JSON="$(jq --arg progress null '.progress = $progress' <<< "$JSON")"
    fi
  fi

  # the "what"
  if [ $# -gt 2 ]; then
    JSON="$(jq --arg what "$3" '.what = $what' <<< "$JSON")"
  fi

  echo "$JSON"
}


function set_status() {
  mkdir -p ${MOUNTROOT}/etc/protonet/system
  build_status_json $@ > ${MOUNTROOT}/etc/protonet/system/configure-script-status
}


function fetch_release_json() {
  local CHANNEL JSON JQSCRIPT
  CHANNEL="$1"
  curl --fail --silent "$(eval echo "$MANIFEST_URL")"
}

function fetch_release_data() {
  local JSONIMGLIST JSONDATA

  JSONDATA="$(fetch_release_json "$CHANNEL")"

  JQSCRIPT_IMAGES='max_by(.build) | .images | keys[] as $k | $k + ":" + .[$k]'
  JQSCRIPT_BUILDNO='max_by(.build) | .build'
  JQSCRIPT_CODENAME='max_by(.build) | .codename'
  JQSCRIPT_RELEASENOTES='max_by(.build) | .url'
  JSONIMGLIST="$(jq "$JQSCRIPT_IMAGES" --raw-output <<< "$JSONDATA")"
  NEWBUILDNUMBER="$(jq "$JQSCRIPT_BUILDNO" --raw-output <<< "$JSONDATA")"
  NEWCODENAME="$(jq "$JQSCRIPT_CODENAME" --raw-output <<< "$JSONDATA")"
  NEWRELEASENOTESURL="$(jq "$JQSCRIPT_RELEASENOTES" --raw-output <<< "$JSONDATA")"

  for img in ${JSONIMGLIST}; do
    # this splits a line in the format 'A:B' and assigns IMGTAGLIST[A]=B
    IFS=':' read -ra I <<< "$img"
    IMGTAGLIST[${I[0]}]=${I[1]}
  done
}

function pull_all_images() {
  local IMG_TOTAL=${#IMGTAGLIST[@]}
  local CURR_IMG_COUNT=0
  local STATUS_PROGRESS

  for i in ${!IMGTAGLIST[@]}; do
    STATUS_PROGRESS="$(jq -n "$CURR_IMG_COUNT/$IMG_TOTAL*100")"
    set_status downloading_image "$STATUS_PROGRESS" "$i"
    download_and_verify_image "$i:${IMGTAGLIST[$i]}"
    CURR_IMG_COUNT=$((CURR_IMG_COUNT+1))
  done
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


function systemd_enable_units() {
    if [ $# -eq 0 ]; then return; fi
    busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager EnableUnitFiles asbb $# $@ false true
}


function systemd_daemon_reload() {
    busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager Reload
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
    systemd_daemon_reload
    # Make sure we're actually waiting for the network if it's required.
    systemd_enable_units systemd-networkd-wait-online.service
    echo "ENABLing all config files."
    systemd_enable_units $(find ${MOUNTROOT}/etc/systemd/system -maxdepth 1 ! -name "*.sh" -type f | \
      xargs --no-run-if-empty basename -a )
    echo "RESTARTing all .path files."
    systemd_enable_units $(find ${MOUNTROOT}/etc/systemd/system -maxdepth 1 -name "*.path" -type f | \
      xargs --no-run-if-empty basename -a )
    echo "DONE."
}


function setup_channel_file() {
    # update the channel file in case there's none or if we're changing channels.
    # TODO: Bail if either CHANNEL or CHANNEL_FILE are not set
    echo -n "Detecting channel... "
    if [[ ! -f ${CHANNEL_FILE} ]] || [[ ! $(cat ${CHANNEL_FILE}) = "${CHANNEL}" ]]; then
        echo -n "using NEW '${CHANNEL}'... "
        busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager StopUnit 'ss' trigger-update-protonet.path replace
        sleep 1
        mkdir -p $(dirname ${CHANNEL_FILE})
        echo ${CHANNEL} > ${CHANNEL_FILE}
        busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager StartUnit 'ss' trigger-update-protonet.path replace
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
        echo -n " Pull failed, retrying.... "
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
    # save the current release information to SKVS
    mkdir -p ${MOUNTROOT}/etc/protonet/system
    echo -n "$NEWBUILDNUMBER" > ${MOUNTROOT}/etc/protonet/system/release_number
    echo -n "$NEWCODENAME" > ${MOUNTROOT}/etc/protonet/system/codename
    echo -n "$NEWRELEASENOTESURL" > ${MOUNTROOT}/etc/protonet/system/release_notes_url
    sync

    set_status "finalizing"
    if [ "$PLATFORM_INSTALL_RELOAD" = true ]; then
        echo "Reloading SystemD after update."
        systemd_daemon_reload
        busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager RestartUnit 'ss' init-protonet.service replace
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

    # must be '-not -name protonet_zpool.sh' or it will break the bootstick
    # must be '-not -name platconf' or it will remove existing platconf
    find ${BIN_PATH} -mindepth 1 -not -name protonet_zpool.sh -not -name platconf -delete
    find ${ETC_PATH}systemd/system/scripts/ -mindepth 1 -delete
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

    cp /binaries/* "${BIN_PATH}"

    # don't overwrite existing
    if [[ ! -x "${BIN_PATH}/platconf" ]]; then
      echo "Pre-installing platconf"
      cp /platconf "${BIN_PATH}/platconf"
    fi

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
fetch_release_data

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

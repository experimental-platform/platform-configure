#!/bin/bash
set -e

MOUNTROOT=${MOUNTROOT:="/mnt"}
CHANNEL=${CHANNEL:="development"}
TEMPLATES_ONLY=${TEMPLATES_ONLY:-"false"}
declare -A MODULES JSONIMGLISTS IMGTAGLIST


print_usage() {
	echo "Usage: $0 [-m module:channel] [-m module:channel] ..."
}


function parse_params() {
  while [[ $# > 0 ]]; do
    key="$1"
    case $key in
      -m|--module)
        MODULES[$1]="$2"
        shift
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        print_usage
        exit 1
        ;;
    esac
    shift # past argument or value
  done
}


function read_modules() {
  for i in /mnt/etc/protonet/system/channels/*; do
    local MOD CHAN
    MOD="$(basename "$i" | sed 's/^[0-9]*_//')"
    CHAN=$(<$i)
    MODULES[$MOD]="$CHAN"
  done
}


function fetch_module_images() {
  local MOD CHANNEL JSON
  MOD="$1"
  CHANNEL="$2"
  JSON="$(curl --fail --silent "https://raw.githubusercontent.com/protonet/builds/test/$MOD/$CHANNEL.json")"
  echo "$JSON" | jq 'keys[] as $k | $k + ":" + .[$k]' --raw-output
}


function fetch_all_module_image_data() {
  declare -A IMGLISTS

  for m in ${!MODULES[@]}; do
    local MODULE TAG
    echo "Fetching image list for module '$m', channel '${MODULES[$m]}'"
    JSONIMGLISTS[$m]="$(fetch_module_images $m ${MODULES[$m]})"
  done

  for m in ${!JSONIMGLISTS[@]}; do
    for img in ${JSONIMGLISTS[$m]}; do
      IFS=':' read -ra I <<< "$img"
      IMGTAGLIST[${I[0]}]=${I[1]}
    done
  done
}


function pull_all_images() {
  for m in ${!JSONIMGLISTS[@]}; do
    for img in ${JSONIMGLISTS[$m]}; do
      download_and_verify_image $img
    done
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
    grep -Hlr '# ExperimentalPlatform' ${MOUNTROOT}/etc/systemd/system/ | xargs rm -rf
    # do it again to remove garbage
    find -L ${MOUNTROOT}/etc/systemd/system/ -type l -exec rm -f {} +
    grep -Hlr '# ExperimentalPlatform' ${MOUNTROOT}/etc/systemd/network | xargs rm -rf
    echo "DONE."
}


function setup_systemd() {
    echo -n "Setting up systemd services... "
    cp /services/* ${MOUNTROOT}/etc/systemd/system/
    cp /config/50-log-warn.conf ${MOUNTROOT}/etc/systemd/system/docker.service.d/50-log-warn.conf
    cp /config/journald_protonet.conf ${MOUNTROOT}/etc/systemd/journald.conf.d/journald_protonet.conf
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


function download_and_verify_image() {
    local image=$1
    echo -ne "\t Image ${image}..."
    DOCKER="/docker"
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
                ${DOCKER} tag -f "${image}-previous" ${image} 2>/dev/null
                # TODO: return instead?
                exit 1
            fi
        done
    fi
    echo "DONE."
}


function finalize() {
    # prefetch buildstep. so the first deployment doesn't have to fetch it.
    download_and_verify_image experimentalplatform/buildstep:herokuish
    # Complex regexp to find all images names in all service files

    set_status "finalizing"
    if [ "$PLATFORM_INSTALL_RELOAD" = true ]; then
        echo "Reloading systemctl after update."
        systemctl restart init-protonet.service
        exit 0
    fi
    if [ "$PLATFORM_INSTALL_OSUPDATE" = true ]; then
        echo "Updating CoreOS system image."
        update_os_image || true
    fi

    echo "===================================================================="
    echo "After the reboot your experimental platform will be reachable via:"
    echo "http://$(cat $HOSTNAME_FILE).local"
    echo "(don't worry, you can change this later)"
    echo "===================================================================="

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

parse_params
if [ ${#MODULES[@]} -eq 0 ]; then
  read_modules
fi

fetch_all_module_image_data

if [ "$TEMPLATES_ONLY" == "true" ]; then
  /button "hdd" >/dev/null 2>&1 || true
  parse_all_templates
  exit 0
fi

pull_all_images
# Now the stuff that may break...
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
finalize
trap - SIGINT SIGTERM EXIT
/button "shimmer" >/dev/null 2>&1 || true

#!/bin/bash
set -e

MOUNTROOT=${MOUNTROOT:="/mnt"}
DOCKER=$(which docker)


function set_status() {
  mkdir -p ${MOUNTROOT}/etc/protonet/system
  echo "$@" > ${MOUNTROOT}/etc/protonet/system/configure-script-status
}


function setup_paths() {
    # new systems need sometimes dont have systemd/system/
    mkdir -p ${MOUNTROOT}/etc/systemd/journald.conf.d
    mkdir -p ${MOUNTROOT}/etc/systemd/system/
    mkdir -p ${MOUNTROOT}/etc/systemd/system/docker.service.d
    mkdir -p ${MOUNTROOT}/etc/systemd/system/scripts/
    mkdir -p ${MOUNTROOT}/etc/udev/rules.d
}


function cleanup_systemd() {
    # First remove broken links, this should avoid confusing error messages
    find -L ${MOUNTROOT}/etc/systemd/system/ -type l -exec rm -f {} +
    grep -Hlr '# ExperimentalPlatform' ${MOUNTROOT}/etc/systemd/system/ | xargs rm -rf
    # do it again to remove garbage
    find -L ${MOUNTROOT}/etc/systemd/system/ -type l -exec rm -f {} +
    grep -Hlr '# ExperimentalPlatform' ${MOUNTROOT}/etc/systemd/network | xargs rm -rf
}


function setup_systemd() {
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
}


function setup_channel_file() {
    # update the channel file in case there's none or if we're changing channels.
    # TODO: Bail if either CHANNEL or CHANNEL_FILE are not set
    if [[ ! -f ${CHANNEL_FILE} ]] || [[ ! $(cat ${CHANNEL_FILE}) = "${CHANNEL}" ]]; then
        echo "NEW channel is '${CHANNEL}'."
        systemctl stop trigger-update-protonet.path
        mkdir -p $(dirname ${CHANNEL_FILE})
        echo ${CHANNEL} > ${CHANNEL_FILE}
        systemctl start trigger-update-protonet.path
    else
        echo "Keeping old channel '${CHANNEL}'."
    fi
}


function download_and_verify_image() {
    # TODO: DUPLICATED CODE MARK
    # TODO: Bail if IMAGE_STATE_DIR or REGISTRY is not set
    local image=$1
    ${DOCKER} tag -f ${image} "${image}-previous" 2>/dev/null || true # do not fail, this is just for backup reason
    ${DOCKER} pull ${image}

    local driver=$(${DOCKER} info | grep '^Storage Driver: ' | sed -r 's/^Storage Driver: (.*)/\1/')
    # if using OverlayFS then verify layers
    if [ "${driver}" == "overlay" ]; then
        # TODO: this basically works with ZFS too, it just has slightly different path names
        for layer in $(docker history --no-trunc ${image} | tail -n +2 | awk '{ print $1 }'); do
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

    # TODO: Might wanna add --type=image for good measure once Docker 1.8 hits the CoreOS stable.
    local image_id=$(docker inspect --format '{{.Id}}' ${image})
    image=${image#$REGISTRY/} # remove Registry prefix

    mkdir -p $(dirname ${IMAGE_STATE_DIR}/${image})
    echo $image_id > ${IMAGE_STATE_DIR}/${image}
}


function setup_images() {
    # Pre-Fetch all Images
    # When using a feature branch most images come from the development channel:
    available_channels="development alpha beta stable"
    if [[ ! ${available_channels} =~ ${CHANNEL} ]]; then
        echo "We're on feature channel '${CHANNEL}'"
        CHANNEL=development
    fi

    # prefetch buildstep. so the first deployment doesn't have to fetch it.
    download_and_verify_image experimentalplatform/buildstep:herokuish
    # Complex regexp to find all images names in all service files
    IMAGES=$(gawk '!/^\s*[a-zA-Z0-9]+=|\[|^#|^\s*$|^\s*\-|^\s*bundle/ { sub("[^a-zA-Z0-9/:@.-]", "", $1); print $1}' ${MOUNTROOT}/etc/systemd/system/*.service | sort | uniq)
    IMG_NUMBER=$(echo "${IMAGES}" | wc -l)
    IMG_COUNT=0
    for IMAGE in ${IMAGES}; do
        set_status "image $IMG_COUNT/$IMG_NUMBER"
        # download german-shepherd and soul ony if soul is enabled.
        if [[ "experimentalplatform/german-shepherd experimentalplatform/soul-nginx" =~ ${IMAGE%:*} ]]; then
            if [[ -f "${MOUNTROOT}/etc/protonet/soul/enabled" ]]; then
                download_and_verify_image ${IMAGE}
            fi
        else
            download_and_verify_image ${IMAGE}
        fi
        IMG_COUNT=$((IMG_COUNT+1))
    done
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
    cp /config/sound-permissions.rules ${MOUNTROOT}/etc/udev/rules.d/sound-permissions.rules
    cp /config/video-permissions.rules ${MOUNTROOT}/etc/udev/rules.d/video-permissions.rules
    cp /config/tty-permissions.rules   ${MOUNTROOT}/etc/udev/rules.d/tty-permissions.rules
    cp /config/80-protonet.rules       ${MOUNTROOT}/etc/udev/rules.d/80-protonet.rules
}


function setup_utility_scripts () {
    # Automates installation of utility scripts and services from scripts/* into
    # $PATH on target systems.
    for f in scripts/*.sh; do
      name=$(basename ${f} .sh)
      dest=${MOUNTROOT}/etc/systemd/system/scripts/${name}.sh
      echo "Installing ${name} to ${dest}"

      cp /scripts/${name}.sh ${dest}
      chmod +x ${dest}
      if [ -d ${MOUNTROOT}/opt/bin/ ]; then
        # this needs to be the full path on host, not in container
        ln -sf /etc/systemd/system/scripts/${name}.sh ${MOUNTROOT}/opt/bin/${name}
      fi
    done
    cp /button ${MOUNTROOT}/opt/bin/
}

# FIRST: Update the platform-configure.script itself!
setup_utility_scripts
# Now the stuff that may break...
setup_paths
cleanup_systemd
setup_udev
setup_systemd
setup_channel_file
setup_images
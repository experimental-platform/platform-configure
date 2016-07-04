#!/usr/bin/env bash
set -e


# Copyright 2015 Protonet GmbH
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

function set_variables() {
    PLATFORM_BASENAME=${PLATFORM_BASENAME:=""}
    UPDATE_CONF=${PLATFORM_BASENAME}/etc/coreos/update.conf
    UPDATE_ENGINE_CONFIG=${PLATFORM_BASENAME}/etc/coreos/update.conf
    PROTONET_PUBKEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5CfJQVP2yJlcMu/3/RxD
KnOvcxD40VWsDiUn/FDXlcgQWpg/xH2a7LD9bpD4c3+jWtUst+I7ZhL11YiyfQDr
Afw9m11RiHtl+fvJfLg8PwuQ25jc5Cf/hLn+NpnFxL4vlifNWljIoIh17j3KE0hj
jd/V7435gkIm0eIvTiebn4cposzh74XrlOnsGyTTyPJ4IMcnS3zYdOIAeTKoSMea
rUIsXC8jYMQtua8q96eqM3bPsvFLBWRRQoTfRtVSfydNbZp+i1SixVKo4oDz9UmF
fNLAJRPgRI+pXV0O6MdmPtKu5dQNkVGAYm7RWbxZctGxsOArXE43OjqE6kGLVabw
7QIDAQAB
-----END PUBLIC KEY-----"
}


function is_update_key_protonet() {
    key_path="${PLATFORM_BASENAME}/usr/share/update_engine/update-payload-key.pub.pem"
    current_digest=$(cat "$key_path" | sha1sum | cut -f1 -d ' ')
    protonet_digest=$(echo "$PROTONET_PUBKEY" | sha1sum | cut -f1 -d ' ')
    if [[ "$current_digest" == "$protonet_digest" ]]; then
        return 0
    else
        return 1
    fi
}


function prepare_os_update() {
	# in case there was an automatic update already running
	update_engine_client -reset_status

	# just in case someone left a key mount
    umount ${PLATFORM_BASENAME}/usr/share/update_engine/update-payload-key.pub.pem &>/dev/null || true
	if ! is_update_key_protonet; then
        echo "$PROTONET_PUBKEY" > ${PLATFORM_BASENAME}/tmp/protonet-image.pub.pem
        mount --bind ${PLATFORM_BASENAME}/tmp/protonet-image.pub.pem ${PLATFORM_BASENAME}/usr/share/update_engine/update-payload-key.pub.pem
  fi
}


function enable_os_updates() {
    # TODO: Bail if either PLATFORM_SYS_GROUP or UPDATE_ENGINE_CONFIG or  are not set
    if [[ -z "${PLATFORM_SYS_GROUP}" ]]; then
        if [ -e ${UPDATE_ENGINE_CONFIG} ]; then
            PLATFORM_SYS_GROUP=$(cat ${UPDATE_ENGINE_CONFIG} | grep '^GROUP=' | cut -f2 -d '=')
            echo "Using OS group '${PLATFORM_SYS_GROUP}' from ${UPDATE_ENGINE_CONFIG}."
        else
            PLATFORM_SYS_GROUP="protonet"
            echo "No OS group given. Using '${PLATFORM_SYS_GROUP}' (default group)."
        fi
    else
        echo "Using OS group '${PLATFORM_SYS_GROUP}' from the command line."
    fi

    # reset backoff timestamp
    rm -f ${PLATFORM_BASENAME}/var/lib/update_engine/prefs/backoff-expiry-time

    # configure update source
    echo | tee ${UPDATE_CONF} &>/dev/null <<- EOM
GROUP=${PLATFORM_SYS_GROUP}
SERVER=https://coreos-update.protorz.net/update
REBOOT_STRATEGY=off
EOM

	# apply changes to update-engine
	systemctl restart update-engine.service

    # in case we mounted a downloaded key
    umount ${PLATFORM_BASENAME}/usr/share/update_engine/update-payload-key.pub.pem &>/dev/null || true
    rm -f ${PLATFORM_BASENAME}/tmp/protonet-image.pub.pem || true
}

function update_os_image() {
    # run update and save its exit code
    echo "Forcing system image update"
    update_engine_client -update &>/dev/null | true
    update_status=${PIPESTATUS[0]}
    echo "Done."

    if [[ "$update_status" -eq 0 ]]; then
        echo "System image update successfull."
        return 0
    else
        echo "System image update failed."
        return 1
    fi
}



set_variables
prepare_os_update
enable_os_updates
update_os_image
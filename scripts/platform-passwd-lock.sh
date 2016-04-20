#!/usr/bin/env bash

set -e

: ${PASSWD_LOCK_FILE:=/etc/protonet/system/ssh/lock}
: ${SUCCESS_FILE:=/etc/protonet/system/ssh/success}
: ${ERROR_FILE:=/etc/protonet/system/ssh/error}
: ${SYSTEM_USER:=platform}

logger -p INFO -s "Locking account '${SYSTEM_USER}'."

if [[ -f ${PASSWD_LOCK_FILE} ]]; then
    passwd -l ${SYSTEM_USER} | true
    status=${PIPESTATUS[0]}
    rm -f ${PASSWD_LOCK_FILE}
fi


if [[ ${status} == 0 ]]; then
    rm -f ${ERROR_FILE} || true
    echo 'Well done!' > ${SUCCESS_FILE}
    logger -p INFO -s "Successfully locked account ${SYSTEM_USER}."
    exit 0
else
    logger -s -p ERROR "An ERROR occurred locking account ${SYSTEM_USER}."
    if [[ -s ${ERROR_FILE} ]]; then
        logger -p ERROR -s -e -f ${ERROR_FILE}
    else
        echo 'Some error occurred.' > ${ERROR_FILE}
    fi
    rm -f ${SUCCESS_FILE} || true
    exit 23
fi

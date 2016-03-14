#!/usr/bin/env bash

set -e

: ${PASSWD_FILE:=/etc/protonet/system/ssh/password}
: ${SUCCESS_FILE:=/etc/protonet/system/ssh/success}
: ${ERROR_FILE:=/etc/protonet/system/ssh/error}
: ${SYSTEM_USER:=platform}

logger -p INFO -s "Setting password for user '${SYSTEM_USER}'."
# remove all newlines
PASSWD_STRING=$(echo ${SYSTEM_USER}:$(awk '{ printf $1 }' ${PASSWD_FILE}))

# set the password
chpasswd <<< "${PASSWD_STRING}" 2>${ERROR_FILE} | true
status=${PIPESTATUS[0]}

if [[ ${status} == 0 ]]; then
    rm -f ${ERROR_FILE} || true
    echo 'Well done!' > ${SUCCESS_FILE}
    logger -p INFO -s "Successfully changed password for user ${SYSTEM_USER}."
    exit 0
else
    logger -s -p ERROR "An ERROR occurred setting the password for user ${SYSTEM_USER}."
    if [[ -s ${ERROR_FILE} ]]; then
        logger -p ERROR -s -e -f ${ERROR_FILE}
    else
        echo 'Some error occurred.' > ${ERROR_FILE}
    fi
    rm -f ${SUCCESS_FILE} || true
    exit 23
fi


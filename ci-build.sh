#!/bin/bash
set -e

DEBUG=/bin/false

${DEBUG} && set -x

# VERSION is the branch THIS REPO is on, usually this will be 'development'
VERSION=${VERSION:=$TRAVIS_BRANCH}
# SERVICE_TAG ist the name of the feature branch the SERVICE_NAME is on
SERVICE_TAG=${SERVICE_TAG:=$TRAVIS_BRANCH}
# SERVICE_NAME is the name of a service on a feature branch


echo -e "\nBuilding platform-configure VERSION '${VERSION}', SERVICE_TAG '${SERVICE_TAG}', SERVICE_NAME '${SERVICE_NAME}', CHANNEL '${CHANNEL}'.\n\n"

# CASE 1: We build an exciting new (feature) branch. That means:
# 1. there is one systemd service file (SERVICE_NAME) that links to the special docker tag SERVICE_TAG (a.k.a. the branch name)
# 2. the docker image for platform-configure (this project) will be tagged with SERVICE_TAG
if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
    SERVICE_FILE=services/${SERVICE_NAME}-protonet.service
    if [ -e ${SERVICE_FILE} ]; then
        echo -e "\n\nBuilding '${SERVICE_FILE}' with TAG '${SERVICE_TAG}':"
        echo "{\"tag\":\"$SERVICE_TAG\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
        mv ${SERVICE_FILE}.new ${SERVICE_FILE}
    fi
fi

# CASE 2: We're building platform-configure itself on a (feature) branch
available_channels="development alpha beta stable soul3"
if [[ -z ${SERVICE_NAME} ]] && [[ -z ${CHANNEL} ]] && [[ ${VERSION} == ${SERVICE_TAG} ]] && [[ ! ${available_channels} =~ ${VERSION} ]]; then
    echo -e "\nplatform-configure feature branch build detected, setting VERSION to 'development'"
    VERSION=development
fi

# CASE 3: Build everything else on a boring old branch, (usually 'development').
for SERVICE_FILE in services/*
do
    echo -e "\n\nBuilding '${SERVICE_FILE}' with VERSION '${VERSION}':"
    echo "{\"tag\":\"${VERSION}\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
    mv ${SERVICE_FILE}.new ${SERVICE_FILE}
done


# Download current version of platform-configure.sh
echo -e "\n\nAdding 'platform-configure-script' with VERSION 'development':"
curl -f https://raw.githubusercontent.com/experimental-platform/platform-configure-script/master/platform-configure.sh > scripts/platform-configure.sh


echo -e "\n\n\nALL DONE.\n\n\n"
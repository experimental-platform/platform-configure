#!/bin/bash
set -e

DEBUG=/bin/false

${DEBUG} && set -x

# VERSION is the branch THIS REPO is on, usually this will be 'development'
VERSION=${VERSION:=$CIRCLE_BRANCH}
# SERVICE_NAME is the name of a service on a feature branch
# SERVICE_TAG ist the name of the feature branch the SERVICE_NAME is on


echo -e "\nBuilding platform-configure version '${VERSION}', service_tag '${SERVICE_TAG}', service_name '${SERVICE_NAME}', channel '${CHANNEL}'.\n\n"

# CASE 1: We build an exciting new (feature) branch. That means:
# 1. there is one systemd service file (SERVICE_NAME) that links to the special docker tag SERVICE_TAG (a.k.a. the branch name)
# 2. the docker image for platform-configure (this project) will be tagged with SERVICE_TAG
if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  SERVICE_FILE=services/${SERVICE_NAME}-protonet.service
  if [ -e ${SERVICE_FILE} ]; then
    echo "{\"tag\":\"$SERVICE_TAG\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
    mv ${SERVICE_FILE}.new ${SERVICE_FILE}
  fi
fi

# CASE 2: Build everything else on a boring old branch, (usually 'development').
for SERVICE_FILE in services/*
do
  echo "{\"tag\":\"${VERSION}\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
  mv ${SERVICE_FILE}.new ${SERVICE_FILE}
done


# Download current version of platform-configure.sh
curl -f https://raw.githubusercontent.com/experimental-platform/platform-configure-script/master/platform-configure.sh > platform-configure.sh

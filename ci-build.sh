#!/bin/bash
set -e

DEBUG=/bin/false

${DEBUG} && set -e

# Current branch name will be default Version if nothing else is set
VERSION=${VERSION:=${GIT_BRANCH#*/}}
SERVICE_TAG=${SERVICE_TAG#*/}

echo -e "\nBuilding platform-configure version ${VERSION}, service_tag ${SERVICE_TAG}.\n\n"

${DEBUG} && echo -e "(DEBUG) CHANNEL: ${CHANNEL}\n\n"

if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  SERVICE_FILE=services/${SERVICE_NAME#platform-}-protonet.service

  if [ -e ${SERVICE_FILE} ]; then
    echo "{\"tag\":\"$SERVICE_TAG\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
    mv ${SERVICE_FILE}.new ${SERVICE_FILE}
  fi
fi

for SERVICE_FILE in services/*
do
  echo "{\"tag\":\"${VERSION}\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
  mv ${SERVICE_FILE}.new ${SERVICE_FILE}
done

# Download current version of platform-configure.sh
curl https://git.protorz.net/AAL/platform-configure-script/raw/master/platform-configure.sh > platform-configure.sh

if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  # this configure build image needs to be tagged with SERVICE_TAG
  echo "GIT_BRANCH = $SERVICE_TAG" > export.props
fi

# Cannot push with deploy key :)
# git commit --all --message="Jenkins Build ${BUILD_NUMBER} for ${VERSION}." --author="Jack Jenkins <jenkins@protonet.info>"
# git push origin HEAD:build/${VERSION}/${BUILD_NUMBER}

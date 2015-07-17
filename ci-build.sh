#!/bin/bash
set -e

DEBUG=/bin/false

${DEBUG} && set -x

# Current branch name will be default Version if nothing else is set
VERSION=${VERSION:=${GIT_BRANCH#*/}}
SERVICE_TAG=${SERVICE_TAG#*/}

echo -e "\nBuilding platform-configure version '${VERSION}', service_tag '${SERVICE_TAG}', service_name '${SERVICE_NAME}'.\n\n"

${DEBUG} && echo -e "(DEBUG) CHANNEL: ${CHANNEL}\n\n"

if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  SERVICE_FILE=services/${SERVICE_NAME#platform-}-protonet.service
  ${DEBUG} && echo "DEBUG: Trying to write unique file '${SERVICE_FILE}'."
  if [ -e ${SERVICE_FILE} ]; then
    echo "{\"tag\":\"$SERVICE_TAG\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
    mv ${SERVICE_FILE}.new ${SERVICE_FILE}
    ${DEBUG} && echo "DEBUG: Unique file '${SERVICE_FILE}' written successfully."
  fi
fi

for SERVICE_FILE in services/*
do
  ${DEBUG} && echo "DEBUG: Trying to write file '${SERVICE_FILE}'."
  echo "{\"tag\":\"${VERSION}\"}" | mustache - ${SERVICE_FILE} > ${SERVICE_FILE}.new
  mv ${SERVICE_FILE}.new ${SERVICE_FILE}
  ${DEBUG} && echo "DEBUG: File '${SERVICE_FILE}' written successfully."
done

${DEBUG} && echo "DEBUG: START Fetching current version of platform-configure.sh."
# Download current version of platform-configure.sh
curl -f https://git.protorz.net/AAL/platform-configure-script/raw/master/platform-configure.sh > platform-configure.sh
${DEBUG} && echo "DEBUG: DONE Fetching current version of platform-configure.sh."

if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  ${DEBUG} && echo "DEBUG: Tagging file '${SERVICE_NAME}' with TAG '${SERVICE_TAG}'."
  # this configure build image needs to be tagged with SERVICE_TAG
  echo "GIT_BRANCH = $SERVICE_TAG" > export.props
fi

${DEBUG} && echo "DEBUG: DONE."

# Cannot push with deploy key :)
# git commit --all --message="Jenkins Build ${BUILD_NUMBER} for ${VERSION}." --author="Jack Jenkins <jenkins@protonet.info>"
# git push origin HEAD:build/${VERSION}/${BUILD_NUMBER}

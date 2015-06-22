#!/bin/bash
VERSION=${VERSION:=development}

if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$SERVICE_TAG" ]; then
  SERVICE_FILE=services/${SERVICE_NAME#platform-}-protonet.service

  if [ -e $SERVICE_FILE ]; then
    echo "{\"tag\":\"$SERVICE_TAG\"}" | mustache - $SERVICE_FILE > $SERVICE_FILE.new
    mv $SERVICE_FILE.new $SERVICE_FILE
  fi
fi

for SERVICE_FILE in services/*
do
  echo "{\"tag\":\"$VERSION\"}" | mustache - $SERVICE_FILE > $SERVICE_FILE.new
  mv $SERVICE_FILE.new $SERVICE_FILE
done

git status

exit 1

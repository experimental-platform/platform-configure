#!/bin/bash
DOCKER=$(which docker)

update_image() {
  local image=$1
  $DOCKER tag -f $image:latest $image:previous

  $DOCKER pull $image:latest
  for layer in $(docker history --no-trunc $image:latest | tail -n +2 | awk '{ print $1 }'); do
    # This is the most stupid way to check if all layer were downloaded correctly.
    # But it is the fastest one. The docker save command takes about 30 Minutes for all images,
    # even with output piped to /dev/null.
    if [[ ! -e /var/lib/docker/overlay/$layer || ! -e /var/lib/docker/graph/$layer ]]; then
      echo "Layer '$layer' of '$image' missing. Switching to previous version."
      $DOCKER tag -f $image:previous $image:latest
      break 2
    fi
  done
}
for image in $(docker images | tail -n +2 | awk '/dockerregistry\.protorz\.net\/.+\s+latest/ { print $1 }'); do
  (update_image $image)
done

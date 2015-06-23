#!/bin/bash
set -e
DOCKER=$(which docker)
REGISTRY="dockerregistry.protorz.net"
CONTAINER_NAME="configure"

REBOOT=false
FETCH=false
DEBUG=false

function print_usage() {
  echo "usage: $0 [-r|--reboot] [-f|--fetch] [-d|--debug] [-h|--help] [-t|--tag tag]"
  echo "Flags:"
  echo -e "\t-r|--reboot\tReboot after update finished."
  echo -e "\t-f|--fetch\tFetch all new images after update."
  echo -e "\t-t|--tag\tUpdate to specified tag (default updates to newest version)."
  echo -e "\t-d|--debug\tEnable debug output."
  echo -e "\t-h|--help\tShow this help text."
}

while [[ $# > 0 ]]; do
  key="$1"
  case $key in
    -r|--reboot)
      REBOOT=true
      ;;
    -f|--fetch)
      FETCH=true
      ;;
    -d|--debug)
      DEBUG=true
      ;;
    -t|--tag)
      TAG="$2"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      # unknown option
    ;;
  esac
  shift # past argument or value
done

if [ DEBUG ]; then
  set -x
fi

if [ -z "$TAG" ]; then
  echo "Update to newest Tag is not implemented yet! Please specify tag via --tag option and run again!"
  exit 1
fi

# This is ugly and we need a read-only registry!
$DOCKER login -u protonet -p geheim -e alpha@experimental-platform.io $REGISTRY

$DOCKER pull $REGISTRY/configure:$TAG

# clean up running update task!
$DOCKER kill $CONTAINER_NAME 2>/dev/null || true
$DOCKER rm $CONTAINER_NAME 2>/dev/null || true

$DOCKER run --rm --name=$CONTAINER_NAME \
            --volume=/etc/:/data/ \
            --volume=/opt/bin/:/host-bin/ \
            $REGISTRY/configure:$TAG


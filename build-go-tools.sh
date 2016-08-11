#!/usr/bin/env bash

set -eu
set -o pipefail

export GO15VENDOREXPERIMENT=1

curl -L https://raw.githubusercontent.com/experimental-platform/misc/master/install-glide.sh | bash -s v0.11.1

mkdir -p binaries

for tooldir in go/*; do
  tool_name="$(basename $tooldir)"
  echo "Building $tool_name"

  echo " * Gliding up"
  docker run -v "$HOME/bin/glide:/usr/bin/glide:ro" -v "$(readlink -f $tooldir):/go/src/$tool_name" -w "/go/src/$tool_name" -e GO15VENDOREXPERIMENT=1 golang:1.5 glide up
  echo " * Building"
  docker run -v "$HOME/bin/glide:/usr/bin/glide:ro" -v "$(readlink -f $tooldir):/go/src/$tool_name" -w "/go/src/$tool_name" -e GO15VENDOREXPERIMENT=1 golang:1.5 go build
  echo " * Testing"
  docker run -v "$HOME/bin/glide:/usr/bin/glide:ro" -v "$(readlink -f $tooldir):/go/src/$tool_name" -w "/go/src/$tool_name" -e GO15VENDOREXPERIMENT=1 golang:1.5 go test -v

  mv "$tooldir/$tool_name" "binaries/"
done

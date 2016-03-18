#!/bin/bash
set -e
set -x

grep -q '{{tag}}' /system/*.{service,timer} && exit 1 || true
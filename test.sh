#!/bin/bash
set -e
set -x

grep -q '{{tag}}' /services/*.{service,timer} && exit 1 || true
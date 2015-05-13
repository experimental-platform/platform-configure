#!/bin/bash

find /data/ ! -name "update-protonet*" -delete && find /services/ ! -name "update-protonet*" -type f -exec cp {} /data \;
#!/bin/bash

find /data/ ! -name "update-protonet*" -type f -o -type l -delete && find /services/ ! -name "update-protonet*" -type f -exec cp {} /data \;
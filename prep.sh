#!/bin/bash

find /data/ ! -name "update-protonet*" -type f -delete -o -type l -delete && find /services/ ! -name "update-protonet*" -type f -exec cp {} /data \;

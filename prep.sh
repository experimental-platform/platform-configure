#!/bin/bash
echo -e "\n\nDEBUG START:\n"
ls -la /data
echo -e "\n\nDEBUG END\n"

find /data/ ! -name "update-protonet*" -type f -delete -o -type l -delete && find /services/ ! -name "update-protonet*" -type f -exec cp {} /data \;

cp /update-images-protonet.sh /data/update-images-protonet.sh

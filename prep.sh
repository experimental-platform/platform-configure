#!/bin/bash
grep -HlR --exclude="update-protonet*" '# ExperimentalPlatform' /data/ | xargs rm -rf
cp -R /services/ /data/

cp /update-images-protonet.sh /data/update-images-protonet.sh

#!/bin/bash
# First remove broken links, this should avoid confusing error messages
find -L /etc/systemd/system/ -type l -exec rm -f {} +
grep -HlR --exclude="update-protonet.service" '# ExperimentalPlatform' /data/ | xargs rm -rf
cp /services/* /data/

cp /update-images-protonet.sh /data/update-images-protonet.sh
cp /update-protonet.sh /data/update-protonet.sh

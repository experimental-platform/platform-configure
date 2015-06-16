#!/bin/bash
# First remove broken links, this should avoid confusing error messages
find -L /etc/systemd/system/ -type l -exec rm -f {} +
grep -Hlr --exclude="update-protonet.service" '# ExperimentalPlatform' /data/ | xargs rm -rf
# do it again to remove garbage
find -L /etc/systemd/system/ -type l -exec rm -f {} +
cp /services/* /data/

cp /update-images-protonet.sh /data/update-images-protonet.sh
cp /update-protonet.sh /data/update-protonet.sh

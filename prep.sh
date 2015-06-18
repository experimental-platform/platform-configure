#!/bin/bash
# First remove broken links, this should avoid confusing error messages
find -L /data/systemd/system/ -type l -exec rm -f {} +
grep -Hlr --exclude="update-protonet.service" '# ExperimentalPlatform' /data/systemd/system/ | xargs rm -rf
# do it again to remove garbage
find -L /data/systemd/system/ -type l -exec rm -f {} +
cp /services/* /data/systemd/system/

cp /stuff/update-images-protonet.sh /data/systemd/system/update-images-protonet.sh
cp /stuff/update-protonet.sh /data/systemd/system/update-protonet.sh
cp /stuff/journald_protonet.conf /data/systemd/journald.conf.d/journald_protonet.conf
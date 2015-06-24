# CoreOS + Vagrant

## Basics

1. install virtualbox
2. install vagrant
3. `$ git clone //github.com/coreos/coreos-vagrant.git`
4. set `$share_home = true` in `Vagrantfile`

## 1. Test the product deployment

1. `cd .. && git checkout git@git.protorz.net:AAL/deploy-product.git`
2. `cd - && ln -s ../deploy-product/cloud-config.yaml ./user-data`
3. `vagrant up && vagrant ssh`
4. `sudo journalctl -f`, sit back and observe how all components magically appear. ;)

## 2. Build and run Dockerfiles

1. `vagrant up`
2. `cd /Users/...wherever your Dockerfile resides/`
3. `docker build ...` and `docker run ...`

## 3. Install a CoreOS somewhere else [OUTDATED]

1. `vagrant up`
2. `vagrant down`
3. insert USB-to-someting-else-converter
4. open VirtualBox GUI, enable USB and add the device to the Vagrant VM
5. remove device
6. `vagrant up`
7. insert device
8. make sure the device is `/dev/sdb`
9. copy `cloud-config.yaml` from `git@git.protorz.net:AAL/deploy-product.git` to `/home/core/cloud-config.yaml` in the VM (vim is your friend)
10. `coreos-install -d /dev/sdb -o "" -c /home/core/cloud-config.yaml`

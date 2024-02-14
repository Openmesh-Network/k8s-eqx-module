#!/bin/bash

export HOME=/root
export PRODUCT_NAME=openmesh
export BUILD_DIR=$HOME/$PRODUCT_NAME-install

mkdir -p $BUILD_DIR

pvcreate /dev/sdb
vgcreate data-vg /dev/sdb
lvcreate -l 100%VG -n data-lv data-vg
mkfs.xfs /dev/data-vg/data-lv

mkdir -p /data
echo '/dev/data-vg/data-lv  /data  xfs defaults 0 0' | tee -a /etc/fstab
mount -a

apt-get update
apt-get install -y jq git inotify-tools gpg

while [ ! -f "$HOME/secrets.json" ]
do
  inotifywait -qqt 2 -e create -e moved_to "$(dirname $HOME/secrets.json)"
  echo "done"
done

export gh_username=$(jq -r .gh_username < $HOME/secrets.json)
export gh_pat=$(jq -r .gh_pat < $HOME/secrets.json)

export ROLE=$(curl --silent https://metadata.platformequinix.com/2009-04-04/meta-data/tags | jq -r .role)
git clone https://$gh_username:$gh_pat@github.com/Openmesh-Network/agent.git $BUILD_DIR/agent
pushd $BUILD_DIR/agent && git checkout main
chmod +x $BUILD_DIR/agent/install-$ROLE.sh && $BUILD_DIR/agent/install-$ROLE.sh

chmod +x $BUILD_DIR/agent/clean-up.sh && echo "/bin/bash $BUILD_DIR/agent/clean-up.sh" | at now + 1 hour

#!/bin/bash

export HOME=/root
export BUILD_DIR=$HOME/l3a

mkdir -p $BUILD_DIR

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
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/agent.git $BUILD_DIR/agent
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/infra-helm-charts.git $BUILD_DIR/infra-helm-charts
chmod +x $BUILD_DIR/agent/install-$ROLE.sh && $BUILD_DIR/agent/install-$ROLE.sh

sleep 5

mkdir -p /data/kafka

chmod +x $BUILD_DIR/agent/clean-up.sh && $BUILD_DIR/agent/clean-up.sh

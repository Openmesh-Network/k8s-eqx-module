#!/bin/bash

export HOME=/root
export BUILD_DIR=$HOME/l3a

mkdir -p $BUILD_DIR

apt-get update
apt-get install -y jq git inotify-tools docker.io gpg

while [ ! -f "$HOME/secrets.json" ]
do
  inotifywait -qqt 2 -e create -e moved_to "$(dirname $HOME/secrets.json)"
  echo "secret file not found, cowardly looping"
done

export gh_username=$(jq -r .gh_username < $HOME/secrets.json)
export gh_pat=$(jq -r .gh_pat < $HOME/secrets.json)

export ROLE=$(curl --silent https://metadata.platformequinix.com/2009-04-04/meta-data/tags | jq -r .role)
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/agent.git $BUILD_DIR/agent
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/infra-helm-charts.git $BUILD_DIR/infra-helm-charts
chmod +x $BUILD_DIR/agent/install-$ROLE.sh && $BUILD_DIR/agent/install-$ROLE.sh

sleep 5

while [ ! -f "/etc/kubernetes/admin.conf" ]
do
  inotifywait -qqt 2 -e create -e moved_to "$(dirname /etc/kubernetes/admin.conf)"
  echo "kubeconfig file not found, cowardly looping"
done

sleep 5

mkdir -p /data/postgres /data/prometheus /data/superset /data/zookeeper-logs /data/zookeeper-data

echo "installing l3a"
echo docker run -v $BUILD_DIR/agent/install-l3a.sh:/apps -v $BUILD_DIR/infra-helm-charts:/apps/infra-helm-charts -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) -e KUBECONFIG=/etc/kubernetes/admin.conf --entrypoint '/bin/bash' ahaiong/l3a-installer:latest "/apps/install-l3a.sh"

docker run \
  -v $BUILD_DIR/agent/install-l3a.sh:/apps/install-l3a.sh \
  -v $BUILD_DIR/infra-helm-charts:/apps/infra-helm-charts \
  -v $HOME/infra_config.json:/apps/infra_config.json \
  -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf \
  -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) \
  -e KUBECONFIG=/etc/kubernetes/admin.conf \
  --entrypoint '/bin/bash' \
  ahaiong/l3a-installer:latest "/apps/install-l3a.sh"

sleep 20

echo "enabling l3a features"
echo docker run -v $BUILD_DIR/agent/install-features.sh:/apps/install-features.sh -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf -v $HOME/features.json:/apps/features.json -e gh_username=REDACTED -e gh_pat=REDACTED -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) -e KUBECONFIG=/etc/kubernetes/admin.conf --entrypoint '/bin/bash' ahaiong/l3a-installer:latest "/apps/install-features.sh"

docker run \
  -v $BUILD_DIR/agent/install-features.sh:/apps/install-features.sh \
  -v $HOME/features.json:/apps/features.json \
  -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf \
  -e gh_username=$gh_username \
  -e gh_pat=$gh_pat \
  -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) \
  -e KUBECONFIG=/etc/kubernetes/admin.conf \
  --entrypoint '/bin/bash' \
  ahaiong/l3a-installer:latest "/apps/install-features.sh"

sleep 600

chmod +x $BUILD_DIR/agent/clean-up.sh && $BUILD_DIR/agent/clean-up.sh

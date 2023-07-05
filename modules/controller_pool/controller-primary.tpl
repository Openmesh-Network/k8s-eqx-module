#!/bin/bash

export HOME=/root

apt-get update
apt-get install -y jq git inotify-tools docker.io

while [ ! -f "$HOME/secrets.json" ]
do
  inotifywait -qqt 2 -e create -e moved_to "$(dirname $HOME/secrets.json)"
  echo "done"
done

export gh_username=$(jq -r .gh_username < $HOME/secrets.json)
export gh_pat=$(jq -r .gh_pat < $HOME/secrets.json)

export ROLE=$(curl --silent https://metadata.platformequinix.com/2009-04-04/meta-data/tags | jq -r .role)
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/agent.git $HOME/agent
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/infra-helm-charts.git $HOME/infra-helm-charts
chmod +x $HOME/agent/install-$ROLE.sh && $HOME/agent/install-$ROLE.sh

sleep 5

while [ ! -f "/etc/kubernetes/admin.conf" ]
do
  inotifywait -qqt 2 -e create -e moved_to "$(dirname /etc/kubernetes/admin.conf)"
  echo "done"
done

sleep 5

mkdir -p /data/postgres /data/prometheus /data/superset /data/zookeeper-logs /data/zookeeper-data

echo "performing the following"
echo docker run -v $HOME/agent:/apps -v $HOME/infra-helm-charts:/apps/infra-helm-charts -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) -e KUBECONFIG=/etc/kubernetes/admin.conf --entrypoint '/bin/bash' ahaiong/l3a-installer:latest "/apps/install-l3a.sh"

docker run \
  -v $HOME/agent:/apps \
  -v $HOME/infra-helm-charts:/apps/infra-helm-charts \
  -v $HOME/infra_config.json:/apps/infra_config.json \
  -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf \
  -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) \
  -e KUBECONFIG=/etc/kubernetes/admin.conf \
  --entrypoint '/bin/bash' \
  ahaiong/l3a-installer:latest "/apps/install-l3a.sh"

#!/usr/bin/env bash

export HOME=/root

apt-get update
apt-get install -y jq git inotify-tools docker.io

while [ ! -f "$HOME/secrets.json" ]
do
  inotifywait -qqt 2 -e create -e moved_to "$(dirname $HOME/secrets.json)"
  echo "done"
done

export gh_username=$(cat $HOME/secrets.json | jq -r .gh_username)
export gh_pat=$(jq -r .gh_pat < "$HOME/secrets.json")

export ROLE=$(curl --silent https://metadata.platformequinix.com/2009-04-04/meta-data/tags | jq -r .role)
git clone https://$gh_username:$gh_pat@github.com/L3A-Protocol/agent.git $HOME/agent
sh $HOME/agent/install-$ROLE.sh

sleep 30

export uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname))
echo "uniq_id is $uniq_id"

echo "performing the following"
echo docker run -v $PWD/agent:/apps -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) -e KUBECONFIG=/etc/kubernetes/admin.conf --entrypoint '/bin/bash' custom "/apps/test.sh"

docker run -v $PWD/agent:/apps -v /etc/kubernetes/admin.conf:/etc/kubernetes/admin.conf \
  -e uniq_id=$(awk  -F '-' '{print $1}' <<< $(hostname)) 
  -e KUBECONFIG=/etc/kubernetes/admin.conf \
  --entrypoint '/bin/bash' \
  custom "/apps/install-l3a.sh"

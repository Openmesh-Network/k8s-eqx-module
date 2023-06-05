#!/usr/bin/env bash

export HOME=/root

apt-get install -y jq git inotify-tools

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

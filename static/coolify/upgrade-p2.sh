#!/bin/bash
# This is running inside coolify-base
WHO=$(whoami)
if [ $WHO != 'root' ]; then
    echo 'You are not root. Ooops!'
    exit
fi

FULLRESTART=$(curl -s https://get.coollabs.io/version.json | jq .coolify.next.fullRestart)

if [ $FULLRESTART ]; then
    docker stack rm coollabs-coolify
else
    docker service rm coollabs-coolify_coolify
fi

set -a && source /usr/src/app/.env && set +a && envsubst < /usr/src/app/install/coolify-template.yml | docker stack deploy -c - coollabs-coolify
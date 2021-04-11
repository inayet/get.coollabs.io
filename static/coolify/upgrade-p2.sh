#!/bin/bash
# This is running inside coolify-base
WHO=$(whoami)
if [ $WHO != 'root' ]; then
    echo 'You are not root. Ooops!'
    exit
fi

docker service rm coollabs-coolify_coolify
set -a && source /usr/src/app/.env && set +a && envsubst < /usr/src/app/install/coolify-template.yml | docker stack deploy -c - coollabs-coolify
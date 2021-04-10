#!/bin/bash
WHO=$(whoami)
if [ $WHO != 'root' ]; then
    echo 'You are not root. Ooops!'
    exit
fi

echo "Hello update"
GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git pull
docker build --label coolify-reserve=true -t coolify-base -f /usr/src/app/install/Dockerfile-base .
docker run --rm -w /usr/src/app coolify-base node /usr/src/app/install/check.js

set -a && source .env && set +a

docker network create $DOCKER_NETWORK --driver overlay
docker build -t coolify -f /usr/src/app/install/Dockerfile .
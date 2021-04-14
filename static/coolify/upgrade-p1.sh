#!/bin/bash
# This is running on the OS
WHO=$(whoami)
if [ $WHO != 'root' ]; then
    echo 'You are not root. Ooops!'
    exit
fi
# Dockerfile-base-new should be renamed after months
GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git pull
# docker build --label coolify-reserve=true -t coolify-binaries -f install/Dockerfile-binaries .
# docker build --label coolify-reserve=true -t coolify-base-nodejs -f install/Dockerfile-base-nodejs .
# docker build --label coolify-reserve=true -t coolify-base -f install/Dockerfile-base-new .
# docker run --rm -w /usr/src/app coolify-base node /usr/src/app/install/check.js

set -a && source .env && set +a

docker network create $DOCKER_NETWORK --driver overlay
docker build --label coolify-reserve=true -t coolify -f install/Dockerfile-new .
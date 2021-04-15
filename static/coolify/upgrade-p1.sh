#!/bin/bash
# This is running in Docker, in the currently running Coolify instance
WHO=$(whoami)
if [ $WHO != 'root' ]; then
    echo 'You are not root. Ooops!'
    exit
fi
# Dockerfile-new should be renamed after months to Dockerfile
GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git pull
set -a && source .env && set +a
docker network create $DOCKER_NETWORK --driver overlay
docker build --label coolify-reserve=true -t coolify -f install/Dockerfile-new .
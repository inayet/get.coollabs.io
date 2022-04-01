#!/usr/bin/env bash
set -eou pipefail
clear
WHO=$(whoami)
APP_ID=$(cat /proc/sys/kernel/random/uuid)
RANDOM_SECRET=$(echo $(($(date +%s%N) / 1000000)) | sha256sum | base64 | head -c 32)
SENTRY_DSN="https://9e7a74326f29422584d2d0bebdc8b7d3@o1082494.ingest.sentry.io/6091062"
DOCKER_MAJOR=20
DOCKER_MINOR=10
DOCKER_VERSION_OK="nok"
FORCE=0

function doNotTrack() {
      DO_NOT_TRACK=1
      SENTRY_DSN=
      APP_ID=
}

if [ -z ${DO_NOT_TRACK+0} ]; then
    DO_NOT_TRACK=0
else 
    if [ ${DO_NOT_TRACK} -eq 1 ]; then
        doNotTrack
    fi
fi

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--debug)
      set -x
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    --do-not-track)
      doNotTrack
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

function errorchecker() {
    exitCode=$?
    if [ $exitCode -ne "0" ]; then
        echo "$0 exited unexpectedly with status: $exitCode"
        exit $exitCode
    fi
}
trap 'errorchecker' EXIT

echo -e "Welcome to Coolify installer!"
echo -e "This script will install all the required packages and services to run Coolify."
echo -e "To see what this script is doing, click here: https://github.com/coollabsio/get.coollabs.io/blob/main/static/coolify/install.sh\n"
echo "-------------"
echo -e "TELEMETRY:"
echo -e "1. The script generates an UUID for your installation to show the number of installed instances on the landing page (https://coolify.io)."
echo -e "2. We use Sentry.io to track errors to fix errors quicker.\n"
echo -e "If you would like to opt-out, we follow the DO_NOT_TRACK movement (https://consoledonottrack.com/).\nSet the environment variable with 'export DO_NOT_TRACK=1' or re-execute the script with: 'curl -fsSL https://get.coollabs.io/coolify/install.sh | bash /dev/stdin --do-not-track'"
echo -e "-------------\n"
# Check if user is root
if [ $WHO != 'root' ]; then
    echo 'Run as root please: sudo sh -c "$(curl -fsSL https://get.coollabs.io/coolify/install.sh)"'
    exit 1
fi

# Check docker version
if [ ! -x "$(command -v docker)" ]; then
    if [ $FORCE -eq 1 ]; then
        echo "Installing Docker..."
        sh -c "$(curl --silent -fsSL https://get.docker.com)"
    else
        while true; do
            read -p "Docker Engine not found, should I install it automatically? [Yy/Nn] " yn
            case $yn in
            [Yy]*)
                echo "Installing Docker..."
                sh -c "$(curl --silent -fsSL https://get.docker.com)"
                break
                ;;
            [Nn]*)
                echo "Please install docker manually and update it to the latest, but at least to $DOCKER_MAJOR.$DOCKER_MINOR"
                exit 0
                ;;
            *) echo "Please answer Y or N." ;;
            esac
        done
    fi
fi

# Check docker swarm
if [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ]; then
    echo "Coolify does not support Docker Swarm yet. Please use a non-swarm compatible version of Docker."
    exit 1
fi

SERVER_VERSION=$(docker version -f "{{.Server.Version}}")
SERVER_VERSION_MAJOR=$(echo "$SERVER_VERSION" | cut -d'.' -f 1)
SERVER_VERSION_MINOR=$(echo "$SERVER_VERSION" | cut -d'.' -f 2)

if [ "$SERVER_VERSION_MAJOR" -ge "$DOCKER_MAJOR" ] &&
    [ "$SERVER_VERSION_MINOR" -ge "$DOCKER_MINOR" ]; then
    DOCKER_VERSION_OK="ok"
fi

if [ $DOCKER_VERSION_OK == 'nok' ]; then
    echo "Docker version less than $DOCKER_MAJOR.$DOCKER_MINOR, please update it to at least to $DOCKER_MAJOR.$DOCKER_MINOR"
    exit 1
fi

if [ -f "/etc/docker/daemon.json" ]; then
    if [ $FORCE -eq 1 ]; then
        echo -e "/etc/docker/daemon.json file found. We will optimize and overwrite it.\n"
        # Adding docker daemon configuration
        cat <<EOF >/etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    },
    "features": {
        "buildkit": true
    },
    "live-restore": true,
    "default-address-pools" : [
    {
      "base" : "172.17.0.0/12",
      "size" : 20
    },
    {
      "base" : "192.168.0.0/16",
      "size" : 24
    }
  ]
}
EOF
    else
        echo -e "/etc/docker/daemon.json file found.\n\nPlease add the following to /etc/docker/daemon.json manually and restart docker with 'systemctl daemon-reload && systemctl restart docker':"
        echo -e '\n{"log-driver":"json-file","log-opts":{"max-size":"100m","max-file":"5"},"features":{"buildkit":true},"live-restore":true,"default-address-pools":[{"base":"172.17.0.0/12","size":20},{"base":"192.168.0.0/16","size":24}]}\n\n'
        echo -e "Or execute the installer with force installation: 'curl -fsSL https://get.coollabs.io/coolify/install.sh | bash /dev/stdin -f' \n"
        exit 1
    fi
else
    # Adding docker daemon configuration
    cat <<EOF >/etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    },
    "features": {
        "buildkit": true
    },
    "live-restore": true,
    "default-address-pools" : [
    {
      "base" : "172.17.0.0/12",
      "size" : 20
    },
    {
      "base" : "192.168.0.0/16",
      "size" : 24
    }
  ]
}
EOF
fi
# Restarting docker daemon
echo "Restarting docker daemon..."
sh -c "systemctl daemon-reload && systemctl restart docker"

# Downloading docker compose cli plugin
echo "Installing docker-compose CLI plugin..."
mkdir -p ~/.docker/cli-plugins/
curl --silent -SL https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Making base directory for coolify
if [ ! -d ~/coolify ]; then
    mkdir ~/coolify
fi

if [ -f ~/coolify/.env ]; then
    echo "Found .env file of Coolify. Using it during setup."
else
    echo "COOLIFY_APP_ID=$APP_ID
COOLIFY_SECRET_KEY=$RANDOM_SECRET
COOLIFY_DATABASE_URL=file:../db/prod.db
COOLIFY_SENTRY_DSN=$SENTRY_DSN
COOLIFY_HOSTED_ON=docker" >~/coolify/.env
fi

echo "Installing Coolify..."
docker pull -q coollabsio/coolify:latest
cd ~/coolify && docker run -tid --env-file .env -v /var/run/docker.sock:/var/run/docker.sock -v coolify-db-sqlite coollabsio/coolify:latest /bin/sh -c "env | grep COOLIFY > .env && docker compose up -d --force-recreate"

echo -e "\nCongratulations! Your Coolify instance is ready to use.\n"
echo "Please visit http://$(curl -4s https://ifconfig.io):3000 to get started."
echo "It will take a few minutes to start up, don't worry."

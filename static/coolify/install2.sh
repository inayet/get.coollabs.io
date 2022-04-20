#!/usr/bin/env bash

[ ! -n "$BASH_VERSION" ] && echo "You can only run this script with bash, not sh / dash." && exit 1

set -eou pipefail
VERSION="v1.0.0"
ARCH=$(uname -m)
WHO=$(whoami)
DEBUG=0
FORCE=0

DOCKER_MAJOR=20
DOCKER_MINOR=10
DOCKER_VERSION_OK="nok"

COOLIFY_APP_ID=$(cat /proc/sys/kernel/random/uuid)
COOLIFY_SECRET_KEY=$(echo $(($(date +%s%N) / 1000000)) | sha256sum | base64 | head -c 32)
COOLIFY_SENTRY_DSN="https://9e7a74326f29422584d2d0bebdc8b7d3@o1082494.ingest.sentry.io/6091062"
COOLIFY_WHITE_LABELED=false
COOLIFY_WHITE_LABELED_ICON=
COOLIFY_CONF_FOUND=$(find ~ -path '*/coolify/.env')

if [ -n "$COOLIFY_CONF_FOUND" ]; then
    eval "$(grep ^COOLIFY_APP_ID= $COOLIFY_CONF_FOUND)"
    eval "$(grep ^COOLIFY_SECRET_KEY= $COOLIFY_CONF_FOUND)"
    eval "$(grep ^COOLIFY_DATABASE_URL= $COOLIFY_CONF_FOUND)"
    eval "$(grep ^COOLIFY_SENTRY_DSN= $COOLIFY_CONF_FOUND)"
    eval "$(grep ^COOLIFY_HOSTED_ON= $COOLIFY_CONF_FOUND)"
    eval "$(grep ^COOLIFY_WHITE_LABELED_ICON= $COOLIFY_CONF_FOUND)"
else
    COOLIFY_CONF_FOUND=${COOLIFY_CONF_FOUND:="$HOME/coolify/.env"}
fi

# Making base directory for coolify
if [ ! -d ~/coolify ]; then
    mkdir ~/coolify
fi

if [ -z ${DO_NOT_TRACK+0} ]; then
    DO_NOT_TRACK=0
else 
    if [ ${DO_NOT_TRACK} -eq 1 ]; then
        doNotTrack
    fi
fi

die() { echo "$*" >&2; exit 2; }
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }
errorchecker() {
    exitCode=$?
    if [ $exitCode -ne "0" ]; then
        echo "$0 exited unexpectedly with status: $exitCode"
        exit $exitCode
    fi
}
doNotTrack() {
      DO_NOT_TRACK=1
      COOLIFY_SENTRY_DSN=
      COOLIFY_APP_ID=
}

while getopts hdfnwi:-: OPT; do
  if [ "$OPT" = "-" ]; then
    OPT="${OPTARG%%=*}"
    OPTARG="${OPTARG#$OPT}" 
    OPTARG="${OPTARG#=}"
  fi
  case "$OPT" in
    h | help ) 
        echo -e "Coolify installer $VERSION
(source code: https://github.com/coollabsio/get.coollabs.io/blob/main/static/coolify/install.sh)\n
Usage: install.sh [options...] 
    -h, --help                  Show this help menu.
    -d, --debug                 Show debug logs during installation.
    -f, --force                 Force installation, no questions asked.\n
    -n, --do-not-track          Opt-out of telemetry. You can set export DO_NOT_TRACK=1 in advance.\n
    -w, --white-labeled         Install white-labeled version. Contact me before using it (https://docs.coollabs.io/contact)
    -i, --white-labeled-logo    Add your remote logo for your white-labeled version. Should be a http/https URL."
    exit 1;
    ;;
    d | debug )                 DEBUG=1; set -x;;
    f | force )                 FORCE=1;;
    n | do-not-track )          doNotTrack;;
    w | white-labeled )         COOLIFY_WHITE_LABELED="true";;
    i | white-labeled-logo )    needs_arg; COOLIFY_WHITE_LABELED_ICON="$OPTARG"; COOLIFY_WHITE_LABELED="true";;
    ??* )                       die "Illegal option --$OPT";;
    ? )                         exit 2 ;;
  esac
done

shift $((OPTIND-1))
trap 'errorchecker' EXIT

if [ $DEBUG -eq 1 ]; then
    echo "FORCE=$FORCE" 
    echo "COOLIFY_APP_ID=$COOLIFY_APP_ID"
    echo "COOLIFY_SECRET_KEY=$COOLIFY_SECRET_KEY"
    echo "COOLIFY_DATABASE_URL=$COOLIFY_DATABASE_URL"
    echo "COOLIFY_SENTRY_DSN=$COOLIFY_SENTRY_DSN"
    echo "COOLIFY_HOSTED_ON=$COOLIFY_HOSTED_ON"
    echo "COOLIFY_WHITE_LABELED=$COOLIFY_WHITE_LABELED"
    echo "COOLIFY_WHITE_LABELED_ICON=$COOLIFY_WHITE_LABELED_ICON" 
fi
if [ $FORCE -eq 1 ]; then
    echo -e "Installing Coolify with force option!"
else
    echo -e "Welcome to Coolify installer!"
    echo -e "This script will install all requirements to run Coolify."
    echo -e "(Source code of this script: https://github.com/coollabsio/get.coollabs.io/blob/main/static/coolify/install.sh)\n"
    echo "-------------"
    echo -e "TELEMETRY:"
    echo -e "1. The script generates a random UUID for your installation to show the number of installed instances on the landing page (https://coolify.io). Nothing else."
    echo -e "2. We use Sentry.io to track errors to fix them quicker.\n"
    echo -e "If you would like to opt-out, we follow the DO_NOT_TRACK movement (https://consoledonottrack.com/).\nExecute 'export DO_NOT_TRACK=1' to set the required environment variable or use '--do-not-track' option."
    echo -e "-------------\n"
fi

# Check if user is root
if [ $WHO != 'root' ]; then
    echo 'Run as root please: sudo bash ./install.sh'
    exit 1
fi

restartDocker() {
   # Restarting docker daemon
   sudo systemctl daemon-reload
   sudo systemctl restart docker
}

dockerConfiguration() {
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
}
saveCoolifyConfiguration() {
      echo "COOLIFY_APP_ID=$COOLIFY_APP_ID
COOLIFY_SECRET_KEY=$COOLIFY_SECRET_KEY
COOLIFY_DATABASE_URL=file:../db/prod.db
COOLIFY_SENTRY_DSN=$COOLIFY_SENTRY_DSN
COOLIFY_HOSTED_ON=docker
COOLIFY_WHITE_LABELED=$COOLIFY_WHITE_LABELED 
COOLIFY_WHITE_LABELED_ICON=$COOLIFY_WHITE_LABELED_ICON"> $COOLIFY_CONF_FOUND
}
# Check docker version
if [ ! -x "$(command -v docker)" ]; then
    if [ $FORCE -eq 1 ]; then
        sh -c "$(curl --silent -fsSL https://get.docker.com)"
        restartDocker
    else
        while true; do
            read -p "Docker Engine not found, should I install it automatically? [Yy/Nn] " yn
            case $yn in
            [Yy]*)
                echo "Installing Docker."
                sh -c "$(curl --silent -fsSL https://get.docker.com)"
                restartDocker
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
if [ "$(sudo docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ]; then
    echo "Coolify does not support Docker Swarm yet. Please use a non-swarm compatible version of Docker."
    exit 1
fi

SERVER_VERSION=$(sudo docker version -f "{{.Server.Version}}")
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
        # Adding docker daemon configuration
        echo 'Configuring Docker daemon.'
        dockerConfiguration
    else
      while true; do
            read -p "Docker already configured. I will overwrite it, okay? [Yy/Nn] " yn
            case $yn in
            [Yy]*)
                dockerConfiguration
                restartDocker
                break
                ;;
            [Nn]*)
                echo "Cannot continue."
                exit 1
                ;;
            *) echo "Please answer Y or N." ;;
            esac
        done
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

restartDocker

# Downloading docker compose cli plugin
if [ ! -x ~/.docker/cli-plugins/docker-compose ]; then
    echo "Installing Docker Compose CLI plugin."
    if [ ! -d ~/.docker/cli-plugins/ ]; then
        sudo mkdir -p ~/.docker/cli-plugins/
    fi
    if [ ARCH == 'arm64' ] || [ ARCH == 'aarch64' ]; then
        sudo curl --silent -SL https://cdn.coollabs.io/bin/linux/arm64/docker-compose-linux-2.3.4 -o ~/.docker/cli-plugins/docker-compose
        sudo chmod +x ~/.docker/cli-plugins/docker-compose
    else 
        sudo curl --silent -SL https://cdn.coollabs.io/bin/linux/amd64/docker-compose-linux-2.3.4 -o ~/.docker/cli-plugins/docker-compose
        sudo chmod +x ~/.docker/cli-plugins/docker-compose
    fi
fi
if [ $FORCE -eq 1 ]; then
    echo 'Updating Coolify configuration.'
    saveCoolifyConfiguration
else
    if [ -f "$COOLIFY_CONF_FOUND" ]; then
        while true; do
                    read -p "Coolify configuration found (${COOLIFY_CONF_FOUND}). I will overwrite it, okay? [Yy/Nn] " yn
                    case $yn in
                    [Yy]*)
                        saveCoolifyConfiguration
                        break
                        ;;
                    [Nn]*)
                        break
                        ;;
                    *) echo "Please answer Y or N." ;;
                    esac
                done
        else
            saveCoolifyConfiguration
    fi
fi
if [ $FORCE -ne 1 ]; then
    echo "Installing Coolify."
fi
echo "Pulling Coolify latest image."
sudo docker pull -q coollabsio/coolify:latest > /dev/null
echo "Starting Coolify."
cd ~/coolify && sudo docker run -tid --env-file $COOLIFY_CONF_FOUND -v /var/run/docker.sock:/var/run/docker.sock -v coolify-db-sqlite coollabsio/coolify:latest /bin/sh -c "env | grep COOLIFY > .env && docker compose up -d --force-recreate" > /dev/null

echo -e "Congratulations! Your Coolify instance is ready to use.\n"
echo "Please visit http://$(curl -4s https://ifconfig.io):3000 to get started."
echo "It will take a few minutes to start up, don't worry."

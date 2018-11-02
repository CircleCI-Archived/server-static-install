#!/usr/bin/env bash

set -exu

NOMAD_VERSION="0.5.6"
DOCKER_VERSION="17.03.2"
UNAME="$(uname -r)"
DEBIAN_FRONTEND=noninteractive

is_xenial(){
  [ "$(cut -d'.' -f1 <<< $UNAME)" = "4" ] && return 0 || return 1
}

guess_private_ip(){
  INET="eth0"
  is_xenial && INET="ens3"
  /sbin/ifconfig $INET | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'
}

echo "--------------------------------------------"
echo "       Finding Private IP"
echo "--------------------------------------------"


PRIVATE_IP=${PRIVATE_IP:-$(guess_private_ip)}
export PRIVATE_IP

echo "Using address: ${PRIVATE_IP}"

if [ -z "${NOMAD_SERVER_ADDRESS}" ]; then
  echo "The NOMAD_SERVER_ADDRESS env var is required."
  echo "It should point to the ip address of your CircleCI"
  echo "services installation."
  exit 1
fi

echo "-------------------------------------------"
echo "     Performing System Updates"
echo "-------------------------------------------"
apt-get update && apt-get -y upgrade

echo "-------------------------------------------"
echo "     Installing Required Dependencies"
echo "-------------------------------------------"
apt-get install -y zip

echo "--------------------------------------"
echo "        Installing Docker"
echo "--------------------------------------"
if is_xenial; then
  apt-get install -y "linux-image-${UNAME}"
else
  apt-get install -y "linux-image-extra-$(uname -r)" linux-image-extra-virtual
fi
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get -y install "docker-ce=${DOCKER_VERSION}~ce-0~ubuntu-$(lsb_release -cs)" cgmanager

echo "--------------------------------------"
echo "         Installing nomad"
echo "--------------------------------------"
curl -o nomad.zip "https://releases.hashicorp.com/nomad/0.5.6/nomad_${NOMAD_VERSION}_linux_amd64.zip"
unzip nomad.zip
mv nomad /usr/bin
mkdir -p /etc/nomad

echo "--------------------------------------"
echo "      Creating config.hcl"
echo "--------------------------------------"
cat <<EOT > /etc/nomad/config.hcl
log_level = "DEBUG"

data_dir = "/opt/nomad"
datacenter = "us-east-1"

advertise {
    http = "$PRIVATE_IP"
    rpc = "$PRIVATE_IP"
    serf = "$PRIVATE_IP"
}

client {
    enabled = true
    servers = ["${NOMAD_SERVER_ADDRESS}:4647"]
    node_class = "linux-64bit"
    options = {"driver.raw_exec.enable" = "1"}
}
EOT

echo "--------------------------------------"
echo "      Creating nomad.conf"
echo "--------------------------------------"
if is_xenial; then
cat <<EOT > /etc/systemd/system/nomad.service
[Unit]
Description="nomad"
[Service]
Restart=always
RestartSec=30
TimeoutStartSec=1m
ExecStart=/usr/bin/nomad agent -config /etc/nomad/config.hcl
[Install]
WantedBy=multi-user.target
EOT
else
cat <<EOT > /etc/init/nomad.conf
start on filesystem or runlevel [2345]
stop on shutdown
script
    exec nomad agent -config /etc/nomad/config.hcl
end script
EOT
fi

echo "--------------------------------------"
echo "   Creating ci-privileged network"
echo "--------------------------------------"
docker network create --driver=bridge --opt com.docker.network.bridge.name=ci-privileged ci-privileged


echo "--------------------------------------"
echo "      Starting Nomad service"
echo "--------------------------------------"
is_xenial

echo "--------------------------------------"
echo "   "Running nomad with mounted docker socket"
echo "--------------------------------------"

sudo docker run \
    --detach \
    --privileged \
    --restart on-failure \
    --network host \
    --volume /opt/nomad:/opt/nomad \
    --volume /etc/nomad:/etc/nomad \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --entrypoint nomad \
    circleci/server-nomad:0.5.6-1 \
    agent -config /etc/nomad/config.hcl


echo "--------------------------------------"
echo "   "Configure the shared docker daemon"
echo "--------------------------------------"

ln -s /var/run/docker.sock /tmp/user-docker.sock

## Configure the shared docker daemon for user builds
sudo nohup dockerd \
    --exec-root=/tmp/user-docker.exec \
    --graph=/tmp/user-docker.graph \
    --host=unix:///tmp/user-docker.sock \
    --pidfile=/tmp/user-docker.pid &

sleep 5
chmod 666 /tmp/user-docker.sock
chmod 666 /var/run/docker.sock

echo 'Node has been configured'





